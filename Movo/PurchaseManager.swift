import Foundation
import StoreKit
import SwiftUI
import UIKit   // ✅ hinzufügen

// MARK: - Purchase Manager

@MainActor
final class PurchaseManager: ObservableObject {

    // MARK: - Public State (für UI)
    @Published var hasUnlockedStatistics: Bool

    // Preise & Badges live aus dem Store anzeigen
    @Published var displayPriceMonthly: String?
    @Published var displayPriceYearly: String?
    @Published var displayPriceLifetime: String?
    @Published var introBadgeMonthly: String?
    @Published var introBadgeYearly: String?

    // MARK: - Config
    private let useMockMode = false

    // 👉 IDs: müssen 1:1 in App Store Connect existieren (Groß/Klein zählt)
    private let productIDMonthly  = "com.benepkt.movo.premium.monthlyabo.v4"
    private let productIDYearly   = "com.benepkt.movo.premium.yearly.v4"
    private let productIDLifetime = "com.benepkt.movo.premium.lifetime.v4"


    // Cache
    private var products: [String: Product] = [:]

    // MARK: - Init
    init() {
        // persistenten Zustand aus beiden Quellen mergen
        let uf = UserDefaults.standard.bool(forKey: "hasUnlockedStatistics")
        let shared = StepsShared.isPremiumUnlocked()
        self.hasUnlockedStatistics = uf || shared

        Task {
            await fetchProducts()
            // Beim Start NICHT runterstufen, nur hochstufen
            await refreshEntitlements(preserveLocal: true)
            listenForTransactionUpdates()
        }
    }

    // MARK: - Public API
    func purchaseMonthly() async { await purchase(productID: productIDMonthly) }
    func purchaseYearly()  async { await purchase(productID: productIDYearly) }
    func purchaseLifetime() async { await purchase(productID: productIDLifetime) }

    func restorePurchases() async {
        if useMockMode {
            let wasUnlocked = UserDefaults.standard.bool(forKey: "hasUnlockedStatistics")
            setPremium(wasUnlocked)
            print("🟢 MOCK: Restore ausgeführt")
            return
        }

        do {
            try await AppStore.sync()
            await refreshEntitlements(preserveLocal: false)
        } catch {
            print("❌ Wiederherstellen fehlgeschlagen: \(error)")
        }
    }

    private func setPremium(_ unlocked: Bool) {
        hasUnlockedStatistics = unlocked
        UserDefaults.standard.set(unlocked, forKey: "hasUnlockedStatistics")
        StepsShared.setPremium(unlocked) // App-Group + Widget reload
    }

    public func applyRemotePremium(_ enabled: Bool) {
        // Remote-Flag darf NIEMALS downgraden.
        if enabled { setPremium(true) }
    }

