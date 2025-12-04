import SwiftUI
import Foundation
import CloudKit
#if os(iOS) || os(visionOS)
import UIKit
#endif

// MARK: - Haupt-View (CloudKit)

struct ExercisesView: View {
    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var trainingStore: TrainingStore
    @Environment(\.designTokens) private var t
    @Environment(\.colorScheme)   private var scheme

    @State private var newExercise = ""
    @State private var selectedExerciseInfo: ExerciseInfo?
    @State private var showNewExerciseSheet = false
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    // Request-States
    @State private var showRequestSheet = false
    @State private var requestName = ""
    @State private var requestDetails = ""

    // Feedback
    @State private var isSending = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    // Filter
    private var filteredExercises: [ExerciseInfo] {
        let all = exerciseLibrary.exercises
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {

                ScrollView {
                    VStack(spacing: 16) {
                        // MARK: Suche
                        searchBar

                        // MARK: Liste
                        LazyVStack(spacing: 16) {
                            if filteredExercises.isEmpty {
                                if searchText.isEmpty {
                                    emptyState
                                        .padding(.horizontal)
                                } else {
                                    noResultsState
                                        .padding(.horizontal)
                                }
                            } else {
                                ForEach(filteredExercises) { info in
                                    ExerciseCardView(info: info) {
                                        selectedExerciseInfo = info
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.top, 4)

                        Spacer(minLength: 40)
                    }
                }

                // MARK: FAB
                fabButton
            }
            .navigationTitle(appSettings.localized("exercises.title"))
            .sheet(item: $selectedExerciseInfo) { info in
                ExerciseDetailView(exerciseInfo: info)
                    .environmentObject(trainingStore)
            }
            .sheet(isPresented: $showNewExerciseSheet) {
                NewExerciseSheet(newExercise: $newExercise, onAdd: addExercise)
                    .presentationDetents([.medium])
            }
            // Request-Sheet
            .sheet(isPresented: $showRequestSheet) {
                ExerciseRequestSheet(
                    name: $requestName,
                    details: $requestDetails,
                    onSend: { name, details in
                        guard !isSending else { return }
                        isSending = true
                        Task {
                            do {
                                try await CloudKitExerciseRequestService.shared.submit(
                                    name: name,
                                    details: details,
                                    query: searchText
                                )
                                #if os(iOS)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                #endif
                                showRequestSheet = false
                                requestName = ""
                                requestDetails = ""
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
                .environmentObject(appSettings)
                .presentationDetents([.medium])
            }
            // Erfolg
            .alert(appSettings.localized("exercises.request.alert.success.title"), isPresented: $showSuccessAlert) {
                Button(appSettings.localized("common.ok")) { }
            } message: {
                Text(appSettings.localized("exercises.request.alert.success.message"))
            }
            // Fehler
            .alert(appSettings.localized("exercises.request.alert.error.title"), isPresented: $showErrorAlert) {
                Button(appSettings.localized("common.ok")) { }
            } message: {
                Text(errorMessage)
            }
        }
        // 👉 harter View-Neuaufbau beim Scheme-Wechsel (kein Ruckeln)
        .id(scheme)
        // 👉 in dieser View: keine Animation auf Scheme-Changes
        .animation(nil, value: scheme)
        .transaction { tx in tx.animation = nil }
    }

    // MARK: - Teil-Views

    private var searchBar: some View {
        let isDark = (scheme == .dark)

        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(appSettings.localized("exercises.search"), text: $searchText)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .textFieldStyle(.plain)
                .foregroundStyle(.primary)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(appSettings.localized("search.clear"))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isDark ? Color.white.opacity(0.08) : Color(UIColor.secondarySystemFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: isDark ? .black.opacity(0.20) : .black.opacity(0.06), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(appSettings.localized("settings.done")) { searchFocused = false }
            }
        }
    }

    private var fabButton: some View {
        let isDark = (scheme == .dark)

        return Button {
            showNewExerciseSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .padding(18)
                .background(
                    Circle()
                        .fill(t.palette.primary)
                        .shadow(color: isDark ? .black.opacity(0.25) : .black.opacity(0.18),
                                radius: isDark ? 8 : 12, x: 0, y: 6)
                )
                .foregroundStyle(.white)
        }
        .padding()
        .accessibilityLabel(appSettings.localized("exercises.addNew"))
        .animation(nil, value: scheme)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(appSettings.localized("templates.empty.subtitle"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(scheme == .dark ? 0.06 : 0.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(scheme == .dark ? Color.white.opacity(0.12) : t.palette.outline, lineWidth: 1)
        )
    }

    // No-Results-State mit lokalisierten Strings
    private var noResultsState: some View {
        let isDark = (scheme == .dark)
        return VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text(String(format: appSettings.localized("exercises.noResults.title"), searchText))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(appSettings.localized("exercises.noResults.subtitle"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                requestName = searchText
                requestDetails = ""
                showRequestSheet = true
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            } label: {
                Label {
                    Text(appSettings.localized("exercises.request.button"))
                        .font(.callout.weight(.semibold))
                } icon: {
                    Image(systemName: "paperplane.fill")
                        .imageScale(.medium)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule(style: .continuous).fill(.thinMaterial))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: isDark ? .black.opacity(0.22) : .black.opacity(0.08), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appSettings.localized("exercises.request.button"))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(isDark ? 0.06 : 0.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isDark ? Color.white.opacity(0.12) : t.palette.outline, lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func addExercise() {
        let trimmed = newExercise.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            exerciseLibrary.addExercise(trimmed)
            newExercise = ""
            showNewExerciseSheet = false
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            #endif
        }
    }
}

// MARK: - Request-Sheet (UI)

struct ExerciseRequestSheet: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @Binding var name: String
    @Binding var details: String
    var onSend: (_ name: String, _ details: String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(appSettings.localized("exercises.request.form.exercise"))) {
                    TextField(appSettings.localized("exercises.request.form.namePlaceholder"), text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section(header: Text(appSettings.localized("exercises.request.form.detailsHeader"))) {
                    TextEditor(text: $details)
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 1)
                        )
                }
                Section(footer: Text(appSettings.localized("exercises.request.form.footer"))) {
                    EmptyView()
                }
            }
            .navigationTitle(appSettings.localized("exercises.request.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appSettings.localized("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appSettings.localized("common.send")) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSend(trimmed, details.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - CloudKit Service

final class CloudKitExerciseRequestService {
    static let shared = CloudKitExerciseRequestService()
    private init() {}

    private let container = CKContainer(identifier: "iCloud.com.benepkt.Movo")
    private var db: CKDatabase { container.publicCloudDatabase }

    func submit(name: String, details: String, query: String) async throws {
        let status = try await container.accountStatus()
        switch status {
        case .available: break
        case .noAccount: throw NSError(domain: "CloudKit", code: 1,
              userInfo: [NSLocalizedDescriptionKey: "iCloud ist auf diesem Gerät nicht eingerichtet."])
        case .restricted: throw NSError(domain: "CloudKit", code: 2,
              userInfo: [NSLocalizedDescriptionKey: "iCloud ist eingeschränkt (Screen Time/MDM?)."])
        case .couldNotDetermine: fallthrough
        @unknown default: throw NSError(domain: "CloudKit", code: 3,
              userInfo: [NSLocalizedDescriptionKey: "iCloud-Status konnte nicht ermittelt werden."])
        }

        let rec = CKRecord(recordType: "ExerciseRequest")
        rec["name"]    = name as CKRecordValue
        rec["details"] = (details.isEmpty ? "—" : details) as CKRecordValue
        rec["query"]   = (query.isEmpty ? "—" : query) as CKRecordValue
        rec["createdAt"] = Date() as CKRecordValue
        try await db.save(rec)
    }
}
