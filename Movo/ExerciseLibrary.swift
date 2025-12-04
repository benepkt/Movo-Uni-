import Foundation
import Combine

class ExerciseLibrary: ObservableObject {
    @Published private(set) var exercisesInfo: [ExerciseInfo] = []
    
    var exercises: [ExerciseInfo] {
        exercisesInfo
    }

    private let exercisesKey = "exerciseLibrary.exercises"

    init() {
        loadExercises()
    }

    func addExercise(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !exercisesInfo.contains(where: { $0.name == trimmed }) else { return }

        let newExercise = ExerciseInfo(
            name: trimmed,
            muscleGroup: "Unbekannt",
            instructions: "Keine Anleitung verfügbar"
        )
        exercisesInfo.append(newExercise)
        saveExercises()
    }

    func deleteExercise(at offsets: IndexSet) {
        exercisesInfo.remove(atOffsets: offsets)
        saveExercises()
    }

  

    private func saveExercises() {
        if let encoded = try? JSONEncoder().encode(exercisesInfo) {
            UserDefaults.standard.set(encoded, forKey: exercisesKey)
        }
    }

    private func loadExercises() {
        if let data = UserDefaults.standard.data(forKey: exercisesKey),
           let decoded = try? JSONDecoder().decode([ExerciseInfo].self, from: data) {
            exercisesInfo = decoded
        } else {
            // Beispielübungen
            exercisesInfo = [
                    ExerciseInfo(name: "Arnold Press (Dumbbell)", muscleGroup: "Shoulders", instructions: "Starte mit den Hanteln vor der Brust, drehe beim Hochdrücken die Handflächen nach vorn."),
                    ExerciseInfo(name: "Back Extension + Weight", muscleGroup: "Lower Back", instructions: "Halte zusätzlich ein Gewicht vor der Brust während der Rückenstreckung."),
                    ExerciseInfo(name: "Bench Dip", muscleGroup: "Triceps", instructions: "Stütze dich rücklings auf eine Bank, senke den Körper und drücke dich wieder hoch."),
                    ExerciseInfo(name: "Bench Press (Barbell)", muscleGroup: "Chest", instructions: "Lege dich auf die Bank, greife die Langhantel schulterbreit und drücke sie hoch."),
                    ExerciseInfo(name: "Bench Press (Dumbbell)", muscleGroup: "Chest", instructions: "Lege dich auf die Bank, halte Kurzhanteln und drücke sie gleichmäßig nach oben."),
                    ExerciseInfo(name: "Bench Press (Smith Machine)", muscleGroup: "Chest", instructions: "Führe die Bankdrückbewegung in der geführten Langhantelmaschine aus."),
                    ExerciseInfo(name: "Bench Press - Close Grip (Barbell)", muscleGroup: "Triceps", instructions: "Greife die Langhantel eng, senke sie zur Brust und drücke sie hoch."),
                    ExerciseInfo(name: "Bench Press - Wide Grip (Barbell)", muscleGroup: "Chest", instructions: "Greife die Langhantel weit, senke sie kontrolliert und drücke sie nach oben."),
                    ExerciseInfo(name: "Bent Over One Arm Row (Dumbbell)", muscleGroup: "Back", instructions: "Stütze dich mit einer Hand ab, ziehe die Kurzhantel mit der anderen zum Körper."),
                    ExerciseInfo(name: "Bent Over Row (Barbell)", muscleGroup: "Back", instructions: "Beuge den Oberkörper nach vorn, ziehe die Langhantel zur Taille."),
                    ExerciseInfo(name: "Bent Over Row (Dumbbell)", muscleGroup: "Back", instructions: "Ziehe zwei Kurzhanteln gleichzeitig zur Hüfte bei vorgeneigtem Oberkörper."),
                    ExerciseInfo(name: "Bent Over Row - Underhand (Barbell)", muscleGroup: "Back", instructions: "Greife die Langhantel im Untergriff und ziehe sie zum unteren Bauch."),
                    ExerciseInfo(name: "Bicep Curl (Barbell)", muscleGroup: "Biceps", instructions: "Halte die Langhantel schulterbreit und beuge die Arme kontrolliert."),
                    ExerciseInfo(name: "Bicep Curl (Cable)", muscleGroup: "Biceps", instructions: "Ziehe den Kabelgriff zur Brust mit gebeugten Ellenbogen."),
                    ExerciseInfo(name: "Bicep Curl (Dumbbell)", muscleGroup: "Biceps", instructions: "Halte Kurzhanteln an den Seiten und beuge die Arme kontrolliert nach oben."),
                    ExerciseInfo(name: "Bicep Curl (Machine)", muscleGroup: "Biceps", instructions: "Führe kontrollierte Curls mit der Maschine aus."),
                    ExerciseInfo(name: "Biceps Curl Scottbank", muscleGroup: "Biceps", instructions: "Lehne die Arme auf die Scottbank und führe Curls mit kontrollierter Bewegung aus."),
                    ExerciseInfo(name: "Box Squat (Barbell)", muscleGroup: "Legs", instructions: "Senke dich mit einer Langhantel auf eine Box und stehe dann explosiv auf."),
                    ExerciseInfo(name: "Bulgarian Split Squat", muscleGroup: "Legs", instructions: "Stelle ein Bein nach hinten auf eine Bank und führe einbeinige Kniebeugen aus."),
                    ExerciseInfo(name: "Cable Crossover", muscleGroup: "Chest", instructions: "Ziehe beide Kabelzüge vor dem Körper zusammen auf Brusthöhe."),
                    ExerciseInfo(name: "Cable Crunch", muscleGroup: "Core", instructions: "Ziehe das Kabelseil nach unten, während du den Oberkörper beugst."),
                    ExerciseInfo(name: "Cable Kickback", muscleGroup: "Glutes", instructions: "Strecke das Bein nach hinten mit Kabelwiderstand."),
                    ExerciseInfo(name: "Cable Pull Through", muscleGroup: "Glutes", instructions: "Beuge dich vor und ziehe das Kabel durch die Beine nach vorn."),
                    ExerciseInfo(name: "Cable Twist", muscleGroup: "Obliques", instructions: "Ziehe das Kabel seitlich über den Körper zur anderen Seite."),
                    ExerciseInfo(name: "Calf Press on Leg Press", muscleGroup: "Calves", instructions: "Drücke das Gewicht mit den Zehen nach oben."),
                    ExerciseInfo(name: "Calf Press on Seated Leg Press", muscleGroup: "Calves", instructions: "Führe Wadenheben auf der sitzenden Beinpresse aus."),
                    ExerciseInfo(name: "Chest Dip", muscleGroup: "Chest", instructions: "Senke den Körper an den Dip-Stangen ab und drücke dich wieder hoch."),
                    ExerciseInfo(name: "Chest Fly (Dumbbell)", muscleGroup: "Chest", instructions: "Führe die Hanteln seitlich auseinander und wieder zusammen."),
                    ExerciseInfo(name: "Chest Fly Kabel Oben", muscleGroup: "Chest", instructions: "Ziehe die Kabel von oben in einer Bogenbewegung zusammen."),
                    ExerciseInfo(name: "Chest Fly Kabel Von Unten", muscleGroup: "Chest", instructions: "Ziehe die Kabel von unten nach oben zusammen."),
                    ExerciseInfo(name: "Chest Press (Machine)", muscleGroup: "Chest", instructions: "Drücke die Griffe der Maschine gerade nach vorn."),
                    ExerciseInfo(name: "Clean (Barbell)", muscleGroup: "Full Body", instructions: "Ziehe die Langhantel vom Boden explosiv bis zu den Schultern."),
                    ExerciseInfo(name: "Clean and Jerk (Barbell)", muscleGroup: "Full Body", instructions: "Führe Clean aus und stoße die Hantel anschließend über Kopf."),
                    ExerciseInfo(name: "Concentration Curl (Dumbbell)", muscleGroup: "Biceps", instructions: "Führe Bizepscurls mit dem Ellenbogen am Oberschenkel ausgeführt."),
                    ExerciseInfo(name: "Crunch (Machine)", muscleGroup: "Core", instructions: "Führe Crunches mit zusätzlichem Widerstand an der Maschine aus."),
                    ExerciseInfo(name: "Deadlift (Barbell)", muscleGroup: "Back", instructions: "Hebe die Langhantel mit geradem Rücken vom Boden an."),
                    ExerciseInfo(name: "Deadlift (Dumbbell)", muscleGroup: "Back", instructions: "Führe Kreuzheben mit Kurzhanteln neben den Beinen aus."),
                    ExerciseInfo(name: "Deadlift (Smith Machine)", muscleGroup: "Back", instructions: "Führe Kreuzheben mit der Smith-Maschine aus."),
                    ExerciseInfo(name: "Decline Bench Press (Barbell)", muscleGroup: "Chest", instructions: "Lege dich auf eine Schrägbank und drücke die Langhantel nach oben."),
                    ExerciseInfo(name: "Decline Bench Press (Dumbbell)", muscleGroup: "Chest", instructions: "Führe dieselbe Bewegung mit Kurzhanteln auf der Schrägbank aus."),
                    ExerciseInfo(name: "Decline Bench Press (Smith Machine)", muscleGroup: "Chest", instructions: "Führe die Übung mit der Smith-Maschine auf der Schrägbank aus."),
                    ExerciseInfo(name: "Deficit Deadlift (Barbell)", muscleGroup: "Back", instructions: "Stelle dich erhöht und führe Kreuzheben für mehr Bewegungsumfang aus."),
                    ExerciseInfo(name: "Dumbbell Row", muscleGroup: "Back", instructions: "Ziehe die Kurzhantel mit gebeugtem Rücken zur Taille."),
                    ExerciseInfo(name: "Dumbbell Shoulder Press", muscleGroup: "Shoulders", instructions: "Drücke die Kurzhanteln über den Kopf."),
                    ExerciseInfo(name: "EZ Bar Curl", muscleGroup: "Biceps", instructions: "Beuge die Arme mit der SZ-Stange kontrolliert."),
                    ExerciseInfo(name: "Face Pull (Cable)", muscleGroup: "Rear Delts", instructions: "Ziehe das Seil auf Augenhöhe zu deinem Gesicht."),
                    ExerciseInfo(name: "Floor Press (Barbell)", muscleGroup: "Chest", instructions: "Lege dich auf den Boden und drücke die Langhantel nach oben."),
                    ExerciseInfo(name: "Front Raise (Plate)", muscleGroup: "Shoulders", instructions: "Hebe eine Gewichtsscheibe vor den Körper auf Schulterhöhe."),
                    ExerciseInfo(name: "Front Squat (Barbell)", muscleGroup: "Legs", instructions: "Lege die Langhantel auf die vordere Schulter und führe Kniebeugen aus."),
                    ExerciseInfo(name: "Glute Kickback (Machine)", muscleGroup: "Glutes", instructions: "Drücke das Bein nach hinten mit Hilfe der Maschine."),
                    ExerciseInfo(name: "Goblet Squat (Kettlebell)", muscleGroup: "Legs", instructions: "Halte die Kettlebell vor der Brust und mache eine Kniebeuge."),
                    ExerciseInfo(name: "Good Morning (Barbell)", muscleGroup: "Lower Back", instructions: "Beuge den Oberkörper nach vorn mit einer Langhantel auf den Schultern."),
                    ExerciseInfo(name: "Hack Squat (Machine)", muscleGroup: "Legs", instructions: "Führe Kniebeugen in der Hackenschmidt-Maschine aus."),
                    ExerciseInfo(name: "Hack Squat (Barbell)", muscleGroup: "Legs", instructions: "Halte die Langhantel hinter dem Körper und führe eine Kniebeuge aus."),
                    ExerciseInfo(name: "Hammer Curl (Band)", muscleGroup: "Biceps", instructions: "Führe den Curl mit neutralem Griff gegen den Widerstand des Bands aus."),
                    ExerciseInfo(name: "Hammer Curl (Cable)", muscleGroup: "Biceps", instructions: "Führe den Curl mit neutralem Griff am Kabelzug aus."),
                    ExerciseInfo(name: "Hammer Curl (Dumbbell)", muscleGroup: "Biceps", instructions: "Führe den Curl mit neutralem Griff mit Kurzhanteln aus."),
                    ExerciseInfo(name: "Hang Clean (Barbell)", muscleGroup: "Full Body", instructions: "Reiße die Langhantel explosiv aus dem Hang zur Schulter."),
                    ExerciseInfo(name: "Hang Snatch (Barbell)", muscleGroup: "Full Body", instructions: "Reiße die Langhantel aus dem Hang über den Kopf."),
                    ExerciseInfo(name: "High Pull (Barbell)", muscleGroup: "Traps", instructions: "Ziehe die Langhantel explosiv bis zur Brust."),
                    ExerciseInfo(name: "Incline Bench Press (Barbell)", muscleGroup: "Chest", instructions: "Drücke die Langhantel schräg nach oben von der Bank."),
                    ExerciseInfo(name: "Incline Bench Press (Cable)", muscleGroup: "Chest", instructions: "Führe Schrägbankdrücken mit Kabelzug aus."),
                    ExerciseInfo(name: "Incline Bench Press (Dumbbell)", muscleGroup: "Chest", instructions: "Drücke die Kurzhanteln schräg nach oben."),
                    ExerciseInfo(name: "Incline Bench Press (Smith Machine)", muscleGroup: "Chest", instructions: "Drücke die Stange der Smith-Maschine schräg nach oben."),
                    ExerciseInfo(name: "Incline Chest Fly (Dumbbell)", muscleGroup: "Chest", instructions: "Führe Schrägbankfliegende mit Kurzhanteln aus."),
                    ExerciseInfo(name: "Incline Chest Press (Machine)", muscleGroup: "Chest", instructions: "Drücke die Griffe der Maschine von der Schrägbank nach vorne."),
                    ExerciseInfo(name: "Incline Curl (Dumbbell)", muscleGroup: "Biceps", instructions: "Führe Bizepscurls auf der Schrägbank mit Kurzhanteln aus."),
                    ExerciseInfo(name: "Incline Row (Dumbbell)", muscleGroup: "Back", instructions: "Rudere mit Kurzhanteln auf einer schrägen Bank."),
                    ExerciseInfo(name: "Inverted Row (Bodyweight)", muscleGroup: "Back", instructions: "Ziehe dich unter einer Stange zum Körper hoch."),
                    ExerciseInfo(name: "Iso-Lateral Chest Press (Machine)", muscleGroup: "Chest", instructions: "Drücke die Griffe einzeln mit der Brustmuskulatur nach vorne."),
                    ExerciseInfo(name: "Iso-Lateral Row (Machine)", muscleGroup: "Back", instructions: "Ziehe die Griffe einzeln zur Körpermitte."),
                    ExerciseInfo(name: "Jump Shrug (Barbell)", muscleGroup: "Traps", instructions: "Springe leicht und ziehe die Schultern mit der Langhantel explosiv nach oben."),
                    ExerciseInfo(name: "Jump Squat", muscleGroup: "Legs", instructions: "Mache eine explosive Kniebeuge mit einem Sprung nach oben."),
                    ExerciseInfo(name: "Kettlebell Swing", muscleGroup: "Glutes", instructions: "Schwinge die Kettlebell mit gestreckten Armen nach vorne."),
                    ExerciseInfo(name: "Kettlebell Turkish Get Up", muscleGroup: "Full Body", instructions: "Stehe kontrolliert mit einer Kettlebell über Kopf auf."),
                    ExerciseInfo(name: "Klappmesser Crunch", muscleGroup: "Abs", instructions: "Berühre mit Händen und Füßen gleichzeitig in der Luft."),
                    ExerciseInfo(name: "Knee Raise (Captain's Chair)", muscleGroup: "Abs", instructions: "Ziehe die Knie im Hängesitz kontrolliert zur Brust."),
                    ExerciseInfo(name: "Lat Pulldown (Cable)", muscleGroup: "Back", instructions: "Ziehe die Stange zum oberen Brustbein."),
                    ExerciseInfo(name: "Lat Pulldown (Machine)", muscleGroup: "Back", instructions: "Ziehe die Griffe der Maschine kontrolliert nach unten."),
                    ExerciseInfo(name: "Lat Pulldown (Single Arm)", muscleGroup: "Back", instructions: "Ziehe einseitig mit Kabel oder Griff nach unten."),
                    ExerciseInfo(name: "Lat Pulldown - Underhand (Band)", muscleGroup: "Back", instructions: "Ziehe das Widerstandsband im Untergriff nach unten."),
                    ExerciseInfo(name: "Lat Pulldown Underhand (Cable)", muscleGroup: "Back", instructions: "Ziehe die Stange mit Untergriff zum Brustbein."),
                    ExerciseInfo(name: "Lat Pulldown Wide Grip (Cable)", muscleGroup: "Back", instructions: "Ziehe die Stange mit breitem Griff nach unten."),
                    ExerciseInfo(name: "Lateral Raise (Band)", muscleGroup: "Shoulders", instructions: "Hebe die Arme seitlich mit einem Widerstandsband."),
                    ExerciseInfo(name: "Lateral Raise (Dumbbell)", muscleGroup: "Shoulders", instructions: "Hebe die Kurzhanteln seitlich auf Schulterhöhe."),
                    ExerciseInfo(name: "Lateral Raise (Machine)", muscleGroup: "Shoulders", instructions: "Hebe die Arme seitlich mit der Maschine."),
                    ExerciseInfo(name: "Leg Extension (Machine)", muscleGroup: "Quads", instructions: "Strecke die Beine an der Beinstreckmaschine."),
                    ExerciseInfo(name: "Leg Press", muscleGroup: "Legs", instructions: "Drücke das Gewicht mit den Beinen weg."),
                    ExerciseInfo(name: "Lunge (Barbell)", muscleGroup: "Legs", instructions: "Mache Ausfallschritte mit einer Langhantel."),
                    ExerciseInfo(name: "Lunge (Bodyweight)", muscleGroup: "Legs", instructions: "Mache Ausfallschritte mit dem eigenen Körpergewicht."),
                    ExerciseInfo(name: "Lunge (Dumbbell)", muscleGroup: "Legs", instructions: "Mache Ausfallschritte mit Kurzhanteln."),
                    ExerciseInfo(name: "Lying Leg Curl (Machine)", muscleGroup: "Hamstrings", instructions: "Beuge die Beine an der liegenden Beinbeugemaschine."),
                    ExerciseInfo(name: "Overhead Press (Barbell)", muscleGroup: "Shoulders", instructions: "Drücke die Langhantel über den Kopf."),
                    ExerciseInfo(name: "Overhead Press (Cable)", muscleGroup: "Shoulders", instructions: "Drücke das Kabelgewicht über den Kopf."),
                    ExerciseInfo(name: "Overhead Press (Dumbbell)", muscleGroup: "Shoulders", instructions: "Drücke die Kurzhanteln über Kopf."),
                    ExerciseInfo(name: "Overhead Press (Smith Machine)", muscleGroup: "Shoulders", instructions: "Drücke die Stange der Smith-Maschine über den Kopf."),
                    ExerciseInfo(name: "Overhead Squat (Barbell)", muscleGroup: "Full Body", instructions: "Führe eine Kniebeuge mit einer über Kopf gehaltenen Langhantel aus."),
                    ExerciseInfo(name: "Pec Deck (Machine)", muscleGroup: "Chest", instructions: "Führe fliegende Bewegungen mit der Maschine aus."),
                    ExerciseInfo(name: "Pendlay Row (Barbell)", muscleGroup: "Back", instructions: "Rudere die Langhantel vom Boden mit explosiver Bewegung."),
                    ExerciseInfo(name: "Pistol Squat", muscleGroup: "Legs", instructions: "Führe eine einbeinige Kniebeuge mit Kontrolle aus."),
                    ExerciseInfo(name: "Power Clean (Barbell)", muscleGroup: "Full Body", instructions: "Reiße die Langhantel in einer schnellen Bewegung zur Schulter."),
                    ExerciseInfo(name: "Preacher Curl (Barbell)", muscleGroup: "Biceps", instructions: "Führe Bizepscurls an der Scottbank mit der Langhantel aus."),
                    ExerciseInfo(name: "Preacher Curl (Machine)", muscleGroup: "Biceps", instructions: "Führe Bizepscurls an der Scott-Maschine aus."),
                    ExerciseInfo(name: "Pull Up", muscleGroup: "Back", instructions: "Ziehe dich mit einem Obergriff an einer Stange hoch."),
                    ExerciseInfo(name: "Pull Up (Assisted)", muscleGroup: "Back", instructions: "Ziehe dich mit Unterstützung an einer Stange hoch."),
                    ExerciseInfo(name: "Pull Up (Band)", muscleGroup: "Back", instructions: "Ziehe dich mit Hilfe eines Widerstandsbands an einer Stange hoch."),
                    ExerciseInfo(name: "Pullover", muscleGroup: "Chest", instructions: "Senke das Gewicht hinter dem Kopf ab und bringe es wieder nach oben."),
                    ExerciseInfo(name: "Pullover (Dumbbell)", muscleGroup: "Chest", instructions: "Führe die Bewegung mit einer Kurzhantel über dem Kopf aus."),
                    ExerciseInfo(name: "Pullover (Machine)", muscleGroup: "Chest", instructions: "Führe den Pullover kontrolliert an der Maschine aus."),
                    ExerciseInfo(name: "Push Press", muscleGroup: "Shoulders", instructions: "Drücke die Langhantel mit Schwung über den Kopf."),
                    ExerciseInfo(name: "Push Up", muscleGroup: "Chest", instructions: "Drücke den Körper vom Boden nach oben."),
                    ExerciseInfo(name: "Push Up (Band)", muscleGroup: "Chest", instructions: "Führe Liegestütze mit zusätzlichem Widerstandsband aus."),
                    ExerciseInfo(name: "Push Up (Knees)", muscleGroup: "Chest", instructions: "Führe Liegestütze auf den Knien aus."),
                    ExerciseInfo(name: "Rack Pull (Barbell)", muscleGroup: "Back", instructions: "Hebe die Langhantel vom Rack in halber Deadlift-Position."),
                    ExerciseInfo(name: "Reverse Crunch", muscleGroup: "Abs", instructions: "Ziehe die Beine zur Brust und hebe das Becken leicht an."),
                    ExerciseInfo(name: "Reverse Curl (Band)", muscleGroup: "Biceps", instructions: "Beuge die Arme mit Handrücken nach oben gegen ein Widerstandsband."),
                    ExerciseInfo(name: "Reverse Curl (Barbell)", muscleGroup: "Biceps", instructions: "Führe Curls mit der Langhantel im Obergriff aus."),
                    ExerciseInfo(name: "Reverse Curl (Dumbbell)", muscleGroup: "Biceps", instructions: "Führe Curls mit Kurzhanteln im Obergriff aus."),
                    ExerciseInfo(name: "Reverse Fly (Cable)", muscleGroup: "Rear Delts", instructions: "Ziehe die Kabelarme seitlich nach hinten."),
                    ExerciseInfo(name: "Reverse Fly (Dumbbell)", muscleGroup: "Rear Delts", instructions: "Führe fliegende Bewegungen mit Kurzhanteln zur Seite aus."),
                    ExerciseInfo(name: "Reverse Fly (Machine)", muscleGroup: "Rear Delts", instructions: "Ziehe die Griffe der Maschine seitlich nach hinten."),
                    ExerciseInfo(name: "Romanian Deadlift (Dumbbell)", muscleGroup: "Hamstrings", instructions: "Senke die Kurzhanteln mit gestreckten Beinen kontrolliert ab."),
                    ExerciseInfo(name: "Rowing (Machine)", muscleGroup: "Back", instructions: "Ziehe den Griff kontrolliert zur Körpermitte und lasse ihn zurück."),
                    ExerciseInfo(name: "Running (Treadmill)", muscleGroup: "Legs", instructions: "Laufe auf dem Laufband mit gleichmäßigem Tempo."),
                    ExerciseInfo(name: "Russian Twist", muscleGroup: "Abs", instructions: "Drehe den Oberkörper im Sitzen von Seite zu Seite."),
                    ExerciseInfo(name: "Seated Calf Raise (Machine)", muscleGroup: "Calves", instructions: "Hebe die Fersen mit Widerstand an der Wadenmaschine."),
                    ExerciseInfo(name: "Seated Calf Raise (Plate Loaded)", muscleGroup: "Calves", instructions: "Führe die Wadenübung mit Gewichtsscheiben aus."),
                    ExerciseInfo(name: "Seated Leg Curl (Machine)", muscleGroup: "Hamstrings", instructions: "Beuge die Beine an der sitzenden Beinbeugemaschine."),
                    ExerciseInfo(name: "Seated Leg Press (Machine)", muscleGroup: "Legs", instructions: "Drücke das Gewicht mit den Beinen aus sitzender Position."),
                    ExerciseInfo(name: "Seated Overhead Press (Barbell)", muscleGroup: "Shoulders", instructions: "Drücke die Langhantel über Kopf im Sitzen."),
                    ExerciseInfo(name: "Seated Overhead Press (Dumbbell)", muscleGroup: "Shoulders", instructions: "Drücke die Kurzhanteln über Kopf im Sitzen."),
                    ExerciseInfo(name: "Seated Palms Up Wrist Curl (Dumbbell)", muscleGroup: "Forearms", instructions: "Rolle die Kurzhanteln mit Handflächen nach oben ein."),
                    ExerciseInfo(name: "Seated Row (Cable)", muscleGroup: "Back", instructions: "Ziehe das Kabel sitzend zur Körpermitte."),
                    ExerciseInfo(name: "Seated Row (Machine)", muscleGroup: "Back", instructions: "Ziehe die Griffe der Maschine zur Brust."),
                    ExerciseInfo(name: "Seated Wide Grip Row (Cable)", muscleGroup: "Back", instructions: "Ziehe das Kabel mit weitem Griff zur Brust."),
                    ExerciseInfo(name: "Shoulder Press (Machine)", muscleGroup: "Shoulders", instructions: "Drücke die Griffe über den Kopf."),
                    ExerciseInfo(name: "Shoulder Press (Plate Loaded)", muscleGroup: "Shoulders", instructions: "Drücke das Gewicht mit einer Plate-loaded-Maschine über Kopf."),
                    ExerciseInfo(name: "Shoulder Press (Dumbbells)", muscleGroup: "Shoulders", instructions: "Drücke Kurzhanteln über Kopf."),
                    ExerciseInfo(name: "Shrug (Barbell)", muscleGroup: "Traps", instructions: "Ziehe die Schultern mit der Langhantel nach oben."),
                    ExerciseInfo(name: "Shrug (Dumbbells)", muscleGroup: "Traps", instructions: "Ziehe die Schultern mit Kurzhanteln nach oben."),
                    ExerciseInfo(name: "Shrug (Machine)", muscleGroup: "Traps", instructions: "Ziehe die Griffe der Maschine mit den Schultern nach oben."),
                    ExerciseInfo(name: "Shrug (Smith Machine)", muscleGroup: "Traps", instructions: "Führe Shrugs mit der Smith Machine aus."),
                    ExerciseInfo(name: "Side Bend (Cable)", muscleGroup: "Obliques", instructions: "Beuge dich seitlich mit Kabelzug."),
                    ExerciseInfo(name: "Side Bend (Dumbbell)", muscleGroup: "Obliques", instructions: "Beuge dich seitlich mit einer Kurzhantel."),
                    ExerciseInfo(name: "Sit Up", muscleGroup: "Abs", instructions: "Rolle den Oberkörper bis zu den Knien auf."),
                    ExerciseInfo(name: "Skullcrusher (Barbell)", muscleGroup: "Triceps", instructions: "Senke die Langhantel zur Stirn und strecke die Arme wieder."),
                    ExerciseInfo(name: "Skullcrusher (Dumbbell)", muscleGroup: "Triceps", instructions: "Führe dieselbe Bewegung mit Kurzhanteln aus."),
                    ExerciseInfo(name: "Snatch (Barbell)", muscleGroup: "Full Body", instructions: "Ziehe die Langhantel explosiv über den Kopf."),
                    ExerciseInfo(name: "Spider Curls", muscleGroup: "Biceps", instructions: "Führe Bizepscurls in Bauchlage über einer Bank aus."),
                    ExerciseInfo(name: "Split Jerk (Barbell)", muscleGroup: "Shoulders", instructions: "Stoße das Gewicht mit einem Ausfallschritt über den Kopf."),
                    ExerciseInfo(name: "Squat (Band)", muscleGroup: "Legs", instructions: "Führe Kniebeugen mit Widerstandsband aus."),
                    ExerciseInfo(name: "Squat (Barbell)", muscleGroup: "Legs", instructions: "Mache Kniebeugen mit der Langhantel auf dem Rücken."),
                    ExerciseInfo(name: "Squat (Bodyweight)", muscleGroup: "Legs", instructions: "Mache Kniebeugen ohne zusätzliches Gewicht."),
                    ExerciseInfo(name: "Squat (Dumbbell)", muscleGroup: "Legs", instructions: "Halte Kurzhanteln und mache Kniebeugen."),
                    ExerciseInfo(name: "Squat (Machine)", muscleGroup: "Legs", instructions: "Führe Kniebeugen mit einer geführten Maschine aus."),
                    ExerciseInfo(name: "Squat (Smith Machine)", muscleGroup: "Legs", instructions: "Führe Kniebeugen mit der Smith Machine aus."),
                    ExerciseInfo(name: "Squat Row (Band)", muscleGroup: "Full Body", instructions: "Kombiniere Kniebeugen mit Rudern gegen das Band."),
                    ExerciseInfo(name: "Standing Calf Raise (Barbell)", muscleGroup: "Calves", instructions: "Hebe die Fersen mit Langhantel auf den Schultern."),
                    ExerciseInfo(name: "Standing Calf Raise (Bodyweight)", muscleGroup: "Calves", instructions: "Hebe die Fersen ohne Zusatzgewicht."),
                    ExerciseInfo(name: "Standing Calf Raise (Dumbbell)", muscleGroup: "Calves", instructions: "Hebe die Fersen mit Kurzhanteln."),
                    ExerciseInfo(name: "Standing Calf Raise (Machine)", muscleGroup: "Calves", instructions: "Führe die Wadenübung an der Maschine stehend aus."),
                    ExerciseInfo(name: "Standing Calf Raise (Smith Machine)", muscleGroup: "Calves", instructions: "Führe die Übung an der Smith Machine mit Gewicht aus."),
                    ExerciseInfo(name: "Step Up", muscleGroup: "Legs", instructions: "Steige mit einem Bein auf eine Plattform und ziehe das andere nach."),
                    ExerciseInfo(name: "Stiff Leg Deadlift (Barbell)", muscleGroup: "Hamstrings", instructions: "Senke die Langhantel mit gestreckten Beinen kontrolliert."),
                    ExerciseInfo(name: "Stiff Leg Deadlift (Dumbbell)", muscleGroup: "Hamstrings", instructions: "Senke die Kurzhanteln mit gestreckten Beinen kontrolliert."),
                    ExerciseInfo(name: "Stiff Leg Deadlift (Band)", muscleGroup: "Hamstrings", instructions: "Senke den Oberkörper gegen den Widerstand des Bands."),
                    ExerciseInfo(name: "Strict Military Press (Barbell)", muscleGroup: "Shoulders", instructions: "Drücke die Langhantel im Stehen streng über Kopf."),
                    ExerciseInfo(name: "Sumo Deadlift (Barbell)", muscleGroup: "Glutes", instructions: "Hebe das Gewicht mit breiter Beinstellung."),
                    ExerciseInfo(name: "Sumo Deadlift High Pull (Barbell)", muscleGroup: "Full Body", instructions: "Kombiniere Sumo-Deadlift mit hohem Zug zur Brust."),
                    ExerciseInfo(name: "Superman", muscleGroup: "Lower Back", instructions: "Hebe Arme und Beine gleichzeitig im Liegen an."),
                    ExerciseInfo(name: "Supine Press", muscleGroup: "Chest", instructions: "Drücke das Gewicht im Liegen nach oben."),
                    ExerciseInfo(name: "SZ Curl", muscleGroup: "Biceps", instructions: "Führe Bizepscurls mit SZ-Stange aus."),
                    ExerciseInfo(name: "T Bar Row", muscleGroup: "Back", instructions: "Ziehe das Gewicht mit neutralem Griff zur Körpermitte."),
                    ExerciseInfo(name: "Thruster (Barbell)", muscleGroup: "Full Body", instructions: "Kombiniere Front Squat mit Schulterdrücken."),
                    ExerciseInfo(name: "Thruster (Kettlebell)", muscleGroup: "Full Body", instructions: "Führe die Kombi aus Squat und Press mit Kettlebell aus."),
                    ExerciseInfo(name: "Toes to Bar", muscleGroup: "Abs", instructions: "Führe die Füße im Hang bis zur Stange."),
                    ExerciseInfo(name: "Torso Rotation (Machine)", muscleGroup: "Obliques", instructions: "Drehe den Oberkörper gegen den Widerstand der Maschine."),
                    ExerciseInfo(name: "Trap Bar Deadlift", muscleGroup: "Glutes", instructions: "Hebe das Gewicht mit der Trap Bar vom Boden."),
                    ExerciseInfo(name: "Tricep Pushdown (Single Handed)", muscleGroup: "Triceps", instructions: "Drücke das Kabelgriff einzeln nach unten."),
                    ExerciseInfo(name: "Triceps Dip", muscleGroup: "Triceps", instructions: "Drücke den Körper mit den Armen nach oben."),
                    ExerciseInfo(name: "Triceps Dip (Assisted)", muscleGroup: "Triceps", instructions: "Führe Dips mit Unterstützung an der Maschine aus."),
                    ExerciseInfo(name: "Triceps Extension (Barbell)", muscleGroup: "Triceps", instructions: "Strecke die Arme über Kopf mit der Langhantel."),
                    ExerciseInfo(name: "Triceps Extension (Cable)", muscleGroup: "Triceps", instructions: "Strecke die Arme mit dem Kabelzug."),
                    ExerciseInfo(name: "Triceps Extension (Dumbbell)", muscleGroup: "Triceps", instructions: "Strecke die Arme mit einer oder zwei Kurzhanteln."),
                    ExerciseInfo(name: "Triceps Extension (Machine)", muscleGroup: "Triceps", instructions: "Führe die Bewegung an der Maschine aus."),
                    ExerciseInfo(name: "Triceps Extension", muscleGroup: "Triceps", instructions: "Führe eine beliebige Trizepsstreckung aus."),
                    ExerciseInfo(name: "Upright Row (Barbell)", muscleGroup: "Shoulders", instructions: "Ziehe die Langhantel eng am Körper nach oben."),
                    ExerciseInfo(name: "Upright Row (Cable)", muscleGroup: "Shoulders", instructions: "Ziehe das Kabel eng am Körper nach oben."),
                    ExerciseInfo(name: "Upright Row (Dumbbell)", muscleGroup: "Shoulders", instructions: "Ziehe Kurzhanteln eng am Körper nach oben."),
                    ExerciseInfo(name: "V Up", muscleGroup: "Abs", instructions: "Berühre Hände und Füße gleichzeitig in der Luft."),
                    ExerciseInfo(name: "Wrist Roller", muscleGroup: "Forearms", instructions: "Rolle ein Gewicht mit den Handgelenken nach oben."),
                    ExerciseInfo(name: "Zercher Squat (Barbell)", muscleGroup: "Legs", instructions: "Halte die Langhantel in den Ellenbeugen und führe Kniebeugen aus.")
                


                ]




            
        }
    }