    // MARK: - Core
    private func purchase(productID: String) async {
        if useMockMode {
            setPremium(true)
            print("🟢 MOCK: Premium freigeschaltet")
            return
        }

        do {
            let product = try await product(for: productID)
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // ✅ WICHTIG: Transaktion abschließen
                    await transaction.finish()
                    setPremium(true)
                    print("✅ Kauf erfolgreich: \(transaction.productID)")

                case .unverified(_, let error):
                    print("⚠️ Kauf unbestätigt: \(String(describing: error))")
                }

            case .userCancelled:
                print("❌ Kauf abgebrochen")

            case .pending:
                print("⏳ Kauf pending (z.B. Family Approval)")

            @unknown default:
                break
            }
        } catch {
            print("❌ Kauf fehlgeschlagen: \(error)")
        }
    }

    private func refreshEntitlements(preserveLocal: Bool) async {
        do {
            var active = false

            for await result in StoreKit.Transaction.currentEntitlements {
                if case .verified(let t) = result,
                   (t.productID == productIDMonthly ||
                    t.productID == productIDYearly  ||
                    t.productID == productIDLifetime) {
                    active = true
                    break
                }
            }

            if active {
                setPremium(true)                 // Upgrade sofort übernehmen
            } else if !preserveLocal {
                setPremium(false)                // nur bei Restore/Explizit
            }
        } catch {
            print("❌ Entitlements prüfen fehlgeschlagen: \(error)")
        }
    }

    private func listenForTransactionUpdates() {
        Task.detached { [weak self] in
            guard let self else { return }
            for await update in StoreKit.Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()

                    // Falls widerrufen/erstattet:
                    if transaction.revocationDate != nil {
                        await MainActor.run { self.setPremium(false) }
                        continue
                    }

                    if transaction.productID == self.productIDMonthly ||
                       transaction.productID == self.productIDYearly  ||
                       transaction.productID == self.productIDLifetime {
                        await MainActor.run { self.setPremium(true) }
                    }
                }
            }
        }
    }

    // MARK: - Product Loading
    private func fetchProducts() async {
        let ids = [productIDMonthly, productIDYearly, productIDLifetime]
        do {
            var fetched = try await Product.products(for: ids)
            print("🧾 fetched products:", fetched.map(\.id))

            // Fallback: fehlende IDs einzeln nachladen (Sandbox/Storefront kann selektiv filtern)
            let fetchedIDs = Set(fetched.map(\.id))
            let missing = ids.filter { !fetchedIDs.contains($0) }
            if !missing.isEmpty {
                print("🧾 missing products in batch (will fetch individually):", missing)
                for id in missing {
                    do {
                        let extra = try await Product.products(for: [id])
                        if let p = extra.first {
                            fetched.append(p)
                            print("🧾 recovered product via single fetch:", p.id)
                        } else {
                            print("⚠️ still missing after single fetch:", id)
                        }
                    } catch {
                        print("❌ single fetch failed for \(id): \(error)")
                    }
                }
            }

            // Cache aktualisieren
            for p in fetched { products[p.id] = p }

            // UI-Strings setzen
            displayPriceMonthly  = products[productIDMonthly]?.displayPrice
            displayPriceYearly   = products[productIDYearly]?.displayPrice
            displayPriceLifetime = products[productIDLifetime]?.displayPrice

            introBadgeMonthly = introBadgeText(for: products[productIDMonthly])
            introBadgeYearly  = introBadgeText(for: products[productIDYearly])
        } catch {
            print("❌ Produkte laden fehlgeschlagen: \(error)")
        }
    }

    private func product(for id: String) async throws -> Product {
        if let p = products[id] { return p }
        let fetched = try await Product.products(for: [id])
        guard let p = fetched.first else {
            throw NSError(
                domain: "PurchaseManager",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Produkt nicht gefunden (\(id))"]
            )
        }
        products[id] = p
        return p
    }

    // MARK: - Helpers
    private func introBadgeText(for product: Product?) -> String? {
        guard let offer = product?.subscription?.introductoryOffer else { return nil }

        switch offer.paymentMode {
        case .freeTrial:
            let p = offer.period
            switch p.unit {
            case .day:   return "\(p.value) Tage kostenlos"
            case .week:  return "\(p.value) Woche(n) kostenlos"
            case .month: return "\(p.value) Monat(e) kostenlos"
            case .year:  return "\(p.value) Jahr(e) kostenlos"
            @unknown default:
                return "Kostenlose Testphase"
            }

        case .payAsYouGo, .payUpFront:
            return "Einführungsangebot"

        default:
            return "Einführungsangebot"
        }
    }
}

// MARK: - Pläne

enum PaywallPlan: String, CaseIterable {
    case monthly
    case yearly
    case lifetime
}

// MARK: - Kauf-Routing

@MainActor
extension PurchaseManager {
    func purchase(plan: PaywallPlan) async {
        switch plan {
        case .monthly:  await purchaseMonthly()
        case .yearly:   await purchaseYearly()
        case .lifetime: await purchaseLifetime()
        }
    }
}

@MainActor
extension PurchaseManager {

