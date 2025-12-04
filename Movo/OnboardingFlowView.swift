// OnboardingFlowView.swift – FINAL (iPad fix, scrolls when needed, Dark Mode fix)

import SwiftUI
import UserNotifications
import HealthKit

// Falls noch nicht global definiert:
// let kOnboardingKey = "onboarding.completed"

// Brand & Background
private let brand      = Color(hex: 0x4C5BFF)   // Periwinkle-Blau
private let bgDeepA    = Color(hex: 0x0A0E19)   // sehr dunkles Navy
private let bgDeepB    = Color(hex: 0x0D1222)   // sehr dunkles Navy
private let brandTintA = Color(hex: 0x3846E8)   // gedämpfter Brand-Ton

struct OnboardingFlowView: View {
    var onFinished: (() -> Void)? = nil

    // Abhängigkeiten
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var healthKit: HealthKitManager

    // User Defaults
    @AppStorage("units.weight") private var weightUnit: WeightUnit = .kg
    @AppStorage("profile.weightKg") private var weightKg: Double = 70
    @AppStorage("profile.heightCm") private var heightCm: Double = 175
    @AppStorage("steps.goal") private var stepsGoal: Int = 10_000
    @AppStorage(kOnboardingKey) private var completed: Bool = false

    // UI State
    @State private var page: Int = 0
    private let pages: [Page] = Page.all

    enum Page: Int, CaseIterable {
        case welcome, log, challenges, stats, history, units, bodyweight, height, permissions, steps, week, done
        static var all: [Page] {
            [.welcome, .log, .challenges, .stats, .history,
             .units, .bodyweight, .height, .permissions, .steps, .week, .done]
        }
        var isLast: Bool { self == .done }
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(colors: [bgDeepA, bgDeepB],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            LinearGradient(colors: [brandTintA.opacity(0.18), .clear],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            // Vollflächiges Paging
            TabView(selection: $page) {
                welcome.tag(Page.welcome.rawValue)
                logFast.tag(Page.log.rawValue)
                challenges.tag(Page.challenges.rawValue)
                statistics.tag(Page.stats.rawValue)
                historyPreview.tag(Page.history.rawValue)
                units.tag(Page.units.rawValue)
                bodyweight.tag(Page.bodyweight.rawValue)
                height.tag(Page.height.rawValue)
                permissions.tag(Page.permissions.rawValue)
                stepsPreview.tag(Page.steps.rawValue)
                weekOverview.tag(Page.week.rawValue)
                final.tag(Page.done.rawValue)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)
            .background(.clear) // wichtig: TabView selbst transparent
        }
        .colorScheme(.dark)            // erzwingt dunkle Inhalte in diesem View
        .preferredColorScheme(.dark)   // (optional) gleiche Absicht für übergeordnete Container

        // Bars nehmen der TabView keine Höhe
        .safeAreaInset(edge: .top) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .onChange(of: stepsGoal) { new in
            healthKit.dailyGoal = new
            healthKit.refreshToday()
        }
    }

    // MARK: - Top / Bottom

