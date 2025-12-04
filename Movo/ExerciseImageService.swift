import UIKit
import AVFoundation

final class ExerciseMediaService {
    static let shared = ExerciseMediaService()
    private init() {}

    // Optionales eigenes Ressourcen-Bundle (falls du eines verwendest)
    private lazy var mediaBundle: Bundle? = {
        guard let url = Bundle.main.url(forResource: "ExerciseMedia", withExtension: "bundle") else { return nil }
        return Bundle(url: url)
    }()

    // ---- Mapping: zuerst Deutsch->Slug, dann slugifizieren
    private func key(_ name: String) -> String {
        let mapped = nameMap[name] ?? name  // <<<< WICHTIG
        return mapped.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    // ---- THUMBNAIL: zuerst aus Assets, dann ggf. aus Bundle-Datei
    func thumbnail(for name: String) -> UIImage? {
        let base = key(name)
        // 1) Assets.xcassets (Image-Set-Name exakt: "<slug>-thumb")
        if let img = UIImage(named: "\(base)-thumb") { return img }

        // 2) Fallback: Datei aus optionalem Ressourcen-Bundle
        if let b = mediaBundle {
            if let url = b.url(forResource: "\(base)-thumb", withExtension: "jpg"),
               let data = try? Data(contentsOf: url),
               let img  = UIImage(data: data) { return img }
            if let url = b.url(forResource: "\(base)-thumb", withExtension: "png"),
               let data = try? Data(contentsOf: url),
               let img  = UIImage(data: data) { return img }
        }
        return nil
    }

    // ---- VIDEO: erst Main Bundle, dann Ressourcen-Bundle
    func localVideoURL(for name: String) -> URL? {
        let base = key(name)
        // 1) Direkt im App-Bundle (empfohlen)
        if let url = Bundle.main.url(forResource: "\(base)-loop", withExtension: "mp4") { return url }
        if let url = Bundle.main.url(forResource: "\(base)-loop", withExtension: "mov") { return url }

        // 2) Optionales Ressourcen-Bundle
        if let b = mediaBundle {
            if let url = b.url(forResource: "\(base)-loop", withExtension: "mp4") { return url }
            if let url = b.url(forResource: "\(base)-loop", withExtension: "mov") { return url }
        }
        return nil
    }

    func prefetch(for names: [String]) {
        // bei Assets/Bundle eigentlich nicht nötig; harmless warmup:
        DispatchQueue.global(qos: .utility).async {
            for n in names { _ = self.thumbnail(for: n); _ = self.localVideoURL(for: n) }
        }
    }
}


extension ExerciseMediaService {
    // Deutsch → slug (englisch, kebab-case)
    fileprivate var nameMap: [String:String] {
        [
            // Warm-ups / Cardio
            "Jumping Jacks": "jumping-jacks",
            "Arm Circles": "arm-circles",
            "Arm Circles rückwärts": "arm-circles-reverse",
            "Arm Swings": "arm-swings",
            "High Knees": "high-knees",
            "Butt Kicks": "butt-kicks",
            "Torso Twists": "torso-twists",
            "Jump Rope": "jump-rope",
            "Seilspringen": "jump-rope",
            "Hip Opener": "hip-opener",
            "Side Lunges": "side-lunges",
            "Burpees (leicht)": "burpees-easy",
            "Burpees": "burpees",

            // Hauptübungen Kraft
            "Kniebeugen": "squat",
            "Bulgarian Split Squats": "bulgarian-split-squat",
            "Ausfallschritte": "forward-lunge",
            "Liegestütze": "push-up",
            "Liegestütze mit Klatschen": "clap-push-up",
            "Plank": "plank",
            "Plank mit Schulter-Taps": "plank-shoulder-taps",
            "Plank mit Beinheben": "plank-leg-raise",
            "Side Plank": "side-plank",
            "Side Plank mit Hüftheben": "side-plank-hip-raise",
            "Hollow Hold": "hollow-hold",
            "Hollow Hold (fortgeschritten)": "hollow-hold-advanced",
            "Hollow Rock (leicht)": "hollow-rock-easy",
            "Dead Bug (aktivieren)": "dead-bug",
            "Bird Dog": "bird-dog",
            "Toe Touches": "toe-touches",
            "Bicycle Crunches": "bicycle-crunches",
            "Reverse Crunches": "reverse-crunches",
            "Plank Walkouts": "plank-walkouts",
            "Hanging Knee Raises": "hanging-knee-raises",
            "Hanging Leg Raises": "hanging-leg-raises",
            "Russian Twists": "russian-twists",
            "Cable Crunch / Alternativ: Band Crunch": "cable-or-band-crunch",

            "Kreuzheben": "deadlift",
            "Deadlift": "deadlift",
            "Frontkniebeuge": "front-squat",
            "Thrusters (Frontkniebeuge + Press)": "thruster",
            "Military Press": "military-press",
            "Overhead Press": "overhead-press",
            "Schulterdrücken Kurzhanteln": "dumbbell-shoulder-press",
            "Renegade Rows": "renegade-rows",
            "Rudern vorgebeugt": "bent-over-row",
            "Kurzhantel Rudern": "dumbbell-row",
            "Klimmzüge": "pull-up",
            "Klimmzüge mit Zusatzgewicht": "weighted-pull-up",
            "Dips": "dips",
            "Kettlebell Swings": "kettlebell-swings",
            "Bankdrücken": "bench-press",
            "Front Squats": "front-squat",

            // Mobility / Stretch
            "Stretching Beine": "stretch-legs",
            "Stretching Rücken": "stretch-back",
            "Stretching Brust": "stretch-chest",
            "Dehnung Brust": "stretch-chest",
            "Dehnung Schultern": "stretch-shoulders",
            "Stretching Schultern": "stretch-shoulders",
            "Stretching Trizeps": "stretch-triceps",
            "Stretching Hüfte": "stretch-hips",
            "Hamstring Stretch": "hamstring-stretch",
            "Hip Flexor Stretch": "hip-flexor-stretch",
            "Thoracic Rotation": "thoracic-rotation",
            "Calf Stretch": "calf-stretch",
            "Quad Stretch": "quad-stretch",
            "Glute Stretch": "glute-stretch",
            "Lat Stretch an Stange": "lat-stretch-bar",
            "Shoulder Opener an der Wand": "shoulder-opener-wall",
            "Lateral Hip Opener": "lateral-hip-opener",
            "Ankle Dorsiflexion Mobilisation": "ankle-dorsiflexion-mobility",
            "Forward Fold (passiv)": "forward-fold-passive",
            "Spinal Twist (liegend)": "supine-spinal-twist",
            "Spinal Waves": "spinal-waves",
            "90/90 Hip Rotation": "90-90-hip-rotation",
            "Pectoral Doorway Stretch": "doorway-pec-stretch",
            "Happy Baby": "happy-baby",
            "Child’s Pose": "childs-pose",
            "Cobra Stretch": "cobra-stretch",
            "Glute Bridge March": "glute-bridge-march",
            "Hip Bridges": "glute-bridge",

            // Mobility Basics / Nacken, Wirbelsäule
            "Cat-Cow": "cat-cow",
            "Cat-Cow (ruhig)": "cat-cow",
            "Katzenbuckel/Pferderücken": "cat-cow",
            "Neck Rolls": "neck-rolls",
            "Leichte Nacken- & Schulterkreise": "neck-shoulder-rolls",

            // Mindfulness (optional eher Icons/Infobilder)
            "Atemfokus (4-4)": "breath-focus-4-4",
            "Box Breathing (4-4-4-4)": "box-breathing-4-4-4-4",
            "Langer Ausatmen (1:2)": "long-exhale-1-2",
            "Body Scan (kurz)": "body-scan",
            "Geführte Visualisierung": "guided-visualization",
            "Loving-Kindness (Metta)": "loving-kindness",
            "Offene Achtsamkeit (Gedanken beobachten)": "open-monitoring",
            "Dankbarkeitsreflexion": "gratitude-reflection",
            "Stille Sitzhaltung": "quiet-seated",
            "Journaling: 3 Zeilen": "journaling-3-lines",
            "World’s Greatest Stretch": "worlds-greatest-stretch",
            "World’s Greatest Stretch (dynamisch)": "worlds-greatest-stretch-dynamic",
            "Arm Circles groß": "arm-circles-large"
        ]
    }
}
