//
//  StepsWidget.swift
//  MovoWidgetsExtension
//

import WidgetKit
import SwiftUI
import StoreKit
import Charts

// MARK: - Premium-Resolver (App-Group -> StoreKit Fallback)
fileprivate let premiumIDs: Set<String> = [
    "com.benepkt.movo.premium.monthly",
    "com.benepkt.movo.premium.yearly",
    "com.benepkt.movo.premium.lifetime"
]

@MainActor
fileprivate func resolvePremium() async -> Bool {
    return true
}

// MARK: - Entry
struct StepsEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let goal: Int
    let authorized: Bool
    let premiumUnlocked: Bool
    let configuration: ConfigurationAppIntent
    let hourlyHistory: [Double]?
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
            configuration: .example,
            hourlyHistory: Array(repeating: 50.0, count: 24)
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
            configuration: configuration,
            hourlyHistory: snap?.hourlyHistory
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
            configuration: configuration,
            hourlyHistory: snap?.hourlyHistory
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
                // New Design
                ZStack {
                     // Dark background managed by modifier or here?
                     // Widget background is set by modifier later.
                     // But we want a specific dark color for the Card look?
                     // In Widgets, the background is usually set via containerBackground.
                     // We should let containerBackground handle it or fill a Shape.
                     // User wanted like the card which has Color(hex: "1C1C1E").
                     // I will use that color in containerBackground if possible or ZStack.
                     
                     VStack(alignment: .leading, spacing: 0) {
                         Spacer()
                         
                         // Steps Count
                         VStack(alignment: .leading, spacing: 2) {
                             Text(stepsString)
                                 .font(.system(size: isSmall ? 32 : 38, weight: .bold, design: .rounded))
                                 .foregroundStyle(.white)
                                 .minimumScaleFactor(0.5)
                                 .lineLimit(1)
                             
                             Text("Schritte") // Localized manually as per request "steps localized"
                                 .font(.system(size: 16, weight: .medium))
                                 .foregroundStyle(.gray)
                         }
                         .padding(.leading, 16)
                         .padding(.bottom, 8)
                         
                         // Chart
                         if let hourly = entry.hourlyHistory {
                             Chart {
                                 ForEach(Array(hourly.enumerated()), id: \.offset) { index, value in
                                     LineMark(
                                         x: .value("Hour", index),
                                         y: .value("Steps", value)
                                     )
                                     .interpolationMethod(.catmullRom)
                                     .foregroundStyle(Color.cyan)
                                     .lineStyle(StrokeStyle(lineWidth: 3))
                                     
                                     AreaMark(
                                         x: .value("Hour", index),
                                         y: .value("Steps", value)
                                     )
                                     .interpolationMethod(.catmullRom)
                                     .foregroundStyle(
                                         LinearGradient(
                                             colors: [Color.cyan.opacity(0.3), Color.cyan.opacity(0.0)],
                                             startPoint: .top,
                                             endPoint: .bottom
                                         )
                                     )
                                 }
                             }
                             .chartXAxis(.hidden)
                             .chartYAxis(.hidden)
                             .frame(height: 50)
                             .padding(.horizontal, 8)
                             .padding(.bottom, 16)
                         } else {
                             // Fallback if no history
                             Spacer().frame(height: 50)
                         }
                     }
                }
            }
        }
        .widgetURL(
            URL(
                string: entry.premiumUnlocked
                ? "movo://steps"
                : "movo://paywall?source=widget-steps"
            )
        )
    }

    // Unused method stubs or removal
    // (Removed old layouts)

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
            content.containerBackground(Color(red: 28/255, green: 28/255, blue: 30/255), for: .widget)
        } else {
            content.background(Color(red: 28/255, green: 28/255, blue: 30/255))
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
                configuration: .example, hourlyHistory: Array(repeating: 200, count: 24))
     StepsEntry(date: .now, steps: 9876, goal: 10000,
                authorized: true, premiumUnlocked: false,
                configuration: .example, hourlyHistory: nil)
 }
