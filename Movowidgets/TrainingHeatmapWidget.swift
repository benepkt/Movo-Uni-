// TrainingHeatmapWidget.swift
// Widgets-Extension: Aktivitäts-Heatmap aus echten App-Group-Daten, zeigt die letzten Wochen (über Jahresgrenzen hinweg)

import WidgetKit
import SwiftUI

struct HeatmapEntry: TimelineEntry {
    let date: Date
    let days: [HeatmapDayCompact]   // oldest -> newest, continuous (z. B. 52 Wochen)
    let premiumUnlocked: Bool
}

struct HeatmapProvider: TimelineProvider {
    func placeholder(in context: Context) -> HeatmapEntry {
        let snap = HeatmapShared.load()
        let premium = true
        let base = snap?.days ?? []
        return HeatmapEntry(date: Date(), days: base, premiumUnlocked: premium)
    }

    func getSnapshot(in context: Context, completion: @escaping (HeatmapEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HeatmapEntry>) -> Void) {
        let entry = makeEntry()
        let next = Date().addingTimeInterval(60 * 5) // alle 5 Minuten
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> HeatmapEntry {
        let snap = HeatmapShared.load()
        let premium = true
        let base = snap?.days ?? []
        return HeatmapEntry(date: Date(), days: base, premiumUnlocked: premium)
    }
}

struct TrainingHeatmapWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HeatmapEntry

    private var isSmall: Bool { family == .systemSmall }
    private var spacing: CGFloat { 2 }
    // Begrenze die Spaltenanzahl (Performance/Lesbarkeit)
    private var maxColumnsCap: Int { isSmall ? 16 : 28 }

    // Wenn true: aktuelle Woche links, ältere nach rechts
    private let leftMostIsRecent = true

    var body: some View {
        Group {
            if !entry.premiumUnlocked {
                locked
            } else {
                heatmap
            }
        }
        .padding(isSmall ? 8 : 10)
        .widgetURL(
            URL(
                string: entry.premiumUnlocked
                ? "movo://statistics"
                : "movo://paywall?source=widget-heatmap"
            )
        )
        .widgetBackground()
    }

    private var heatmap: some View {
        // Header + separater GeometryReader nur für das Grid
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
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
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: isSmall ? 10 : 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: isSmall ? 20 : 22, height: isSmall ? 20 : 22)

                Text("Aktivität")
                    .font(isSmall ? .caption2.weight(.medium) : .caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            GeometryReader { geo in
                let size = geo.size

                // 1) Spalten aus Tagen bilden, VORHER an lokalen Wochenanfang ausrichten
                let allColumns = makeColumnsWeekAligned(from: entry.days)
                // nur die letzten Wochen anzeigen
                let lastColumns = Array(allColumns.suffix(maxColumnsCap))
                // 1a) Reihenfolge festlegen: neueste links (optional)
                let columns = leftMostIsRecent ? Array(lastColumns.reversed()) : lastColumns

                // 2) Dynamische Zellgröße berechnen basierend NUR auf dem Grid-Bereich
                let cols = max(columns.count, 1)
                let rows = 7
                let availableW = max(0, size.width  - CGFloat(cols - 1) * spacing)
                let availableH = max(0, size.height - CGFloat(rows - 1) * spacing)
                let cell = floor(min(availableW / CGFloat(cols), availableH / CGFloat(rows)))

                // Grid
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<columns.count, id: \.self) { idx in
                        let week = columns[idx]
                        VStack(spacing: spacing) {
                            ForEach(0..<7, id: \.self) { r in
                                let c = week[r].c
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(color(for: c))
                                    .frame(width: cell, height: cell)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var locked: some View {
        Group {
            switch family {
            case .systemSmall:
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill").imageScale(.medium).foregroundStyle(.secondary)
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
                        Text("Premium erforderlich").font(.headline)
                        Text("Tippe, um die Paywall zu öffnen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Richtet die Tage so aus, dass der erste Eintrag auf dem lokalen Wochenanfang liegt,
    /// danach 7er-Chunks (Spalten). Die letzte Spalte enthält immer die aktuelle Woche (mit „heute“).
    private func makeColumnsWeekAligned(from days: [HeatmapDayCompact]) -> [[HeatmapDayCompact]] {
        guard !days.isEmpty else {
            let zeroCol = Array(repeating: HeatmapDayCompact(d: Date(), c: 0), count: 7)
            return [zeroCol]
        }

        let cal = Calendar.current
        var aligned: [HeatmapDayCompact] = days

        // 1) Falls der erste Tag NICHT auf dem lokalen Wochenanfang liegt, vorne mit Nullen auffüllen
        if let first = aligned.first {
            let firstWeekday = cal.firstWeekday
            let weekday = cal.component(.weekday, from: first.d) // 1...7
            var leadPad = (weekday - firstWeekday)
            if leadPad < 0 { leadPad += 7 }
            if leadPad > 0 {
                let pad = Array(repeating: HeatmapDayCompact(d: first.d, c: 0), count: leadPad)
                aligned = pad + aligned
            }
        }

        // 2) In 7er-Chunks schneiden (älteste -> neueste)
        var chunks: [[HeatmapDayCompact]] = stride(from: 0, to: aligned.count, by: 7).map {
            Array(aligned[$0..<min($0 + 7, aligned.count)])
        }

        // 3) Letzte Spalte auf genau 7 Elemente auffüllen (falls die letzte Woche noch nicht vollständig ist)
        if let last = chunks.last, last.count < 7 {
            let deficit = 7 - last.count
            chunks[chunks.count - 1] = last + Array(repeating: HeatmapDayCompact(d: last.last?.d ?? Date(), c: 0), count: deficit)
        }

        return chunks
    }

    private func color(for count: Int) -> Color {
        if count == 0 { return Color(.systemGray5) }
        let intensity = min(1.0, 0.18 + Double(count) * 0.22)
        return Color.accentColor.opacity(intensity)
    }
}

struct TrainingHeatmapWidget: Widget {
    let kind = "TrainingHeatmapWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HeatmapProvider()) { entry in
            TrainingHeatmapWidgetView(entry: entry)
                .widgetBackground()
        }
        .configurationDisplayName("Aktivitäts‑Heatmap")
        .description("Echte Trainingsaktivität – letzte Wochen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// iOS16/17-safe background helper
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