    private var topBar: some View {
        HStack {
            if page > 0 {
                Button {
                    withAnimation(.spring()) {
                        page = max(0, page - 1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                }
            } else {
                Color.clear
                    .frame(width: 24, height: 24)
            }

            Spacer()

            Button("Überspringen") {
                finish()
            }
            .font(.subheadline.weight(.semibold))
        }
        .tint(brand)
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            Dots(count: pages.count, index: page, accent: brand)

            Button {
                if page == Page.permissions.rawValue {
                    NotificationManager.shared.requestAuthorizationIfNeeded(
                        forcePrompt: true,
                        appSettings: appSettings
                    )
                    Task {
                        await requestHealthIfNeeded(forcePrompt: true)
                    }
                }

                if page < pages.count - 1 {
                    withAnimation(.spring()) {
                        page += 1
                    }
                } else {
                    finish()
                }
            } label: {
                Text(page == pages.count - 1
                     ? localized("common.start", fallback: "Los geht’s")
                     : localized("common.continue", fallback: "Weiter"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(brand)
        }
    }

    // MARK: - Pages
    // Jede Seite nutzt .onboardingPage() → bei wenig Höhe automatisch ScrollView

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            TitleBlock(
                title: "Willkommen bei Movo",
                highlight: "Fokus statt Schnickschnack.",
                subtitle: "Logge Workouts, halte Streaks, beobachte deinen Fortschritt."
            )
            IconHero(name: "figure.strengthtraining.traditional", tint: brand)
            FeatureRow(icon: "bolt.fill",  title: "Blitzschnelles Logging",
                       text: "Sätze, Gewichte, Wdh. – alles mit einem Tap.")
            FeatureRow(icon: "flame.fill", title: "Streaks & Badges",
                       text: "Bleib dran und sammle Belohnungen.")
            Spacer()
        }
        .onboardingPage()
    }

    private var logFast: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            TitleBlock(
                title: "Workouts loggen",
                highlight: "ohne Hürden.",
                subtitle: "Training starten, Sets abhaken, fertig."
            )
            DemoCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Arnold Press (Dumbbell)", systemImage: "dumbbell.fill")
                        .font(.headline)
                    HStack(spacing: 8) {
                        chip("12.5", "kg")
                        chip("10", "Wdh")
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            FeatureRow(icon: "clock.badge.checkmark",
                       title: "Pausen-Timer",
                       text: "Mit Haptik & Benachrichtigung.")
            FeatureRow(icon: "arrow.up.arrow.down",
                       title: "Drag & Drop",
                       text: "Übungen frei sortieren.")
            Spacer()
        }
        .onboardingPage()
    }

    private var challenges: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            TitleBlock(
                title: "Challenges",
                highlight: "die motivieren.",
                subtitle: "Ziele wie „5 Workouts/Woche“ oder „12.000 Schritte/Tag“."
            )
            DemoCard {
                VStack(alignment: .leading, spacing: 12) {
                    challengeRow(title: "5 Workouts pro Woche",
                                 progress: 0.6,
                                 info: "3/5 Workouts")
                    challengeRow(title: "12.000 Schritte/Tag",
                                 progress: 0.35,
                                 info: "4.156/12.000")
                }
            }
            FeatureRow(icon: "star.fill",
                       title: "Abzeichen",
                       text: "Erreiche Meilensteine und sammle Badges.")
            Spacer()
        }
        .onboardingPage()
    }

