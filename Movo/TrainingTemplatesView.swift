import SwiftUI

struct TrainingTemplatesView: View {
    @EnvironmentObject var sessionManager: TrainingSessionManager
    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    @EnvironmentObject var templateStore: TemplateStore
    @EnvironmentObject var appSettings: AppSettings

    @EnvironmentObject var syncService: SyncService
    @Binding var showNewTraining: Bool

    @Environment(\.designTokens) private var t

    @State private var showingAddTemplate = false
    @State private var editingTemplate: TrainingTemplate? = nil
    @State private var templateToShare: TrainingTemplate?
    @State private var previewTemplate: TrainingTemplate? // New: For preview sheet
    @State private var showAllMovoTemplates = false       // New: For "Show More" logic

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private func L(_ de: String, _ en: String) -> String { isDE ? de : en }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            RadialGradient(
                colors: [
                    t.palette.primary.opacity(0.36),
                    Color.cyan.opacity(0.12),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 30,
                endRadius: 430
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    
                    // 1. My Routines (Eigene Templates)
                    if !templateStore.userTemplates.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(appSettings.localized("templates.section.custom"))
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal)
                            
                            // Combine user and default templates for the list
                            VStack(spacing: 16) {
                                ForEach(templateStore.userTemplates) { template in
                                    RoutineCard(
                                        template: template,
                                        editable: true,
                                        onStart: { previewTemplate = template },
                                        onEdit: { editingTemplate = template },
                                        onShare: { templateToShare = template },
                                        onDelete: {
                                            templateStore.delete(template)
                                            Task { await syncService.uiDeleteTemplate(id: template.id) }
                                        },
                                        onPin: { templateStore.togglePin(for: template) },
                                        isPinned: templateStore.isPinned(template)
                                    )
                                    .onTapGesture { previewTemplate = template }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // 2. Movo Routines (Default Templates)
                    if !templateStore.defaultTemplates.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(appSettings.localized("templates.section.default"))
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal)
                            
                            let displayedTemplates = showAllMovoTemplates 
                                ? templateStore.defaultTemplates 
                                : Array(templateStore.defaultTemplates.prefix(4))
                            
                            VStack(spacing: 16) {
                                ForEach(displayedTemplates) { template in
                                    RoutineCard(
                                        template: template,
                                        editable: true,
                                        onStart: { previewTemplate = template },
                                        onEdit: { editingTemplate = template },
                                        onShare: { templateToShare = template },
                                        onDelete: nil,
                                        onPin: { templateStore.togglePin(for: template) },
                                        isPinned: templateStore.isPinned(template)
                                    )
                                    .onTapGesture { previewTemplate = template }
                                }
                                
                                // Show More Button
                                if templateStore.defaultTemplates.count > 4 {
                                    Button(action: { withAnimation { showAllMovoTemplates.toggle() } }) {
                                        HStack {
                                            Text(showAllMovoTemplates ? L("Weniger anzeigen", "Show less") : L("Mehr anzeigen", "Show more"))
                                                .font(.subheadline.bold())
                                            Image(systemName: showAllMovoTemplates ? "chevron.up" : "chevron.down")
                                                .font(.caption.bold())
                                        }
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(t.palette.primary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 20)
                .padding(.bottom, 80) // Space for floating button
            }
        }
        .navigationTitle(appSettings.localized("templates.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        
        // Floating Add Button
        .overlay(alignment: .bottomTrailing) {
            Button {
                attemptCreateTemplate()
            } label: {
                ZStack {
                    Circle().fill(t.palette.primary)
                        .frame(width: 56, height: 56)
                        .shadow(color: t.palette.primary.opacity(0.26), radius: 16, x: 0, y: 10)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                }
                .padding()
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }

        // Sheets
        .sheet(isPresented: $showingAddTemplate) {
            AddTemplateView { newTemplate in
                templateStore.add(newTemplate)
            }
            .environmentObject(exerciseLibrary)
        }
        .sheet(item: $editingTemplate) { template in
            AddTemplateView(existingTemplate: template) { updatedTemplate in
                templateStore.update(updatedTemplate)
            }
            .environmentObject(exerciseLibrary)
        }
        .sheet(item: $templateToShare) { template in
            TemplateQRCodeView(template: template)
                .environmentObject(appSettings)
        }
        .sheet(item: $previewTemplate) { template in
            TemplateDetailView(
                template: template,
                onStart: {
                    startTemplate(template)
                    previewTemplate = nil
                },
                onEdit: {
                    previewTemplate = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        editingTemplate = template
                    }
                },
                onPin: {
                    templateStore.togglePin(for: template)
                },
                onShare: {
                    previewTemplate = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        templateToShare = template
                    }
                },
                onDelete: templateStore.isDefault(template) ? nil : {
                    previewTemplate = nil
                    templateStore.delete(template)
                    Task { await syncService.uiDeleteTemplate(id: template.id) }
                },
                isPinned: templateStore.isPinned(template)
            )
        }
    }

    // MARK: - Actions
    private func startTemplate(_ template: TrainingTemplate) {
        sessionManager.startTraining(title: template.name, source: "from_template", templateId: template.id)
        for name in template.exercises { sessionManager.addExercise(name) }
        sessionManager.activities = template.activities
        sessionManager.persistSnapshotIfNeeded()
        AnalyticsService.trackWorkoutStarted(source: "from_template", template: template)
        showNewTraining = true
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(.white.opacity(0.12)).frame(width: 56, height: 56)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(appSettings.localized("templates.empty.title"))
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(appSettings.localized("templates.empty.subtitle"))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
        .padding()
        .background(.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Helpers
    private func attemptCreateTemplate() {
        showingAddTemplate = true
    }
}

// MARK: - Subviews

struct RoutineCard: View {
    let template: TrainingTemplate
    let editable: Bool
    
    // Actions are now handled by parent via Tap -> Preview
    // We only need basic data here to render functionality if needed,
    // but actually the card itself is just visual now.
    
    // ... though existing code passes these closures.
    // We can keep the signature to avoid breaking call sites,
    // but ignore them in the body since interaction is via Preview.
    let onStart: () -> Void
    var onEdit: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onPin: (() -> Void)? = nil
    var isPinned: Bool = false
    var isLocked: Bool = false  // Premium lock indicator
    
    @Environment(\.designTokens) private var t
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [t.palette.primary.opacity(0.75), Color.cyan.opacity(0.30)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: isLocked ? "lock.fill" : "dumbbell.fill")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.black)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Text(template.name)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    if isPinned {
                        Text(appSettings.language.lowercased().hasPrefix("de") ? "Home" : "Home")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(t.palette.primary)
                            .clipShape(Capsule())
                    }
                }

                Text(template.exercises.prefix(3).joined(separator: " · "))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label("\(template.exercises.count)", systemImage: "list.bullet")
                    Label("~45 min", systemImage: "clock")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.42))
            }

            Spacer(minLength: 0)

            Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isLocked ? t.palette.primary : .white.opacity(0.36))
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.08))
                .clipShape(Circle())
        }
        .padding(14)
        .background(.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.13), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
        .opacity(isLocked ? 0.6 : 1.0)  // Dim locked cards
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        EmptyView() // No longer used in this layout
    }
    
    func gradientColors(for title: String) -> [Color] { [.black, .black] }
}

#Preview {
    NavigationView {
        TrainingTemplatesView(showNewTraining: .constant(false))
            .environmentObject(TrainingSessionManager())
            .environmentObject(ExerciseLibrary())
            .environmentObject(TemplateStore(training: TrainingStore()))
            .environmentObject(AppSettings())
            .environmentObject(DesignSettingsStore())
            .environmentObject(ChallengeStore())
    }
}
