//
//  StepsWidget.swift
//  MovoWidgetsExtension
//

import WidgetKit
import SwiftUI
import StoreKit

// MARK: - Premium-Resolver (App-Group -> StoreKit Fallback)
fileprivate let premiumIDs: Set<String> = [
    "com.benepkt.movo.premium.monthly",
    "com.benepkt.movo.premium.yearly",
    "com.benepkt.movo.premium.lifetime"
]

@MainActor
fileprivate func resolvePremium() async -> Bool {
    if StepsShared.isPremiumUnlocked() { return true }
    do {
        for await r in StoreKit.Transaction.currentEntitlements {
            if case .verified(let t) = r, premiumIDs.contains(t.productID) {
                return true
            }
        }
    } catch { /* ignore */ }
    return false
}

// MARK: - Entry
struct StepsEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let goal: Int
    let authorized: Bool
    let premiumUnlocked: Bool
    let configuration: ConfigurationAppIntent
}

// MARK: - Provider (AppIntent)
struct StepsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StepsEntry {
        StepsEntry(
            date: .now,
            steps: 7421,
            goal: 8000,
            authorized: true,
            premiumUnlocked: true,
            configuration: .example
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent,
                  in context: Context) async -> StepsEntry {
        let snap = StepsShared.load()
        let premium = await resolvePremium()
        return StepsEntry(
            date: .now,
            steps: snap?.stepsToday ?? 0,
            goal: snap?.goal ?? 8000,
            authorized: snap != nil,
            premiumUnlocked: premium,
            configuration: configuration
        )
    }

    func timeline(for configuration: ConfigurationAppIntent,
                  in context: Context) async -> Timeline<StepsEntry> {
        let snap = StepsShared.load()
        let premium = await resolvePremium()
        let entry = StepsEntry(
            date: .now,
            steps: snap?.stepsToday ?? 0,
            goal: snap?.goal ?? 8000,
            authorized: snap != nil,
            premiumUnlocked: premium,
            configuration: configuration
        )
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        return Timeline(entries: [entry], policy: .after(next))
    }
}

// MARK: - View
struct StepsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: StepsEntry

    private var stepsString: String {
        NumberFormatter.localizedString(from: entry.steps as NSNumber, number: .decimal)
    }
    private var goalString: String {
        NumberFormatter.localizedString(from: entry.goal as NSNumber, number: .decimal)
    }
    private var progress: Double {
        guard entry.goal > 0 else { return 0 }
        return min(1, Double(entry.steps) / Double(entry.goal))
    }

    private var isSmall: Bool { family == .systemSmall }

    var body: some View {
        Group {
            if !entry.premiumUnlocked {
                lockedContent
            } else if !entry.authorized {
                unauthorizedContent
            } else {
                if isSmall {
                    smallLayout
                } else {
                    mediumLayout
                }
            }
        }
        .tint(.accentColor)
        .widgetURL(
            URL(
                string: entry.premiumUnlocked
                ? "movo://steps"
                : "movo://paywall?source=widget-steps"
            )
        )
    }


    // MARK: - SMALL

    private var smallLayout: some View {
        VStack(spacing: 8) {
            // kleine Kopfzeile nur mit Icon
            HStack {
                iconBadge(size: 20)
                Spacer()
            }

            // kompakter Ring
            StepsRing(progress: progress, lineWidth: 10)
                .frame(width: 70, height: 70)

            // Schritte-Zahl
            Text(stepsString)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // Ziel-Pill zentriert unten
            goalChip
                .frame(maxWidth: .infinity)
        }
        .padding(12)
    }


    // MARK: - MEDIUM

    private var mediumLayout: some View {
        HStack(spacing: 18) {
            // Fortschrittsring links – OHNE Zahl
            StepsRing(progress: progress, lineWidth: 16)
                .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 10) {
                // Ziel-Chip über der Schrittzahl
                goalChip

                // Icon + Steps
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    iconBadge(size: 26)

                    Text(stepsString)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Spacer(minLength: 0)
                }

                Text("heute")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
    }

    // MARK: - Icon + Goal-Chip

    private func iconBadge(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.7),
                            Color.accentColor.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "figure.walk")
                .font(.system(size: size * 0.55, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }

    private var goalChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.checkered")
            Text(goalString)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.06))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.20), lineWidth: 0.7)
                )
        )
        .foregroundStyle(.secondary)
    }

    // MARK: - States

    private var unauthorizedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
                Text("Schritte")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text("In der App erlauben")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(isSmall ? 14 : 16)
    }

    // MARK: - Lock-Ansicht (wenn kein Premium)
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
                .padding(14)

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
                .padding(16)
            }
        }
    }
}

// MARK: - Fortschrittsring (ohne Text im Inneren)
private struct StepsRing: View {
    var progress: Double   // 0...1
    var lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.accentColor,
                            Color.accentColor.opacity(0.6)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

           
            }
        }
    }


// MARK: - Widget Definition

struct StepsWidget: Widget {
    let kind: String = "StepsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: StepsProvider()
        ) { entry in
            StepsWidgetView(entry: entry)
                .modifier(ContainerBG()) // iOS 17 system background
        }
        .configurationDisplayName("Heutige Schritte")
        .description("Zeigt deine Schritte und dein Tagesziel.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// iOS-17 Background nur hier (nicht in der View); iOS-16: nichts tun
fileprivate struct ContainerBG: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.containerBackground(.fill.tertiary, for: .widget)
        } else {
            content
        }
    }
}

// MARK: - AppIntent Preview Helpers
extension ConfigurationAppIntent {
    static var example: ConfigurationAppIntent {
        let i = ConfigurationAppIntent()
        return i
    }
}

#Preview(as: .systemSmall) {
    StepsWidget()
} timeline: {
    StepsEntry(date: .now, steps: 5234, goal: 8000,
               authorized: true, premiumUnlocked: true,
               configuration: .example)
    StepsEntry(date: .now, steps: 9876, goal: 10000,
               authorized: true, premiumUnlocked: false,
               configuration: .example)
}