    private var statistics: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            TitleBlock(
                title: "Statistiken",
                highlight: "klar & hilfreich.",
                subtitle: "Volumen, PRs, Trends, Schritt-Ziele."
            )
            DemoCard {
                HStack(spacing: 10) {
                    stat("Volumen", "10.4k", "kg")
                    stat("Sätze", "18", nil)
                    stat("Wdh",  "132", nil)
                }
            }
            FeatureRow(icon: "chart.bar.xaxis",
                       title: "Wöchentliche Trends",
                       text: "Sieh sofort, wie deine Woche lief.")
            Spacer()
        }
        .onboardingPage()
    }

    private var historyPreview: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            TitleBlock(
                title: "Trainingsverlauf",
                highlight: "",
                subtitle: "Alles chronologisch – inkl. Volumen & Details."
            )
            DemoCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("October 2025")
                        .font(.title2.bold())
                    historyRow(emoji: "💪", title: "Push",
                               date: "22. October 2025",
                               meta: "Volumen: 2.811 kg")
                    historyRow(emoji: "💪", title: "Pull",
                               date: "20. October 2025",
                               meta: "Volumen: 1.964 kg")
                    historyRow(emoji: "💪", title: "Oberkörper",
                               date: "20. October 2025",
                               meta: "Volumen: 2.104 kg")
                    historyRow(emoji: "💪", title: "Legs",
                               date: "19. October 2025",
                               meta: "Volumen: 1.742 kg")
                }
            }
            Spacer()
        }
        .onboardingPage()
    }

    private var units: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            TitleBlock(
                title: "Welche Einheiten?",
                highlight: "",
                subtitle: "Du kannst das später jederzeit ändern."
            )
            HStack(spacing: 14) {
                UnitCard(selected: weightUnit == .kg,
                         icon: "scalemass",
                         title: "Kilogramm") {
                    weightUnit = .kg
                }
                UnitCard(selected: weightUnit == .lb,
                         icon: "scalemass.fill",
                         title: "Pounds") {
                    weightUnit = .lb
                }
            }
            Text("Aktuell: \(weightUnit == .kg ? "kg" : "lb")")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .onboardingPage()
    }

    private var bodyweight: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            TitleBlock(
                title: "Dein Körpergewicht",
                highlight: "",
                subtitle: "Für bessere Empfehlungen & Analysen."
            )
            DemoCard {
                VStack(spacing: 12) {
                    Text("\(formatNumber(weightDisplay)) \(weightUnit == .kg ? "kg" : "lb")")
                        .font(.system(size: 40,
                                      weight: .bold,
                                      design: .rounded))
                        .monospacedDigit()
                    Slider(
                        value: Binding(
                            get: { weightDisplay },
                            set: { v in
                                weightKg = (weightUnit == .kg)
                                    ? v
                                    : WeightUnit.lb.toKilograms(v)
                            }
                        ),
                        in: weightUnit == .kg ? 40...180 : 90...400,
                        step: 0.5
                    )
                    .tint(brand)
                }
            }
            Spacer()
        }
        .onboardingPage()
    }

    private var height: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            TitleBlock(
                title: "Deine Größe",
                highlight: "",
                subtitle: "Wird für BMI & Empfehlungen genutzt."
            )
            DemoCard {
                VStack(spacing: 12) {
                    Text("\(Int(heightCm)) cm")
                        .font(.system(size: 40,
                                      weight: .bold,
                                      design: .rounded))
                        .monospacedDigit()
                    Slider(value: $heightCm,
                           in: 140...210,
                           step: 1)
                        .tint(brand)
                }
            }
            Spacer()
        }
        .onboardingPage()
    }

    private var stepsPreview: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            TitleBlock(
                title: "Deine Schritte",
                highlight: "in Movo.",
                subtitle: "So sieht’s später in der App aus."
            )
            .lineLimit(2)
            .minimumScaleFactor(0.9)

            DemoCard {
                VStack(alignment: .leading, spacing: 16) {
                    // Kopf: Donut-Ring + Werte
                    HStack(spacing: 14) {
                        RingProgress(progress: progressToday, size: 82)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Schritte")
                                .font(.subheadline.weight(.semibold))
                            Text("\(healthKit.todaySteps.formatted(.number.grouping(.automatic))) / \(stepsGoal.formatted(.number.grouping(.automatic)))")
                                .font(.headline.monospacedDigit())
                        }
                        Spacer()
                    }

                    // Ziel mit Snap + Presets
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(stepsGoal.formatted(.number.grouping(.automatic))) Schritte")
                            .font(.system(size: 32,
                                          weight: .bold,
                                          design: .rounded))
                            .monospacedDigit()

                        Slider(
                            value: Binding(
                                get: { Double(stepsGoal) },
                                set: { v in
                                    stepsGoal = clampToRange(
                                        roundTo500(Int(v)),
                                        min: 3_000,
                                        max: 20_000
                                    )
                                }
                            ),
                            in: 3_000...20_000,
                            step: 500
                        )
                        .tint(brand)

                        HStack(spacing: 8) {
                            ForEach([8_000, 10_000, 15_000], id: \.self) { preset in
                                GoalChip(
                                    value: preset,
                                    selected: stepsGoal == preset
                                ) {
                                    stepsGoal = preset
                                }
                            }
                        }
                    }

                    // Mini-Bar-Chart (Demo)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Verlauf (7 Tage)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        let bars = demoLast7Days()
                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(bars, id: \.self) { v in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(brand.opacity(v >= 1 ? 1 : 0.55))
                                    .frame(width: 16,
                                           height: max(6, CGFloat(v) * 56))
                            }
                        }
                        .frame(height: 64, alignment: .bottom)
                    }
                }
            }
            .onAppear {
                healthKit.dailyGoal = stepsGoal
                healthKit.refreshToday()
            }

            Spacer()
        }
        .onboardingPage()
    }

    private var weekOverview: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            TitleBlock(
                title: "Home- & Wochenansicht",
                highlight: "",
                subtitle: "Geplante Sessions, Warm-up, Übungen, Cool-down."
            )
            .padding(.top, 4)
            .lineLimit(2)
            .minimumScaleFactor(0.85)

            DemoCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Woche 1")
                        .font(.headline)

                    HStack(spacing: 8) {
                        labelPill("~20 min",  "Dauer")
                        labelPill("~158 kcal","Kalorien")
                        labelPill("Brust",    "Fokus")
                    }

                    Divider().opacity(0.15)

                    VStack(spacing: 10) {
                        ForEach(sampleExercises(), id: \.self) { name in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "figure.strengthtraining.traditional")
                                    )

                                Text(name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    .overlay(
                                        Text("35s × 3 Rdn")
                                            .font(.caption)
                                    )
                                    .frame(width: 120, height: 28)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.05))
                            )
                        }
                    }
                }
            }
            Spacer()
        }
        .onboardingPage()
    }

    private var permissions: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            TitleBlock(
                title: "Noch zwei Dinge",
                highlight: "",
                subtitle: "Bitte erlauben – jederzeit änderbar in den Einstellungen."
            )
            VStack(spacing: 12) {
                PermissionRow(
                    icon: "heart.fill",
                    title: "Apple Health",
                    desc: "Schritte & Kalorien synchronisieren."
                ) {
                    Task {
                        await requestHealthIfNeeded(forcePrompt: true)
                        healthKit.dailyGoal = stepsGoal
                        healthKit.refreshToday()
                    }
                }

                PermissionRow(
                    icon: "bell.badge.fill",
                    title: "Mitteilungen",
                    desc: "Pausen-Timer & Streak-Hinweise."
                ) {
                    NotificationManager.shared.requestAuthorizationIfNeeded(
                        forcePrompt: true,
                        appSettings: appSettings
                    )
                }
            }
            Spacer()
        }
        .onboardingPage()
    }

    private var final: some View {
        VStack(spacing: 24) {
            Spacer()
            TitleBlock(
                title: "Alles bereit!",
                highlight: "Viel Spaß mit Movo.",
                subtitle: "Du kannst später alles in den Einstellungen anpassen."
            )
            IconHero(name: "checkmark.seal.fill", tint: brand)
            Spacer()
        }
        .onboardingPage()
    }

    // MARK: - Helpers

    private func finish() {
        completed = true
        healthKit.dailyGoal = stepsGoal
        healthKit.refreshToday()
        onFinished?()
        dismiss()
    }

    private func requestHealthIfNeeded(forcePrompt: Bool = false) async {
        await healthKit.requestReadAuthorizationIfNeeded(
            readTypes: [
                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                HKObjectType.quantityType(forIdentifier: .bodyMass)!,
                HKObjectType.quantityType(forIdentifier: .height)!,
                HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
                HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
            ],
            forcePrompt: forcePrompt
        )
    }

    private func localized(_ key: String, fallback: String) -> String {
        let v = appSettings.localized(key) ?? fallback
        return v == key ? fallback : v
    }

    private var weightDisplay: Double {
        weightUnit == .kg ? weightKg : WeightUnit.lb.fromKilograms(weightKg)
    }

    private func formatNumber(_ value: Double, decimals: Int = 1) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = decimals
        nf.maximumFractionDigits = decimals
        return nf.string(from: NSNumber(value: value))
        ?? String(format: "%.\(decimals)f", value)
    }

    private var progressToday: CGFloat {
        guard stepsGoal > 0 else { return 0 }
        return CGFloat(
            min(1.0,
                Double(healthKit.todaySteps) / Double(stepsGoal))
        )
    }

    private func demoLast7Days() -> [Double] {
        [0.85, 0.48, 0.32, 0.46, 0.41, 1.0, 0.38]
    }

    private func sampleExercises() -> [String] {
        ["Jumping Jacks", "Hip Opener", "Liegestütze", "Superman Pulls", "Plank"]
    }

    private func chip(_ value: String, _ unit: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .bold()
                .monospacedDigit()
            Text(unit)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(Color.white.opacity(0.08))
        )
    }

    private func stat(_ title: String,
                      _ value: String,
                      _ unit: String?) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Group {
                if let unit {
                    Text(value)
                        .font(.title3.bold())
                        .monospacedDigit()
                    + Text(" \(unit)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text(value)
                        .font(.title3.bold())
                        .monospacedDigit()
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .allowsTightening(true)
        }
        .frame(maxWidth: .infinity,
               minHeight: 68)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08),
                        lineWidth: 0.5)
        )
    }

    private func labelPill(_ value: String,
                           _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func challengeRow(title: String,
                              progress: Double,
                              info: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.15),
                                      lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            brand,
                            style: StrokeStyle(
                                lineWidth: 6,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    ProgressView(value: progress)
                        .tint(brand)
                }
                Spacer()
            }
            Text(info)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func historyRow(emoji: String,
                            title: String,
                            date: String,
                            meta: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(brand.opacity(0.16))
                Text(emoji)
                    .font(.title3)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(meta)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "trash")
                .foregroundStyle(.red)
                .font(.title3)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
    }
}