    func exerciseInfo(for name: String) -> ExerciseInfo? {
        exercisesInfo.first { $0.name == name }
    }
}
extension ExerciseLibrary {
    func addNote(for exerciseId: UUID, text: String = "") {
        if let index = exercisesInfo.firstIndex(where: { $0.id == exerciseId }) {
            exercisesInfo[index].notes.append(Note(text: text))
            saveExercises()
        }
    }

    func updateNote(for exerciseId: UUID, note: Note) {
        if let exIndex = exercisesInfo.firstIndex(where: { $0.id == exerciseId }),
           let noteIndex = exercisesInfo[exIndex].notes.firstIndex(where: { $0.id == note.id }) {
            exercisesInfo[exIndex].notes[noteIndex] = note
            saveExercises()
        }
    }

    func deleteNote(for exerciseId: UUID, noteId: UUID) {
        if let exIndex = exercisesInfo.firstIndex(where: { $0.id == exerciseId }) {
            exercisesInfo[exIndex].notes.removeAll { $0.id == noteId }
            saveExercises()
        }
    }
}


extension ExerciseInfo {
    /// Baut aus dem sichtbaren Übungsnamen einen Lokalisierungs-Key:
    /// z.B. "Bench Press (Barbell)" -> "exercise.instructions.bench_press_barbell"
    ///     "Chest Fly Kabel Oben"   -> "exercise.instructions.chest_fly_kabel_oben"
    fileprivate var instructionKeyFromName: String {
        var s = name.lowercased()

        // Umlaute/ß robust handhaben
        s = s.replacingOccurrences(of: "ä", with: "ae")
             .replacingOccurrences(of: "ö", with: "oe")
             .replacingOccurrences(of: "ü", with: "ue")
             .replacingOccurrences(of: "ß", with: "ss")

        // Klammern/Plus/Bindestriche/sonstige Trenner normalisieren
        let replacers: [String: String] = [
            "(": " ", ")": " ", "+": " ", "–": " ", "—": " ", "-": " ",
            "/": " ", "&": " ", ",": " ", ".": " ", "'": "", "’": ""
        ]
        for (k, v) in replacers { s = s.replacingOccurrences(of: k, with: v) }

        // Mehrfach-Whitespaces -> Unterstrich, nur a–z0–9 zulassen
        s = s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "de_DE"))
        s = s.replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
             .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        return "exercise.instructions.\(s)"
    }

    /// Liefert die korrekte (ggf. lokalisierte) Anleitung mit Fallback.
    func localizedInstructions(using appSettings: AppSettings) -> String {
        // 1) Versuch über abgeleiteten Key
        let autoKey = instructionKeyFromName
        let localized = appSettings.localized(autoKey)
        if localized != autoKey { return localized }   // Key existiert → Treffer

        // 2) Falls (später) mal ein expliziter Key im Modell landen sollte:
        // if let key = instructionsKey, !key.isEmpty {
        //     let t = appSettings.localized(key)
        //     if t != key { return t }
        // }

        // 3) Fallback: gespeicherter Text oder neutrale Lokalisierung
        let trimmed = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? appSettings.localized("exercise.instructions.none") : trimmed
    }
}
