import WidgetKit
import SwiftUI

// MARK: - Entry
struct StepsWeeklyEntry: TimelineEntry {
    let date: Date
    let goal: Int
    let days: [StepsDayCompact]    // älteste -> neueste
    let premiumUnlocked: Bool
}

// MARK: - Provider
struct StepsWeeklyProvider: TimelineProvider {
    func placeholder(in context: Context) -> StepsWeeklyEntry { dummy }

    func getSnapshot(in context: Context, completion: @escaping (StepsWeeklyEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepsWeeklyEntry>) -> Void) {
        completion(
            Timeline(
                entries: [makeEntry()],
                policy: .after(Date().addingTimeInterval(60 * 15))
            )
        )
    }

    // Dummy-Daten für Gallery
    private var dummy: StepsWeeklyEntry {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        let vals = [4200, 7600, 10300, 8700, 12000, 9800, 6500]
        let days = (0..<7).map { i in
            StepsDayCompact(
                d: cal.date(byAdding: .day, value: -(6 - i), to: base)!,
                s: vals[i]
            )
        }
        return StepsWeeklyEntry(
            date: Date(),
            goal: 10000,
            days: days,
            premiumUnlocked: true
        )
    }

    // Reale Daten aus App-Group
    private func makeEntry() -> StepsWeeklyEntry {
        let snap = StepsShared.load()
        let last7 = Array((snap?.lastDays ?? []).suffix(7)) // älteste -> neueste
        let premium = snap?.premiumUnlocked ?? false
        return StepsWeeklyEntry(
            date: Date(),
            goal: snap?.goal ?? 10000,
            days: last7,
            premiumUnlocked: premium
        )
    }
}

// MARK: - View (compact + overflow-safe)
struct StepsWeeklyView: View {
    let entry: StepsWeeklyEntry
    @Environment(\.widgetFamily) private var family

    // abgeleitete Werte
    private var maxSteps: Double {
        let maxDay = Double(entry.days.map { $0.s }.max() ?? 0)
        return max(Double(entry.goal), maxDay, 1)
    }
    private var total: Int { entry.days.reduce(0) { $0 + $1.s } }
    private var avg: Int { entry.days.isEmpty ? 0 : total / entry.days.count }

    private var weekdayShort: [String] {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEEEE") // 1-Buchstaben-Tag
        return entry.days.map { f.string(from: $0.d).uppercased() }
    }

    // Layout-Tuning pro Family
    private var numberFontSize: CGFloat { family == .systemSmall ? 24 : 30 }
    private var chartHeight: CGFloat  { family == .systemSmall ? 48 : 68 } // nur für medium genutzt
    private var outerPadding: CGFloat { family == .systemSmall ? 8  : 10 }
    private var vSpacing: CGFloat     { family == .systemSmall ? 6  : 8  }

    var body: some View {
        Group {
            if !entry.premiumUnlocked {
                lockedContent
            } else {
                switch family {
                case .systemSmall:
                    smallLayout
                default: // .systemMedium
                    mediumLayout
                }
            }
        }
        .padding(outerPadding)
        .widgetURL(
            URL(
                string: entry.premiumUnlocked
                ? "movo://steps"
                : "movo://paywall?source=widget-steps-weekly"
            )
        )
        .widgetBackground()
    }

