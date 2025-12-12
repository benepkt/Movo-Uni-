import WidgetKit
import SwiftUI

@main
struct MovoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StepsWidget()               // ← bestehendes Heute-Widget
        StepsWeeklyWidget()         // ← 7‑Tage‑Widget Schritte
        TrainingWeeklyWidget()      // ← Trainings/Woche
        TrainingHeatmapWidget()     // ← NEU: Aktivitäts‑Heatmap
    }
}