// MARK: - Reusable building blocks

private struct RingProgress: View {
    var progress: CGFloat     // 0...1
    var size: CGFloat = 88

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Circle()
                .stroke(Color.white.opacity(0.15),
                        lineWidth: 12)
            Circle()
                .trim(from: 0,
                      to: max(0.001, min(progress, 1)))
                .stroke(
                    AngularGradient(
                        colors: [brand, brand.opacity(0.9)],
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: 12,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: brand.opacity(0.35),
                        radius: 6)
        }
        .frame(width: size, height: size)
    }
}

private struct GoalChip: View {
    let value: Int
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(value.formatted(.number.grouping(.automatic)))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        selected
                        ? brand.opacity(0.22)
                        : Color.white.opacity(0.06)
                    )
                )
                .overlay(
                    Capsule().stroke(
                        selected ? brand : Color.white.opacity(0.12),
                        lineWidth: selected ? 1.2 : 0.8
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

// Slider-Snap-Helpers
private func roundTo500(_ v: Int) -> Int {
    let step = 500
    let r = Int((Double(v) / Double(step)).rounded()) * step
    return r
}

private func clampToRange(_ v: Int, min: Int, max: Int) -> Int {
    Swift.max(min, Swift.min(max, v))
}

// MARK: - Utilities

private struct TitleBlock: View {
    let title: String
    let highlight: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            (Text(title)
             + (highlight.isEmpty
                ? Text("")
                : Text(" ") + Text(highlight)))
            .font(.system(size: 34,
                          weight: .heavy,
                          design: .rounded))
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity,
               alignment: .leading)
    }
}

