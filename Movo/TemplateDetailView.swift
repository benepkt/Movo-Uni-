import SwiftUI

struct TemplateDetailView: View {
    let template: TrainingTemplate
    let onStart: () -> Void
    var onEdit: (() -> Void)? = nil
    var onPin: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var isPinned: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                RadialGradient(
                    colors: [t.palette.primary.opacity(0.34), Color.cyan.opacity(0.12), .clear],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 430
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        headerCard
                        summaryRow
                        exerciseList
                        Spacer(minLength: 110)
                    }
                    .padding(.top, 18)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // Pin / Unpin
                        if let onPin {
                            Button(action: onPin) {
                                Label(
                                    isPinned ? appSettings.localized("templates.unpin") : appSettings.localized("templates.pin"),
                                    systemImage: isPinned ? "pin.slash" : "pin"
                                )
                            }
                        }
                        
                        // Share
                        if let onShare {
                            Button(action: onShare) {
                                Label(appSettings.localized("templates.share"), systemImage: "square.and.arrow.up")
                            }
                        }
                        
                        // Edit
                        if let onEdit {
                            Button(action: onEdit) {
                                Label(appSettings.localized("templates.edit"), systemImage: "pencil")
                            }
                        }
                        
                        // Delete
                        if let onDelete {
                            Button(role: .destructive, action: onDelete) {
                                Label(appSettings.localized("templates.delete"), systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.72))
                            .font(.system(size: 24))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.72))
                            .font(.system(size: 24))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
            }

            .safeAreaInset(edge: .bottom) {
                VStack {
                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onStart()
                        }
                    }) {
                        Text(appSettings.localized("start.training"))
                            .font(.title3.bold())
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(t.palette.primary))
                            .shadow(color: t.palette.primary.opacity(0.4), radius: 10, y: 5)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 20)
                .background(
                    LinearGradient(colors: [Color.black.opacity(0), Color.black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 100)
                        .allowsHitTesting(false)
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [t.palette.primary.opacity(0.72), Color.cyan.opacity(0.24), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 52, height: 52)
                            .background(t.palette.primary)
                            .clipShape(Circle())

                        Text(template.name)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }
                    Spacer()
                }
                .padding(22)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            InfoBadge(icon: "list.bullet", title: "\(template.exercises.count) \(appSettings.localized("exercises"))")
            InfoBadge(icon: "clock.fill", title: "~45 min")
        }
        .padding(.horizontal, 16)
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(appSettings.localized("exercises"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 2)

            VStack(spacing: 10) {
                ForEach(Array(template.exercises.enumerated()), id: \.offset) { index, exerciseName in
                    HStack(spacing: 14) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(width: 34, height: 34)
                            .background(t.palette.primary)
                            .clipShape(Circle())

                        Text(exerciseName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.28))
                    }
                    .padding(14)
                    .background(.white.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // Helper View
    struct InfoBadge: View {
        let icon: String
        let title: String
        
        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.72))
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(.white.opacity(0.09)))
            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }
    
    private func gradientColors(for title: String) -> [Color] {
        // Consistent dark theme as requested
         return [Color(hex: "2C2C2E") ?? .gray, Color(hex: "1C1C1E") ?? .black]
    }
}
