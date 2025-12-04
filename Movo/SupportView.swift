import SwiftUI
import MessageUI
import CloudKit
#if os(iOS) || os(visionOS)
import UIKit
#endif

struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings

    // Mail
    @State private var showMailSheet = false
    @State private var showMailUnavailableAlert = false
    private let supportAddress: String = DeveloperProfile.email

    // Cloud (ohne E-Mail)
    @State private var showCloudSheet = false
    @State private var ticketSubject = ""
    @State private var ticketMessage = ""
    @State private var isSending = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(appSettings.localized("settings.support.title"))
                        .font(.largeTitle.bold())
                    Text(appSettings.localized("settings.support.subtitle"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Card: E-Mail Support (bestehend)
                VStack(spacing: 16) {
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)

                    VStack(spacing: 4) {
                        Text(L("Schreib uns direkt", "Contact us directly"))
                            .font(.title3.weight(.semibold))
                        Text(L("Wir hängen Basisdiagnosen an, damit wir schneller helfen können.",
                               "We’ll attach basic diagnostics so we can help faster."))
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button { openSupportEmail() } label: {
                        Label(appSettings.localized("about.support.email"), systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text(L("Es werden App-Version, iOS-Version und Gerätetyp ergänzt.",
                           "App version, iOS version, and device type will be attached."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                .padding(.horizontal)

                // Card: Ohne E-Mail (CloudKit)
                VStack(spacing: 16) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 42, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)

                    VStack(spacing: 4) {
                        Text(L("Ohne E-Mail senden", "Send without Email"))
                            .font(.title3.weight(.semibold))
                        Text(L("Anfrage wird sicher in iCloud gespeichert. Wir sehen sie direkt im Dashboard. Bitte vergess nicht deinen Namen anzugeben damit wir dich identifizieren können",
                               "Your request will—hopefully—be saved safely in iCloud. We should see it on the dashboard right away. Please don’t forget to include your name, or we might not be able to identify you."))
                               
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        ticketSubject = ""
                        ticketMessage = ""
                        showCloudSheet = true
                    } label: {
                        Label(L("Support-Anfrage ohne Mail", "Support request (no email)"),
                              systemImage: "paperplane")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Text(L("Wir fügen App-Version, System und Gerät automatisch hinzu.",
                           "We’ll attach app version, system and device automatically."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                .padding(.horizontal)

                Spacer(minLength: 12)
            }
            .padding(.top, 16)
        }
        .background(
            LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                           startPoint: .top, endPoint: .bottom)
        )
        .navigationTitle(appSettings.localized("settings.support.title"))
        .navigationBarTitleDisplayMode(.inline)

        // Mail Sheet
        .sheet(isPresented: $showMailSheet) {
            SupportMailSheet(
                recipient: supportAddress,
                subject: defaultSubject(),
                body: defaultBody()
            )
        }
        // Mail Fallback Alert
        .alert(L("Mail nicht konfiguriert", "Mail not configured"),
               isPresented: $showMailUnavailableAlert) {
            Button(appSettings.localized("common.ok"), role: .cancel) { }
        } message: {
            Text(L("Bitte richte Mail ein oder schreibe an %@.",
                   "Please configure Mail or write to %@.")
                 .replacingOccurrences(of: "%@", with: supportAddress))
        }

        // Cloud Sheet
        .sheet(isPresented: $showCloudSheet) {
            SupportTicketSheet(
                subject: $ticketSubject,
                message: $ticketMessage,
                onSend: { subject, message in
                    guard !isSending else { return }
                    isSending = true
                    Task {
                        do {
                            try await CloudKitSupportService.shared.submit(
                                subject: subject,
                                message: message
                            )
                            #if os(iOS)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            #endif
                            showCloudSheet = false
                            showSuccessAlert = true
                        } catch {
                            #if os(iOS)
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                            #endif
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                        isSending = false
                    }
                }
            )
            .presentationDetents([.medium])
        }

        // Cloud: Erfolg
        .alert(L("Danke!", "Thank you!"), isPresented: $showSuccessAlert) {
            Button(appSettings.localized("common.ok")) { }
        } message: {
            Text(L("Deine Support-Anfrage wurde gespeichert.",
                   "Your support request has been saved."))
        }

        // Cloud: Fehler
        .alert(L("Fehler beim Senden", "Sending failed"), isPresented: $showErrorAlert) {
            Button(appSettings.localized("common.ok")) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Mail

    private func openSupportEmail() {
        #if canImport(MessageUI)
        if MFMailComposeViewController.canSendMail() {
            showMailSheet = true
            return
        }
        #endif
        if let url = mailtoURL() {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #endif
        } else {
            showMailUnavailableAlert = true
        }
    }

    private func defaultSubject() -> String {
        let app = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "App"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        return L("Support – %@ v%@", "Support – %@ v%@")
            .replacingOccurrences(of: "%@", with: app)
            .replacingOccurrences(of: "%@", with: version)
    }

    private func defaultBody() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let system  = UIDevice.current.systemName + " " + UIDevice.current.systemVersion
        let device  = UIDevice.current.model

        let hello = L("Hallo Support-Team,", "Hello support team,")
        let describe = L("[Bitte beschreibe dein Anliegen hier.]", "[Please describe your issue here.]")
        let dash = "———"
        let appLine = L("• App-Version:", "• App version:")
        let iosLine = L("• iOS:", "• iOS:")
        let devLine = L("• Gerät:", "• Device:")
        let timeLine = L("• Zeit:", "• Time:")

        return """
        \(hello)

        \(describe)

        \(dash)
        \(appLine) \(version) (\(build))
        \(iosLine) \(system)
        \(devLine) \(device)
        \(timeLine) \(Date().formatted(date: .abbreviated, time: .shortened))
        """
    }

    private func mailtoURL() -> URL? {
        let encodedSubject = defaultSubject().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody    = defaultBody().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:\(supportAddress)?subject=\(encodedSubject)&body=\(encodedBody)")
    }

    // i18n helper
    private func L(_ de: String, _ en: String) -> String {
        appSettings.language.lowercased().hasPrefix("de") ? de : en
    }
}

// MARK: - CloudKit Sheet

struct SupportTicketSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @Binding var subject: String
    @Binding var message: String
    var onSend: (_ subject: String, _ message: String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Betreff")) {
                    TextField("Kurzer Titel", text: $subject)
                        .textInputAutocapitalization(.sentences)
                }
                Section(header: Text("Nachricht")) {
                    TextEditor(text: $message)
                        .frame(minHeight: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 1)
                        )
                }
                Section(footer: Text("Wir hängen App-Version, System und Gerät an.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Support-Anfrage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Senden") {
                        let sub = subject.trimmingCharacters(in: .whitespacesAndNewlines)
                        let msg = message.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !sub.isEmpty, !msg.isEmpty else { return }
                        onSend(sub, msg)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - CloudKit Service (Public DB)

final class CloudKitSupportService {
    static let shared = CloudKitSupportService()
    private init() {}

    // 👉 Container-ID ggf. anpassen
    private let container = CKContainer(identifier: "iCloud.com.benepkt.Movo")
    fileprivate var db: CKDatabase { container.publicCloudDatabase }

    /// Speichert eine Support-Anfrage als `SupportTicket`-Record.
    func submit(subject: String, message: String) async throws {
        let status = try await container.accountStatus()
        switch status {
        case .available: break
        case .noAccount:
            throw NSError(domain: "CloudKit", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "iCloud ist auf diesem Gerät nicht eingerichtet."])
        case .restricted:
            throw NSError(domain: "CloudKit", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "iCloud ist eingeschränkt (Screen Time/MDM?)."])
        default:
            throw NSError(domain: "CloudKit", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "iCloud-Status konnte nicht ermittelt werden."])
        }

        let rec = CKRecord(recordType: "SupportTicket")
        rec["subject"] = subject as CKRecordValue
        rec["message"] = message as CKRecordValue

        // Meta
        let appName  = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? "App"
        let version  = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build    = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        #if os(iOS) || os(visionOS)
        let system   = UIDevice.current.systemName + " " + UIDevice.current.systemVersion
        let device   = UIDevice.current.model
        #else
        let system   = "macOS"
        let device   = "Mac"
        #endif

        rec["appName"]     = appName as CKRecordValue
        rec["appVersion"]  = "\(version) (\(build))" as CKRecordValue
        rec["system"]      = system as CKRecordValue
        rec["device"]      = device as CKRecordValue
        rec["locale"]      = Locale.current.identifier as CKRecordValue
        rec["createdAt"]   = Date() as CKRecordValue

        try await db.save(rec)
    }
}

// OPTIONAL: Wenn du die Tickets in der App listen willst, kannst du später Indizes
// (createdAt queryable/sortable) im CloudKit Dashboard anlegen und hier ein Fetch wie bei ExerciseRequest bauen.
#if canImport(MessageUI)
import MessageUI

struct SupportMailSheet: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            controller.dismiss(animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) { }
}
#else
// Fallback für Plattformen ohne MessageUI (z. B. macOS, Catalyst, Simulator-Konstellationen)
struct SupportMailSheet: View {
    let recipient: String
    let subject: String
    let body: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 40))
            Text("E-Mail-Versand nicht verfügbar")
                .font(.headline)
            Text("Bitte verwende die Cloud-Option oder kontaktiere uns manuell: \(recipient)")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}
#endif