private struct IconHero: View {
    let name: String
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.18))
            Image(systemName: name)
                .font(.system(size: 48,
                              weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: 132, height: 132)
        .padding(.vertical, 8)
        .accessibilityHidden(true)
    }
}

private struct DemoCard<Content: View>: View {
    @Environment(\.designTokens) private var t
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: 620)
        .background(
            RoundedRectangle(cornerRadius: 18,
                             style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(t.palette.outline,
                        lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.18),
                radius: 12,
                y: 6)
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                Image(systemName: icon)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
    }
}

private struct UnitCard: View {
    let selected: Bool
    let icon: String
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity,
                   minHeight: 110)
            .background(
                RoundedRectangle(cornerRadius: 16,
                                 style: .continuous)
                    .fill(
                        Color.white.opacity(
                            selected ? 0.14 : 0.06
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16,
                                 style: .continuous)
                    .stroke(
                        selected
                        ? .white.opacity(0.6)
                        : .white.opacity(0.12),
                        lineWidth: selected ? 1.2 : 0.8
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let desc: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                Image(systemName: icon)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(desc)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Erlauben", action: action)
                .buttonStyle(.bordered)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
    }
}

private struct Dots: View {
    let count: Int
    let index: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(
                        i == index
                        ? accent
                        : .white.opacity(0.2)
                    )
                    .frame(width: i == index ? 22 : 6,
                           height: 6)
                    .animation(
                        .spring(response: 0.35,
                                dampingFraction: 0.8),
                        value: index
                    )
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Color util

private extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue:  Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - iPad width helper

struct ConstrainedWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var hSize

    func body(content: Content) -> some View {
        let isPad = hSize == .regular
        return content
            .frame(
                maxWidth: isPad ? 560 : .infinity,
                alignment: .center
            )
            .padding(.horizontal, isPad ? 32 : 16)
    }
}

extension View {
    func iPadConstrained() -> some View {
        modifier(ConstrainedWidth())
    }
}

// MARK: - Adaptive page wrapper

private struct AdaptivePage<Content: View>: View {
    @Environment(\.verticalSizeClass) private var vSize
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            let shouldScroll =
                vSize == .compact || proxy.size.height < 700

            Group {
                if shouldScroll {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            content
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 140) // Platz für Weiter-Button + Dots
                        .iPadConstrained()
                    }
                } else {
                    VStack(spacing: 24) {
                        content
                    }
                    .iPadConstrained()
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .top
                    )
                }
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height,
                alignment: .top
            )
        }
    }
}

private extension View {
    /// Einheitlicher Wrapper für alle Onboarding-Seiten.
    func onboardingPage() -> some View {
        AdaptivePage { self }
    }
}
// Ganz unten in der Datei (oder in eine Utils-Datei)