    /// Öffnet Apples offizielles "Code einlösen" Sheet (Offer Code / Promo Code).
    /// Danach werden Entitlements aktualisiert, damit Premium sofort aktiv wird.
    func redeemCode() async {
        #if os(iOS)
        do {
            if #available(iOS 16.0, *) {
                // bestes aktives UIWindowScene finden
                let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                guard let scene =
                        scenes.first(where: { $0.activationState == .foregroundActive }) ??
                        scenes.first
                else {
                    print("❌ Kein UIWindowScene gefunden für Redeem Sheet")
                    return
                }

                try await AppStore.presentOfferCodeRedeemSheet(in: scene)
            } else {
                // iOS 15 und älter
                SKPaymentQueue.default().presentCodeRedemptionSheet()
            }

            // nach Einlösung Entitlements neu prüfen (Premium sollte dann anspringen)
            await refreshEntitlements(preserveLocal: true)

        } catch {
            print("❌ Code einlösen fehlgeschlagen: \(error)")
        }
        #endif
    }
}


// MARK: - Paywall Theme

private struct PaywallTheme {
    static let accentA = Color(red: 0.40, green: 0.63, blue: 1.00)
    static let accentB = Color(red: 0.58, green: 0.42, blue: 1.00)
    static let bgTop   = Color.black
    static let bgBot   = Color(red: 0.05, green: 0.07, blue: 0.11)
}

// MARK: - Paywall View