    // MARK: - SMALL LAYOUT
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                iconBadge(size: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Schritte – 7 Tage")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(format(total))
                        .font(.system(size: 20,
                                      weight: .semibold,
                                      design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Spacer(minLength: 4)
            }

            chartWithLabels
                .frame(height: 36) // mehr Platz als vorher, aber kompakt

            HStack(spacing: 6) {
                Text("Σ \(format(total))")
                Text("·")
                Text("Ø \(format(avg))")
                Spacer(minLength: 4)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    // MARK: - MEDIUM LAYOUT (wie vorher, nur in eigene View ausgelagert)
    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: vSpacing) {
            header      // nutzt iconBadge + goalChip
            chartWithLabels
                .frame(height: chartHeight)
            footer
            Spacer(minLength: 0)
        }
    }

    // MARK: Header für Medium
    private var header: some View {
        HStack(spacing: 10) {
            iconBadge(size: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("Schritte – 7 Tage")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(format(total)) // große Summe
                    .font(.system(size: numberFontSize,
                                  weight: .bold,
                                  design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.accentColor,
                                Color.accentColor.opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Spacer(minLength: 6)

            goalChip
        }
    }

    // Icon-Badge für beide Layouts
    private func iconBadge(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.55),
                            Color.accentColor.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "figure.walk.motion")
                .font(.system(size: size * 0.55, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }

    private var goalChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.checkered")
            Text(format(entry.goal))
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.06))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.7)
                )
        )
        .foregroundStyle(.secondary)
    }

    // MARK: Chart + X-Achse
    private var chartWithLabels: some View {
        VStack(spacing: 6) {
            chart
            HStack {
                ForEach(weekdayShort.indices, id: \.self) { i in
                    Text(weekdayShort[i])
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }

    // Chart selbst – unverändert „glatt“ (für beide Layouts)
    private var chart: some View {
        GeometryReader { geo in
            let size = geo.size
            let w = size.width
            let h = size.height
            let count = max(entry.days.count, 1)
            let spacing: CGFloat = family == .systemSmall ? 4 : 6
            let barW = max((w - CGFloat(count - 1) * spacing) / CGFloat(count), 4)

            ZStack(alignment: .bottomLeading) {
                // Ziel-Linie (dezent gestrichelt)
                let goalRatio = CGFloat(entry.goal) / CGFloat(maxSteps)
                let y = max(0, min(h, h - goalRatio * h))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: w, y: y))
                }
                .stroke(
                    Color.secondary.opacity(0.35),
                    style: StrokeStyle(
                        lineWidth: 1,
                        lineCap: .round,
                        dash: [3, 3]
                    )
                )

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(entry.days.enumerated()), id: \.offset) { _, day in
                        let v = Double(day.s)
                        let ratio = v / maxSteps
                        let barH = max(3, CGFloat(ratio) * (h - 6))
                        let hitGoal = v >= Double(entry.goal)

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(hitGoal ? 0.95 : 0.75),
                                        Color.accentColor.opacity(hitGoal ? 0.75 : 0.45)
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: barW, height: barH)
                    }
                }
            }
        }
    }

    // MARK: Footer / Meta für Medium
    private var footer: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "sum")
                Text(format(total))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Text("•")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Ø \(format(avg))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 6)

            Text("7 Tage")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                )
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Lock-Ansicht (wie gehabt)
    private var lockedContent: some View {
        Group {
            switch family {
            case .systemSmall:
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .imageScale(.medium)
                            .foregroundStyle(.secondary)
                        Text("Premium").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }
                    Text("Widgets freischalten")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Tippe, um Premium zu aktivieren")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            default:
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Premium erforderlich")
                            .font(.headline)
                        Text("Tippe, um die Paywall zu öffnen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: Helper
    private func format(_ n: Int) -> String {
        NumberFormatter.localizedString(from: n as NSNumber, number: .decimal)
    }
}

// MARK: - Glass Card Wrapper
struct GlassWidgetCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.55),
                                    Color.white.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.25),
                        radius: 12,
                        x: 0,
                        y: 8)

            content
                .padding(14)
        }
    }
}

// MARK: - Widget Definition
struct StepsWeeklyWidget: Widget {
    let kind = "StepsWeeklyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StepsWeeklyProvider()) { entry in
            StepsWeeklyView(entry: entry)
                .widgetBackground() // iOS17 system background; iOS16 no-op
        }
        .configurationDisplayName("Schritte – 7 Tage")
        .description("Summe, Ø und Ziel mit Mini-Barchart.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Background Helper (iOS16/17-safe)
private extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOS 17, *) {
            self.containerBackground(.fill.tertiary, for: .widget)
        } else {
            self
        }
    }
}
