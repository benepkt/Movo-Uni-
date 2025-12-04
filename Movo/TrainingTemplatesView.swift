import SwiftUI

struct TrainingTemplatesView: View {
    @EnvironmentObject var sessionManager: TrainingSessionManager
    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    @EnvironmentObject var templateStore: TemplateStore
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var syncService: SyncService

    @Binding var showNewTraining: Bool

    @Environment(\.designTokens) private var t

    @State private var showingAddTemplate = false
    @State private var editingTemplate: TrainingTemplate? = nil

    // Paywall/Limit
    @State private var showLimitAlert = false
    @State private var showPaywall = false

    private let freeTemplateLimit = 3
    private var isPremium: Bool { purchaseManager.hasUnlockedStatistics }
    private var userTemplateCount: Int { templateStore.userTemplates.count }
    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private func L(_ de: String, _ en: String) -> String { isDE ? de : en }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea(edges: .bottom)

            if templateStore.allTemplates.isEmpty {
                emptyState
                    .padding(.horizontal)
            } else {
                templatesList
            }
        }
        .navigationTitle(appSettings.localized("templates.title"))
        .navigationBarTitleDisplayMode(.large)

        // Neue Vorlage
        .sheet(isPresented: $showingAddTemplate) {
            AddTemplateView { newTemplate in
                if isPremium || userTemplateCount < freeTemplateLimit {
                    templateStore.add(newTemplate)
                } else {
                    showLimitAlert = true
                }
            }
            .environmentObject(exerciseLibrary)
        }

        // Vorlage bearbeiten
        .sheet(item: $editingTemplate) { template in
            AddTemplateView(existingTemplate: template) { updatedTemplate in
                templateStore.update(updatedTemplate)
            }
            .environmentObject(exerciseLibrary)
        }

        // Limit-Alert
        .alert(L("Limit erreicht", "Limit reached"), isPresented: $showLimitAlert) {
            Button(L("Später", "Not now"), role: .cancel) { }
            Button(L("Upgrade", "Upgrade")) { showPaywall = true }
        } message: {
            Text(L(
                "In der kostenlosen Version kannst du bis zu 3 eigene Vorlagen erstellen. Für unbegrenzt viele Vorlagen wechsle bitte auf Premium.",
                "In the free version you can create up to 3 custom templates. Upgrade to Premium for unlimited templates."
            ))
        }

        // Paywall
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(appSettings)
                .environmentObject(purchaseManager)
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(.white.opacity(0.18)).frame(width: 56, height: 56)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(appSettings.localized("templates.empty.title"))
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(appSettings.localized("templates.empty.subtitle"))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            Button {
                attemptCreateTemplate()
            } label: {
                Label(appSettings.localized("templates.empty.button"), systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white.opacity(0.22)))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .appHeroCard()
    }

    // MARK: - Templates-Liste
    private var templatesList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                if !templateStore.defaultTemplates.isEmpty {
                    section(title: appSettings.localized("templates.section.default")) {
                        VStack(spacing: 12) {
                            ForEach(templateStore.defaultTemplates) { template in
                                templateCard(for: template, editable: false)
                            }
                        }
                    }
                }

                if !templateStore.userTemplates.isEmpty {
                    section(title: appSettings.localized("templates.section.custom")) {
                        VStack(spacing: 12) {
                            ForEach(templateStore.userTemplates) { template in
                                templateCard(for: template, editable: true)
                                    .contextMenu {
                                        Button {
                                            editingTemplate = template
                                        } label: {
                                            Label(appSettings.localized("templates.edit"), systemImage: "pencil")
                                        }

                                        Button(role: .destructive) {
                                            // 1) Lokal aus dem TemplateStore entfernen (UI reagiert sofort)
                                            templateStore.delete(template)

                                            // 2) Remote in Firestore löschen (falls Account vorhanden)
                                            Task {
                                                await syncService.uiDeleteTemplate(id: template.id)
                                            }
                                        } label: {
                                            Label(appSettings.localized("templates.delete"), systemImage: "trash")
                                        }
                                    }

                            }
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
        // Floating Add Button
        .overlay(alignment: .bottomTrailing) {
            Button {
                attemptCreateTemplate()
            } label: {
                ZStack {
                    Circle().fill(t.palette.primary)
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 6)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding()
            }
            .buttonStyle(.plain)
            .accessibilityHint(
                isPremium || userTemplateCount < freeTemplateLimit
                ? L("Neue Vorlage erstellen", "Create new template")
                : L("Limit erreicht – Upgrade erforderlich", "Limit reached – upgrade required")
            )
        }
    }

    // MARK: - Helpers
    private func attemptCreateTemplate() {
        if isPremium || userTemplateCount < freeTemplateLimit {
            showingAddTemplate = true
        } else {
            showLimitAlert = true
        }
    }

    // MARK: - Section Wrapper
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .padding(.horizontal)
            content()
                .padding(.horizontal)
        }
    }

    // MARK: - Template Card
    private func templateCard(for template: TrainingTemplate, editable: Bool) -> some View {
        Button {
            sessionManager.startTraining(title: template.name)
            for name in template.exercises { sessionManager.addExercise(name) }
            showNewTraining = true
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(t.palette.primary.opacity(0.14))
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(t.palette.primary)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 6) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundStyle(t.palette.primary)

                    Text(String(format: appSettings.localized("templates.exercisesCount"),
                                template.exercises.count))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if editable {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .appElevatedCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.name)
    }
}

#Preview {
    let training = TrainingStore()
    let templates = TemplateStore(training: training)

    return NavigationStack {
        TrainingTemplatesView(showNewTraining: .constant(false))
    }
    .environmentObject(TrainingSessionManager())
    .environmentObject(ExerciseLibrary())
    .environmentObject(training)      // derselbe TrainingStore wie im TemplateStore
    .environmentObject(templates)     // genau 1x TemplateStore
    .environmentObject(AppSettings())
    .environmentObject(DesignSettingsStore())
}