struct PaywallView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    var onRequestClose: (() -> Void)? = nil

    @State private var selected: PaywallPlan = .monthly
    @State private var isLoading = false

    var eulaURL: URL?    = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

    var termsURL: URL? = URL(string: "https://www.movobp.de/agb.html")
    var privacyURL: URL? = URL(string: "https://www.movobp.de/datenschutz.html")

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private func L(_ de: String, _ en: String) -> String { isDE ? de : en }

    // ✅ CTA erst aktivieren, wenn Produkte wirklich geladen sind
    private var productsReady: Bool {
        purchaseManager.displayPriceMonthly != nil ||
        purchaseManager.displayPriceYearly != nil ||
        purchaseManager.displayPriceLifetime != nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(colors: [PaywallTheme.bgTop, PaywallTheme.bgBot],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [PaywallTheme.accentB.opacity(0.20), .clear],
                           center: .topLeading, startRadius: 10, endRadius: 420)
                .ignoresSafeArea()
            RadialGradient(colors: [PaywallTheme.accentA.opacity(0.18), .clear],
                           center: .bottomTrailing, startRadius: 10, endRadius: 520)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header

                    // Headline
                    VStack(spacing: 8) {
                        Text(L("Jeden Tag.", "Every Day."))
                            .font(.system(size: 40, weight: .heavy))
                            .kerning(0.5)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(L("Alle Pro-Features – modern, schnell und ohne Limits.",
                               "All Pro features – modern, fast, without limits."))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)

                    // Feature-Karussell
                    PaywallFeatureCarousel()
                        .padding(.top, 4)

                    // Plan-Auswahl
                    VStack(spacing: 12) {

                        // Jahresabo
                        PlanCardGlass(
                            title: L("Jahresabo", "Yearly"),
                            leftPill: L("Beliebt", "Popular"),
                            rightBadge: purchaseManager.introBadgeYearly,
                            price: purchaseManager.displayPriceYearly ?? "—",
                            periodLabel: L("pro Jahr", "per year"),
                            subline: {
                                // If intro is available, show explicit free-trial copy with price
                                if purchaseManager.introBadgeYearly != nil,
                                   let price = purchaseManager.displayPriceYearly {
                                    return L("7 Tage kostenlos, danach \(price)/Jahr",
                                             "7 days free, then \(price)/year")
                                } else {
                                    return L("Bestes Preis-Leistungs-Verhältnis", "Best value")
                                }
                            }(),
                            selected: selected == .yearly,
                            glow: selected == .yearly
                        )
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.18)) { selected = .yearly } }

                        // Monatsabo
                        PlanCardGlass(
                            title: L("Monatsabo", "Monthly"),
                            leftPill: nil,
                            rightBadge: purchaseManager.introBadgeMonthly,
                            price: purchaseManager.displayPriceMonthly ?? "—",
                            periodLabel: L("pro Monat", "per month"),
                            subline: L("Maximum Flexibilität, kündbar jederzeit.",
                                       "Maximum flexibility, cancel anytime."),
                            selected: selected == .monthly
                        )
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.18)) { selected = .monthly } }

                        // Lifetime
                        PlanCardGlass(
                            title: L("Lifetime", "Lifetime"),
                            leftPill: L("Einmalig", "One-time"),
                            rightBadge: nil,
                            price: purchaseManager.displayPriceLifetime ?? "—",
                            periodLabel: L("einmalig", "one-time"),
                            subline: L("Einmal zahlen, für immer nutzen.",
                                       "Pay once, use forever."),
                            selected: selected == .lifetime
                        )
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.18)) { selected = .lifetime } }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Text(L("Einmaliger In-App-Kauf oder Abo. Kündigung jederzeit möglich. Preise können variieren.",
                           "One-time purchase or subscription. Cancel anytime. Prices may vary."))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 2)

                    // CTA
                    GlassPrimaryButton(title: ctaText(), isLoading: isLoading) {
                        Task {
                            isLoading = true
                            await purchaseManager.purchase(plan: selected)
                            isLoading = false
                            if purchaseManager.hasUnlockedStatistics { close() }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .opacity(productsReady ? 1 : 0.6)
                    .disabled(!productsReady || isLoading)

                    Text(L("Jederzeit kündbar • Kein Risiko", "Cancel anytime • No risk"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.top, 4)

                    footer
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
                .padding(.top, 8)
            }
            .background(Color.clear)
            .modifier(HideScrollBG())
        }
        .interactiveDismissDisabled(true)
        .colorScheme(.dark)
        .preferredColorScheme(.dark)
        .onChange(of: purchaseManager.hasUnlockedStatistics) { unlocked in
            if unlocked { close() }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Button {
                Task {
                    isLoading = true
                    await purchaseManager.restorePurchases()
                    isLoading = false
                    if purchaseManager.hasUnlockedStatistics { close() }
                }
            } label: {
                Text(L("Wiederherstellen", "Restore"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
            }
            .disabled(isLoading)

            Spacer()

            Button { close() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(10)
                    .background(.white, in: Circle())
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    // MARK: - Footer
    @State private var showPrivacySheet = false
    @State private var showTermsSheet   = false

    private var footer: some View {
        HStack(spacing: 18) {
            if let privacyURL {
                Link(L("Datenschutz", "Privacy"), destination: privacyURL)
                    .underline()
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Button { showPrivacySheet = true } label: {
                    Text(L("Datenschutz", "Privacy"))
                        .underline()
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            if let termsURL {
                Link(L("AGB", "Terms"), destination: termsURL)
                    .underline()
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Button { showTermsSheet = true } label: {
                    Text(L("AGB", "Terms"))
                        .underline()
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            
            if let eulaURL {
                          Link("EULA", destination: eulaURL)
                              .underline()
                              .foregroundStyle(.white.opacity(0.8))
                      }
            
            
            Button {
                   Task { await purchaseManager.redeemCode() }
               } label: {
                   Text(L("Code einlösen", "Redeem code"))
                       .underline()
                       .foregroundStyle(.white.opacity(0.8))
               }
               .buttonStyle(.plain)
            
            

            Spacer()
        }
        .sheet(isPresented: $showPrivacySheet) {
            NavigationStack { PrivacyPolicyView() }
        }
        .sheet(isPresented: $showTermsSheet) {
            NavigationStack { ImprintAGBView() }
        }
    }

    // MARK: - CTA Text
    private func ctaText() -> String {
        switch selected {
        case .yearly:
            return purchaseManager.introBadgeYearly != nil
                ? L("Gratis starten", "Start free trial")
                : L("Jahresabo abschließen", "Subscribe yearly")
        case .monthly:
            return L("Monatsabo abschließen", "Subscribe monthly")
        case .lifetime:
            return L("Lifetime kaufen", "Buy lifetime")
        }
    }

    // MARK: - Close Helper
    private func close() {
        if let onRequestClose { onRequestClose() }
        else { dismiss() }
    }
}

// MARK: - Helpers

private struct HideScrollBG: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

// MARK: - Feature Carousel

private struct PaywallFeatureCarousel: View {
    @State private var page: Int = 0
    @State private var didAppear = false

    var body: some View {
        VStack(spacing: 16) {
            TabView(selection: $page) {
                TemplatesFeatureCard().tag(0)
                StatisticsFeatureCard().tag(1)
                LiveActivityFeatureCard().tag(2)
                HeartRateFeatureCard().tag(3)
                WidgetsFeatureCard(style: .mediumBars)
                    .id("widgets_bars")
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Color.clear)
            .frame(height: 300)
            .onAppear { didAppear = true }

            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Color.white.opacity(0.9) : Color.white.opacity(0.28))
                        .frame(width: i == page ? 46 : 26, height: 7)
                        .animation(didAppear ? .easeInOut(duration: 0.22) : .none,
                                   value: page)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Launcher

struct PaywallLauncher: View {
    @State private var showPaywall = false
    @State private var dim = 0.0

    @EnvironmentObject var app: AppSettings
    @EnvironmentObject var pm: PurchaseManager

    var body: some View {
        ZStack {
            Button("Premium öffnen") {
                openPaywallSmooth()
            }

            Color.black
                .ignoresSafeArea()
                .opacity(dim)
                .allowsHitTesting(dim > 0)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(onRequestClose: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    dim = 0
                    showPaywall = false
                }
            })
            .environmentObject(app)
            .environmentObject(pm)
            .environment(\.colorScheme, .dark)
        }
    }

    private func openPaywallSmooth() {
        withAnimation(.easeInOut(duration: 0.20)) {
            dim = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            showPaywall = true
        }
    }
}

// MARK: - Glass Card

private struct GlassCard<Content: View>: View {
    var corner: CGFloat = 28
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(LinearGradient(colors: [
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.02)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .blur(radius: 28)

            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(.ultraThinMaterial)

            content().padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 20, y: 10)
    }
}

// MARK: - Feature Icon

private struct FeatureIconCircle: View {
    var tint: Color
    var system: String

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [tint.opacity(0.55), tint.opacity(0.28)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: system)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 52, height: 52)
    }
}

// MARK: - Templates Feature

private struct TemplatesFeatureCard: View {
    @EnvironmentObject var appSettings: AppSettings

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private func L(_ de: String, _ en: String) -> String { isDE ? de : en }

    private let accent = Color(hue: 0.65, saturation: 0.75, brightness: 1.0)

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    FeatureIconCircle(tint: accent, system: "list.bullet.rectangle.fill")
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Unbegrenzte Templates", "Unlimited templates"))
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text(L("Erstelle & nutze so viele Vorlagen wie du willst.",
                               "Create and use as many templates as you like."))
                            .foregroundColor(.white.opacity(0.85))
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                    }
                    Spacer()
                }

                VStack(spacing: 10) {
                    templateRow(title: L("Push", "Push"), count: 6)
                    templateRow(title: L("Pull", "Pull"), count: 4)
                }
            }
        }
    }

    private func templateRow(title: String, count: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(accent.opacity(0.16))
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(accent)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(accent)
                Text("\(count) " + L("Übungen", "exercises"))
                    .foregroundColor(.white.opacity(0.7))
                    .font(.subheadline)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(12)
        .background(Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - Statistics Feature

private struct StatisticsFeatureCard: View {
    @EnvironmentObject var appSettings: AppSettings

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private func L(_ de: String, _ en: String) -> String { isDE ? de : en }

    private let accentA = PaywallTheme.accentA
    private let accentB = PaywallTheme.accentB

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    FeatureIconCircle(tint: .purple, system: "chart.bar.fill")
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Statistiken", "Statistics"))
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text(L("Bestes Training, Dauer & Top-Übungen.",
                               "Best workout, duration & top exercises."))
                            .foregroundColor(.white.opacity(0.85))
                            .font(.subheadline)
                    }
                    Spacer()
                }

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach([12, 24, 10, 48, 6, 22, 14], id: \.self) { h in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(colors: [accentA, accentB],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: 14, height: CGFloat(8 + h))
                            .opacity(0.9)
                    }
                }
                .frame(height: 70)
                .padding(.top, 2)

                HStack(spacing: 12) {
                    kpi(title: L("Trainings", "Workouts"), value: "5")
                    kpi(title: L("Zeit", "Time"), value: "49m")
                    kpi(title: L("Gewicht", "Weight"), value: "2.8 t")
                }
            }
        }
    }

    private func kpi(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Heart Rate Feature

private struct HeartRateFeatureCard: View {
    @EnvironmentObject var appSettings: AppSettings

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private func L(_ de: String, _ en: String) -> String { isDE ? de : en }

    private let accent = Color(red: 0.45, green: 0.50, blue: 1.0)

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    FeatureIconCircle(tint: .red, system: "heart.fill")
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Herzfrequenz im Training", "Heart rate during workouts"))
                            .font(.title2.bold())
                            .foregroundColor(.white)
                    }
                    Spacer()
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color.black.opacity(0.97))
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 18, y: 10)

                    VStack(alignment: .leading, spacing: 14) {
                        Text(L("Push Workout", "Push workout"))
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)

                        HStack(spacing: 10) {
                            chip(icon: "calendar", text: L("11. Dez 2025", "11 Dec 2025"))
                            chip(icon: "timer", text: "0m 25s")
                            Spacer()
                        }

                        HStack(spacing: 14) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle().fill(accent)
                                    Image(systemName: "pause.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .frame(width: 30, height: 30)

                                Text("01:00")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(Color.white.opacity(0.06))
                            )

                            Spacer()

                            HStack(spacing: 6) {
                                Text("64")
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                    }
                    .padding(18)
                }
                .frame(height: 170)
            }
        }
    }

    private func chip(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(Color.white.opacity(0.10))
        )
    }
}

