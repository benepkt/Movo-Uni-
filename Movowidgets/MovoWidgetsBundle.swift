import WidgetKit
import SwiftUI

@main
struct MovoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StepsWidget()        // ← dein bestehendes Heute-Widget (unverändert lassen)
        StepsWeeklyWidget()  // ← das neue 7-Tage-Widget
        TrainingWeeklyWidget()     // NEU: Trainings/Woche
    }
}
