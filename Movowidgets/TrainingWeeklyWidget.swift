//  TrainingWeeklyWidget.swift
//  Zeigt NUR die aktuelle Woche: Anzahl Trainings + Progress-Ring
//  Premium-Lock via StepsShared.premiumUnlocked

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Konfiguration (Ziel im Widget einstellbar)

struct TrainingWeekConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Trainings-Widget"
    static var description = IntentDescription("Trainingsziel pro Woche.")

    @Parameter(title: "Ziel pro Woche", default: 3)
    var goalPerWeek: Int
}

// MARK: - Entry

struct TrainingWeekEntry: TimelineEntry {
    let date: Date
    let weekStart: Date
    let count: Int
    let goalPerWeek: Int
    let premiumUnlocked: Bool
}

// MARK: - Provider (AppIntent)

struct TrainingWeekProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TrainingWeekEntry {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: Date())!.start
        return TrainingWeekEntry(
            date: Date(),
            weekStart: start,
            count: 2,
            goalPerWeek: 3,
            premiumUnlocked: true
        )
    }

    func snapshot(for configuration: TrainingWeekConfiguration,
                  in context: Context) async -> TrainingWeekEntry {
        makeEntry(goalOverride: configuration.goalPerWeek)
    }

    func timeline(for configuration: TrainingWeekConfiguration,
                  in context: Context) async -> Timeline<TrainingWeekEntry> {
        let entry = makeEntry(goalOverride: configuration.goalPerWeek)
        return Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(60 * 20))
        )
    }

    // reale Daten aus App-Group + optionales Ziel aus Konfiguration
    private func makeEntry(goalOverride: Int? = nil) -> TrainingWeekEntry {
        let cal = Calendar.current
        let now = Date()
        let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? cal.startOfDay(for: now)

        let snap = TrainingWeeklyShared.load()
        let last = snap?.lastWeeks.last

        // Premium-Flag aus StepsShared (eine zentrale Quelle)
        let premium = StepsShared.load()?.premiumUnlocked ?? false

        let goal = goalOverride ?? snap?.goalPerWeek ?? 3

        return TrainingWeekEntry(
            date: Date(),
            weekStart: last?.start ?? start,
            count: last?.count ?? 0,
            goalPerWeek: goal,
            premiumUnlocked: premium
        )
    }
}

// MARK: - View

struct TrainingWeekWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TrainingWeekEntry

    private var progress: Double {
        guard entry.goalPerWeek > 0 else { return 0 }
        return min(1, Double(entry.count) / Double(entry.goalPerWeek))
    }

    private var kwString: String {
        let cal = Calendar.current
        let kw = cal.component(.weekOfYear, from: entry.weekStart)
        return "KW \(kw)"
    }

    private var isSmall: Bool { family == .systemSmall }
    private var numberSize: CGFloat { isSmall ? 22 : 34 }
    private var ringSize: CGFloat   { isSmall ? 52 : 86 }

    var body: some View {
        Group {
            if !entry.premiumUnlocked {
                lockedContent
            } else {
                if isSmall {
                    smallLayout
                } else {
                    mediumLayout
                }
            }
        }
        .padding(isSmall ? 10 : 16)
        .widgetURL(
            URL(
                string: entry.premiumUnlocked
                ? "movo://statistics"
                : "movo://paywall?source=widget-training-week"
            )
        )
        .widgetBackground()
    }

    // MARK: - SMALL

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Kopfzeile: Icon + "Trainings – Woche" + "2 von 3"
            HStack(spacing: 8) {
                iconBadge(size: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Trainings – Woche")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("\(entry.count) von \(entry.goalPerWeek)")
                        .font(.system(size: 14,
                                      weight: .semibold,
                                      design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 4)
            }

            // Ring + Meta rechts
            HStack(spacing: 10) {
                ZStack {
                    ProgressRing(
                        progress: progress,
                        color: .accentColor,
                        lineWidth: 8
                    )
                    Text("\(entry.count)")
                        .font(.system(size: numberSize,
                                      weight: .semibold,
                                      design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: ringSize, height: ringSize)

                VStack(alignment: .leading, spacing: 3) {
                    Text(kwString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("\(entry.goalPerWeek)/Wo.")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - MEDIUM

    private var mediumLayout: some View {
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(
                    progress: progress,
                    color: .accentColor,
                    lineWidth: 12
                )
                .frame(width: ringSize, height: ringSize)

                Text("\(entry.count)")
                    .font(.system(size: numberSize,
                                  weight: .semibold,
                                  design: .rounded))
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    iconBadge(size: 22)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Trainings – diese Woche")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text("\(entry.count) von \(entry.goalPerWeek)")
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Spacer(minLength: 4)
                    goalChip
                }

                ProgressView(value: progress)
                    .progressViewStyle(.linear)

                HStack {
                    Text(kwString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Ziel \(entry.goalPerWeek)/Wo.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Icon + Goal-Chip

    private func iconBadge(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size / 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.6),
                            Color.accentColor.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "calendar")
                .font(.system(size: size * 0.55, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size + 2, height: size + 2)
    }

    private var goalChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "target")
            Text("\(entry.goalPerWeek)/Wo.")
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.06))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.22), lineWidth: 0.7)
                )
        )
        .foregroundStyle(.secondary)
    }

    // MARK: - Lock-Ansicht

    private var lockedContent: some View {
        Group {
            switch family {
            case .systemSmall:
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .imageScale(.medium)
                            .foregroundStyle(.secondary)
                        Text("Premium")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
}

// MARK: - Widget Definition

struct TrainingWeeklyWidget: Widget {
    let kind = "TrainingWeeklyWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TrainingWeekConfiguration.self,
            provider: TrainingWeekProvider()
        ) { entry in
            TrainingWeekWidgetView(entry: entry)
        }
        .configurationDisplayName("Trainings – diese Woche")
        .description("Aktuelle Woche mit Fortschritt zum Wochenziel.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Ring

private struct ProgressRing: View {
    var progress: Double   // 0...1
    var color: Color
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.20), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
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