// MARK: - Live Activity Feature

private struct LiveActivityFeatureCard: View {
    @EnvironmentObject var appSettings: AppSettings

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private func L(_ de: String, _ en: String) -> String { isDE ? de : en }

    private let accent = Color.cyan

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    FeatureIconCircle(tint: accent, system: "play.circle.fill")
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Live Activity", "Live Activity"))
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text(L("Fortschritt direkt auf dem Sperrbildschirm.",
                               "Progress right on your Lock Screen."))
                            .foregroundColor(.white.opacity(0.85))
                            .font(.subheadline)
                    }
                    Spacer()
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.black.opacity(0.75))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)

                    HStack(spacing: 0) {
                        metric(icon: "figure.strengthtraining.traditional",
                               value: "0", title: L("Sätze", "Sets"))
                        divider
                        metric(icon: "clock",
                               value: "0m", title: L("Zeit", "Time"))
                        divider
                        metric(icon: "scalemass",
                               value: "0 kg", title: L("Gewicht", "Weight"))
                    }
                    .padding(.horizontal, 18)
                }
                .frame(height: 86)
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 34)
            .padding(.horizontal, 16)
    }

    private func metric(icon: String, value: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .foregroundColor(.white)
                    .font(.headline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(title)
                    .foregroundColor(.white.opacity(0.7))
                    .font(.footnote)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widgets Feature

private enum WidgetPreviewStyle { case mediumBars, smallRing }

private struct WidgetsFeatureCard: View {
    @EnvironmentObject var appSettings: AppSettings

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private func L(_ de: String, _ en: String) -> String { isDE ? de : en }

    let style: WidgetPreviewStyle

    private let ringA = PaywallTheme.accentA
    private let ringB = PaywallTheme.accentB

    var body: some View {
        GlassCard(corner: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    iconCircle(system: "square.grid.2x2.fill", tint: .purple)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Widgets", "Widgets"))
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text(L("iOS-Widgets für Verlauf & Schritte.",
                               "iOS widgets for history & steps."))
                            .foregroundColor(.white.opacity(0.85))
                            .font(.subheadline)
                    }
                    Spacer()
                }
                .padding(.bottom, 12)

                switch style {
                case .mediumBars:
                    widgetPreviewMediumBars()
                case .smallRing:
                    widgetPreviewSmallRing()
                }
            }
        }
    }

    private func widgetBackground(corner: CGFloat = 22) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color.black.opacity(0.88))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    private func widgetPreviewMediumBars() -> some View {
        ZStack {
            widgetBackground()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(.white.opacity(0.8))
                    Text(L("Schritte – 7 Tage", "Steps – 7 days"))
                        .foregroundStyle(.white.opacity(0.8))
                        .font(.subheadline.weight(.semibold))
                }

                Text("35.073")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach([0.35, 0.78, 0.42, 0.40, 0.38, 0.62, 0.05], id: \.self) { h in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(LinearGradient(colors: [ringA, ringB],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: 16, height: 76 * h)
                            .opacity(0.95)
                    }
                }
                .padding(.vertical, 4)

                HStack {
                    Text(L("Summe 35.073 • Ø 5.010",
                           "Total 35,073 • avg 5,010"))
                    Spacer()
                    Text(L("Ziel 8.000", "Goal 8,000"))
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
            }
            .padding(14)
        }
        .frame(height: 156)
    }

    private func widgetPreviewSmallRing() -> some View {
        ZStack {
            widgetBackground()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.grid.2x2")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Movo")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                }

                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.20), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: 0.80)
                            .stroke(
                                LinearGradient(colors: [ringA, ringB],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        Text("4")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 68, height: 68)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("KW 43", "Week 43"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(L("Ziel 3/Wo.", "Goal 3/week"))
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        }
        .frame(height: 156)
    }

    private func iconCircle(system: String, tint: Color) -> some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [tint.opacity(0.55), tint.opacity(0.28)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: system)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 52, height: 52)
    }
}

