import SwiftUI
import Foundation

// MARK: - 🎉 Streak Congrats (Full Screen, Safe-Area-fest)
struct StreakCongratsView: View {
    let unlockedWeeks: Int
    let weekProgress: [Bool]       // 7 Werte ab Wochenbeginn (Locale)
    var onContinue: () -> Void

    @Environment(\.designTokens) private var t
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                let topInset = geo.safeAreaInsets.top
                let bottomInset = geo.safeAreaInsets.bottom

                // Inhalt lässt sich scrollen, falls die Schrift größer ist / kleines iPhone
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 28) {
                        // genug Abstand unter Dynamic Island / Notch
                        Text(appSettings.localized("streak.unlocked.title") ?? "You've unlocked a streak!")
                            .font(.system(size: 32, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.top, max(16, topInset + 8))
                            .minimumScaleFactor(0.7)

                        // Flame/Icon
                        ZStack {
                            Circle().fill(t.palette.primary.opacity(0.18)).frame(width: 138, height: 138)
                            Image(systemName: "flame.fill")
                                .font(.system(size: 56, weight: .bold))
                                .foregroundStyle(t.palette.primary)
                        }
                        .accessibilityHidden(true)

                        // Zahl + Label
                        Text("\(unlockedWeeks)")
                            .font(.system(size: 84, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.6)

                        Text(appSettings.localized("streak.weeks.label") ?? "Week Streak")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)

                        // Woche Mo–So (auto-breite Kacheln)
                        WeekRow(progress: weekProgress, accent: t.palette.primary)
                            .padding(.top, 2)

                        Text(appSettings.localized("streak.hint") ?? "Log workouts to continue your streak!")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.top, 4)

                        // Platz, damit der Content nicht hinter dem CTA steckt
                        Spacer(minLength: 120)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                }
                // Button fest an den unteren Safe-Area-Rand pinnen
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        Button(action: onContinue) {
                            Text(appSettings.localized("common.continue") ?? "Continue")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(t.palette.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                        // Abstand zum Home-Indicator
                        Color.clear.frame(height: max(8, bottomInset))
                    }
                    .background(
                        // leichter „Lift“, damit der Button nicht klebt
                        LinearGradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.4)],
                                       startPoint: .top, endPoint: .bottom)
                            .ignoresSafeArea(edges: .bottom)
                    )
                }
            }
        }
        .onAppear {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        }
    }

    // MARK: - Week Row (auto passt die Kachelgröße)
    private struct WeekRow: View {
        let progress: [Bool] // 7 Einträge
        let accent: Color

        var body: some View {
            GeometryReader { gp in
                let labels = shortWeekdaySymbols()
                let spacing: CGFloat = 10
                let available = gp.size.width - spacing * 6
                let side = max(36, min(56, available / 7)) // min/max begrenzen

                HStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { idx in
                        VStack(spacing: 8) {
                            Text(labels[idx])
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .minimumScaleFactor(0.7)

                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(.white.opacity(0.25), lineWidth: 1)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
                                if progress.indices.contains(idx), progress[idx] {
                                    Image(systemName: "checkmark")
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(accent)
                                }
                            }
                            .frame(width: side, height: side)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 96) // genug Höhe für Label + Kachel
        }

        private func shortWeekdaySymbols() -> [String] {
            var cal = Calendar.current
            cal.locale = .current
            let short = cal.veryShortWeekdaySymbols
            let start = cal.firstWeekday - 1
            return Array(short[start...] + short[..<start])
        }
    }
}