// MARK: - Plan Card

private struct PlanCardGlass: View {
    var title: String
    var leftPill: String?
    var rightBadge: String?
    var price: String
    var periodLabel: String?
    var subline: String?
    var selected: Bool
    var glow: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(colors: [Color.white.opacity(0.10),
                                                    Color.white.opacity(0.02)],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                        .blur(radius: 16)
                )
                .shadow(color: .black.opacity(selected ? 0.35 : 0.25),
                        radius: selected ? 18 : 10, y: 10)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    if let leftPill {
                        Text(leftPill.uppercased())
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(colors: [PaywallTheme.accentA.opacity(0.28),
                                                        PaywallTheme.accentB.opacity(0.28)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.18))
                            )
                            .foregroundStyle(.white)
                    }

                    if let subline, !subline.isEmpty {
                        Text(subline)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(price)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    if let periodLabel {
                        Text(periodLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            .padding(18)

            if let rightBadge {
                Text(rightBadge.uppercased())
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(colors: [PaywallTheme.accentA, PaywallTheme.accentB],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Capsule()
                    )
                    .foregroundStyle(.black.opacity(0.85))
                    .padding(10)
            }
        }
        .overlay(NeonOutline(corner: 22, active: selected, showGlow: glow))
        .padding(.vertical, 2)
    }
}

private struct NeonOutline: View {
    var corner: CGFloat = 22
    var active: Bool = false
    var showGlow: Bool = false

    private let g = LinearGradient(
        colors: [PaywallTheme.accentA, PaywallTheme.accentB],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            if showGlow {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(g, lineWidth: 6)
                    .blur(radius: 14)
                    .opacity(0.95)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
            let borderStyle: AnyShapeStyle = active
                ? AnyShapeStyle(g)
                : AnyShapeStyle(Color.white.opacity(0.14))

            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(borderStyle, lineWidth: active ? 2 : 1)
                .compositingGroup()
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Glasiger Primary Button

private struct GlassPrimaryButton: View {
    var title: String
    var isLoading: Bool
    var action: () -> Void

    var body: some View {
        Button {
            guard !isLoading else { return }
            action()
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            HStack(spacing: 10) {
                if isLoading { ProgressView().tint(.white) }
                Text(title).font(.headline.weight(.bold))
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule().stroke(
                    LinearGradient(colors: [PaywallTheme.accentA, PaywallTheme.accentB],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.2
                )
            )
            .shadow(color: .black.opacity(0.35), radius: 16, y: 10)
            .foregroundStyle(.white)
        }
    }
}

// MARK: - Paywalled Overlay (wie gehabt)

public enum PaywallFit { case fill, content }

public struct Paywalled<Content: View>: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var appSettings: AppSettings
    @Environment(\.colorScheme) private var colorScheme

    @Binding private var showPaywall: Bool
    private let content: Content
    private var icon: String
    private var subtitle: String?
    private var cornerRadius: CGFloat
    private var fit: PaywallFit

    public init(
        showPaywall: Binding<Bool>,
        icon: String = "crown.fill",
        subtitle: String? = nil,
        cornerRadius: CGFloat = 22,
        fit: PaywallFit = .fill,
        @ViewBuilder content: () -> Content
    ) {
        self._showPaywall = showPaywall
        self.icon = icon
        self.subtitle = subtitle
        self.cornerRadius = cornerRadius
        self.fit = fit
        self.content = content()
    }

    public var body: some View {
        ZStack {
            content
                .blur(radius: purchaseManager.hasUnlockedStatistics ? 0 : 2.5)
                .allowsHitTesting(purchaseManager.hasUnlockedStatistics)

            if !purchaseManager.hasUnlockedStatistics {
                overlaySizedToFit()
            }
        }
    }

    @ViewBuilder
    private func overlaySizedToFit() -> some View {
        switch fit {
        case .fill:
            overlayCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { showPaywall = true }
        case .content:
            GeometryReader { proxy in
                overlayCard
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(colorScheme == .dark ? 0.12 : 0.18))
                    )
            }
            .allowsHitTesting(true)
            .contentShape(Rectangle())
            .onTapGesture { showPaywall = true }
        }
    }

    private var overlayCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(colorScheme == .dark ? 0.32 : 0.22))

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            VStack(spacing: 14) {
                LinearGradient(colors: [.purple, .blue],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .mask(Image(systemName: icon).font(.system(size: 30, weight: .semibold)))
                    .frame(height: 30)

                VStack(spacing: 6) {
                    Text(appSettings.localized("premium.locked"))
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text(subtitle ?? appSettings.localized("paywall.h2"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    showPaywall = true
                } label: {
                    Text(appSettings.localized("premium.unlock"))
                        .fontWeight(.semibold)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(colors: [.blue, .cyan],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .accessibilityHint(appSettings.localized("premium.unlock"))
            }
            .padding(20)
        }
        .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Optional Premium Teaser Card (wie gehabt)

private struct PremiumTeaserCard: View {
    @EnvironmentObject var appSettings: AppSettings

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private func L(_ de: String, _ en: String) -> String { isDE ? de : en }

    var tap: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(
                        LinearGradient(colors: [.purple.opacity(0.6), .blue.opacity(0.6)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.white)
                        .font(.title2.bold())
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Premium-Statistiken", "Premium statistics"))
                        .font(.headline)
                    Text(L("Beta: Alle Pro-Features sind aktuell kostenlos.",
                           "Beta: All pro features are currently free."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            VStack(spacing: 10) {
                row(icon: "chart.bar.fill",
                    title: L("Erweiterte Diagramme & Trends",
                             "Advanced charts & trends"))
                row(icon: "trophy.fill",
                    title: L("Bestes Training & Rekorde",
                             "Best workouts & records"))
                row(icon: "timer",
                    title: L("Dauer, Volumen, Top-Übungen",
                             "Duration, volume, top exercises"))
                row(icon: "square.grid.2x2",
                    title: L("Widgets auf dem Homescreen",
                             "Widgets on the Home Screen"))
            }

            Button(action: tap) {
                Text(L("Kostenlos testen", "test for free"))
                    .fontWeight(.bold)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(colors: [.blue, .purple],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(radius: 8, y: 4)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func row(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 44, height: 44)
                Image(systemName: icon).foregroundStyle(.primary)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

