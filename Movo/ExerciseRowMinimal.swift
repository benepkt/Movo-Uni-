//  HowToViews.swift — FINAL (Auto-L10n + Live Language Sync)
//  Enthält nur die UI: LottieBlockView, SectionCard, HowToSheet.

import SwiftUI
import DotLottie
import Foundation

// MARK: - Localization helpers
fileprivate func L(_ keyOrText: String, _ app: AppSettings) -> String {
    app.localized(keyOrText)
}

fileprivate func Lsmart(_ token: String, _ app: AppSettings) -> String {
    let comps = token.components(separatedBy: "::")
    let key = comps.first ?? token
    let args = Array(comps.dropFirst())
    let translated = app.localized(key)
    return (translated != key) ? String(format: translated, arguments: args) : token
}

// MARK: - Quelle (lokal oder Web)
enum LottieSource: Hashable {
    case local(name: String, bundle: Bundle = .main)
    case web(url: String)
}

// MARK: - Content-Typen
enum HowToContent: Identifiable, Hashable {
    case section(id: UUID = UUID(), title: String, bullets: [String])
    case lottie(id: UUID = UUID(), source: LottieSource, fill: Bool = false, aspect: CGFloat = 16/9)

    var id: UUID {
        switch self {
        case .section(let id, _, _): return id
        case .lottie(let id, _, _, _): return id
        }
    }
}

// Kurzschreibweise
extension HowToContent {
    static func sec(_ title: String, _ bullets: [String]) -> HowToContent { .section(title: title, bullets: bullets) }
    static func breathing(_ bullets: [String])   -> HowToContent { .sec("Atmung", bullets) }
    static func mistakes(_ bullets: [String])    -> HowToContent { .sec("Häufige Fehler", bullets) }
    static func progressions(_ bullets: [String])-> HowToContent { .sec("Skalierung/Varianten", bullets) }
    static func cues(_ bullets: [String])        -> HowToContent { .sec("Coaching Cues", bullets) }
}

// MARK: - Lottie-Card
struct LottieBlockView: View {
    let source: LottieSource
    let fill: Bool
    let aspect: CGFloat

    @EnvironmentObject private var appSettings: AppSettings

    @ViewBuilder
    private func dotLottieView() -> some View {
        switch source {
        case .local(let name, let bundle):
            if bundle.path(forResource: name, ofType: "lottie") != nil
                || bundle.path(forResource: name, ofType: "json") != nil {
                DotLottieAnimation(
                    fileName: name,
                    bundle: bundle,
                    config: .init(autoplay: true, loop: true, backgroundColor: .clear)
                ).view()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2.weight(.semibold))
                    Text(String(format: L("howto.lottie.notFound.body", appSettings), name))
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            }

        case .web(let url):
            DotLottieAnimation(
                webURL: url,
                config: .init(autoplay: true, loop: true, backgroundColor: .clear)
            ).view()
        }
    }

    var body: some View {
        dotLottieView()
            .aspectRatio(aspect, contentMode: fill ? .fill : .fit)
            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 320)
            .clipped()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.07), radius: 12, y: 6)
            .padding(.horizontal)
    }
}

// MARK: - SectionCard
struct SectionCard: View {
    let title: String
    let bullets: [String]
    let sfSymbol: String
    let exerciseName: String?    // für Auto-Keys

    @EnvironmentObject private var appSettings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                let sectionKey = AutoL10n.keyForSectionTitle(title)
                Text(appSettings.localized(sectionKey) != sectionKey ? appSettings.localized(sectionKey) : L(title, appSettings))
                    .font(.headline)
            } icon: {
                Image(systemName: sfSymbol).imageScale(.medium)
            }
            .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(bullets.enumerated()), id: \.offset) { idx, b in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.tertiary)
                        bulletText(b, index: idx)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        }
        .padding(.horizontal)
    }
}

    private extension SectionCard {
        func bulletText(_ raw: String, index: Int) -> some View {
            let resolved: String
            if let ex = exerciseName {
                // 1) Probiere alle Kandidaten-Keys (EN & DE Slugs)
                let candidates = AutoL10n.bulletKeyCandidates(exerciseName: ex, sectionTitle: title, index: index + 1)
                if let hit = candidates.first(where: { appSettings.localized($0) != $0 }) {
                    resolved = appSettings.localized(hit)
                } else {
                    // 2) Fallback: „schlaue“ Token-Übersetzung oder Rohtext
                    resolved = Lsmart(raw, appSettings)
                }
            } else {
                resolved = Lsmart(raw, appSettings)
            }
            return Text(resolved)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }



// MARK: - HowToSheet
struct HowToSheet: View {
    let title: String
    let blocks: [HowToContent]

    @EnvironmentObject private var appSettings: AppSettings

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 6) {
                    let titleKey = AutoL10n.keyForTitle(title)
                    Text(appSettings.localized(titleKey) != titleKey ? appSettings.localized(titleKey) : L(title, appSettings))
                        .font(.largeTitle.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(L("howto.header.subtitle", appSettings))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)

                // Inhalt
                ForEach(blocks) { block in
                    switch block {
                    case .lottie(_, let source, let fill, let aspect):
                        LottieBlockView(source: source, fill: fill, aspect: aspect)

                    case .section(_, let stitle, let bullets):
                        SectionCard(
                            title: stitle,
                            bullets: bullets,
                            sfSymbol: icon(for: stitle),
                            exerciseName: title
                        )
                    }
                }
                Spacer(minLength: 12)
            }
            .padding(.top, 20)
        }
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .id(appSettings.language) // Live Language Refresh
    }

    private func icon(for title: String) -> String {
        switch title.lowercased() {
        case "setup": return "figure.strengthtraining.traditional"
        case "ausführung", "execution": return "list.bullet"
        case "atmung", "breathing": return "wind"
        case "häufige fehler", "common mistakes": return "exclamationmark.triangle"
        case "skalierung/varianten", "progression", "regression": return "slider.horizontal.3"
        case "cues", "coaching cues": return "dot.radiowaves.left.and.right"
        case "tempo": return "metronome.fill"
        case "power": return "bolt.fill"
        case "pattern": return "square.grid.3x3.fill"
        case "hinweis", "note": return "info.circle"
        case "safety": return "shield"
        default: return "info.circle"
        }
    }
}

// Convenience-Init mit DB
extension HowToSheet {
    init(exerciseName: String) {
        let (t, b) = HowToDB.blocks(for: exerciseName)
        self.init(title: t, blocks: b)
    }
}

// MARK: - How-to Datenbank
enum HowToDB {

    // Optional: explizite Web-Quellen (selten nötig)
    private static let webOverrides: [String: String] = [:]

    // Lokale Datei-Namen (ohne .lottie/.json), wenn der Slug abweicht
    private static let localOverrides: [String: String] = [:]

    // Öffentliche API
    static func hasEntry(for name: String) -> Bool { map[key(name)] != nil }

    static func blocks(for name: String) -> (String, [HowToContent]) {
        let resolved = key(name)
        let base = map[resolved] ?? generic
        let enriched = enrich(name: resolved, blocks: base)
        #if DEBUG
        let added = enriched.count - base.count
        print("[HowToDB] \(resolved): \(added > 0 ? "+\(added) Sektion(en) ergänzt" : "keine Ergänzung")")
        #endif
        return (resolved, enriched)
    }

    // MARK: Normalisierung & Alias
    private static func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "'", with: "’")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .lowercased()
    }

    private static func key(_ raw: String) -> String {
        let a = alias(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        return a.isEmpty ? raw : a
    }

    private static func alias(_ name: String) -> String {
        let n = normalize(name)
        switch n {
        // Planks & Taps
        case "plank (fortgeschritten)": return "Plank (fortgeschritten)"
        case "plank mit schulter-taps", "plank mit schulter taps": return "Plank mit Schulter-Taps"
        case "plank mit beinheben": return "Plank mit Beinheben"

        // Push-ups
        case "pike push-ups", "pike pushups": return "Pike Push-ups"
        case "enge liegestütze (trizeps)": return "Enge Liegestütze (Trizeps)"
        case "liegestütze (tempo 3-1-1)": return "Liegestütze (Tempo 3-1-1)"
        case "liegestütze mit klatschen": return "Liegestütze mit Klatschen"

        // Squats & Lunges
        case "jump squats": return "Jump Squats"
        case "bulgarian split squats (ohne erhöhung)": return "Bulgarian Split Squats (ohne Erhöhung)"
        case "side lunges": return "Side Lunges"
        case "ausfallschritte": return "Ausfallschritte"
        case "kniebeugen": return "Kniebeugen"

        // Hinge/Good Mornings
        case "hip hinge / good mornings": return "Hip Hinge / Good Mornings"
        case "good mornings (langsam)": return "Good Mornings (langsam)"

        // Core
        case "hollow hold": return "Hollow Hold"
        case "hollow rock (leicht)": return "Hollow Rock (leicht)"
        case "reverse crunches": return "Reverse Crunches"
        case "bicycle crunches": return "Bicycle Crunches"
        case "toe touches": return "Toe Touches"
        case "plank walkouts": return "Plank Walkouts"
        case "side plank": return "Side Plank"
        case "side plank mit hüftheben": return "Side Plank mit Hüftheben"
        case "dead bug", "deadbug", "dead-bug": return "Dead Bug"
        case "hip bridges": return "Hip Bridges"
        case "glute bridge march": return "Glute Bridge March"
        case "bird dog": return "Bird Dog"
        case "crunches": return "Crunches"

        // Rücken/Schultern
        case "superman pulls": return "Superman Pulls"
        case "superman hold": return "Superman Hold"
        case "prone w-raises": return "Prone W-Raises"
        case "reverse snow angels": return "Reverse Snow Angels"
        case "arm circles", "arm circles rückwärts", "arm circles groß": return name
        case "arm swings": return "Arm Swings"
        case "hip opener": return "Hip Opener"
        case "torso twists": return "Torso Twists"
        case "neck rolls", "leichte nacken- & schulterkreise": return "Leichte Nacken- & Schulterkreise"

        // Cardio
        case "jumping jacks": return "Jumping Jacks"
        case "high knees": return "High Knees"
        case "butt kicks": return "Butt Kicks"
        case "mountain climbers": return "Mountain Climbers"
        case "burpees (leicht)": return "Burpees (leicht)"
        case "burpees": return "Burpees"

        // Mobility/Stretch
        case "cat-cow", "cat-cow (ruhig)": return "Cat-Cow"
        case "child’s pose", "child's pose": return "Child’s Pose"
        case "deep breathing": return "Deep Breathing"
        case "hamstring stretch": return "Hamstring Stretch"
        case "hip flexor stretch": return "Hip Flexor Stretch"
        case "thoracic rotation": return "Thoracic Rotation"
        case "world’s greatest stretch", "world's greatest stretch", "world’s greatest stretch (dynamisch)": return "World’s Greatest Stretch (dynamisch)"
        case "glute stretch": return "Glute Stretch"
        case "shoulder opener an der wand": return "Shoulder Opener an der Wand"
        case "ankle dorsiflexion mobilisation": return "Ankle Dorsiflexion Mobilisation"
        case "half standing forward fold": return "Half Standing Forward Fold"
        case "spinal waves": return "Spinal Waves"
        case "90/90 hip rotation": return "90/90 Hip Rotation"
        case "pectoral doorway stretch", "doorway stretch": return "Pectoral Doorway Stretch"
        case "lunging straight leg calf stretching": return "Lunging Straight Leg Calf Stretching"
        case "box breathing": return "Box Breathing"
        case "arm circles groß": return "Arm Circles groß"
        case "lateral hip opener": return "Lateral Hip Opener"
        case "lat stretch an stange": return "Lat Stretch an Stange"
        case "quad stretch": return "Quad Stretch"
        case "happy baby": return "Happy Baby"
        case "spinal twist (liegend)": return "Spinal Twist (liegend)"
        case "dehnung brust": return "Pectoral Doorway Stretch"
        case "stretching rücken": return "Cat-Cow"
        case "stretching hüfte": return "Hip Flexor Stretch"
        case "stretching beine": return "Hamstring Stretch"
        case "stretching schultern": return "Shoulder Opener an der Wand"
        case "stretching bauch": return "Cobra Stretch"

        // Meditation
        case "atemfokus (4-4)": return "Atemfokus (4-4)"
        case "body scan (kurz)": return "Body Scan (kurz)"
        case "dankbarkeitsreflexion": return "Dankbarkeitsreflexion"
        case "offene achtsamkeit (gedanken beobachten)": return "Offene Achtsamkeit (Gedanken beobachten)"
        case "langer ausatmen (1:2)": return "Langer Ausatmen (1:2)"
        case "geführte visualisierung": return "Geführte Visualisierung"
        case "loving-kindness (metta)": return "Loving-Kindness (Metta)"
        case "journaling: 3 zeilen": return "Journaling: 3 Zeilen"
        case "lockere hüftkreise": return "Lockere Hüftkreise"
        case "atem zählen (1–10)": return "Atem zählen (1–10)"
        case "stille sitzhaltung": return "Stille Sitzhaltung"

        default:
            return name
        }
    }

    // MARK: Slug/Dateinamen-Helfer
    private static func slug(_ s: String) -> String {
        func translit(_ x: String) -> String {
            var t = x
            t = t.replacingOccurrences(of: "ä", with: "ae")
                .replacingOccurrences(of: "ö", with: "oe")
                .replacingOccurrences(of: "ü", with: "ue")
                .replacingOccurrences(of: "ß", with: "ss")
            t = t.replacingOccurrences(of: "Ä", with: "Ae")
                .replacingOccurrences(of: "Ö", with: "Oe")
                .replacingOccurrences(of: "Ü", with: "Ue")
            return t
        }
        let base = translit(s)
            .lowercased()
            .replacingOccurrences(of: "&", with: " und ")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        return base.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: "_")
            .replacingOccurrences(of: "__", with: "_")
    }

    // Quelle bestimmen: erst lokal, dann (optional) Web
    private static func lottieSource(for name: String) -> LottieSource? {
        if let local = localOverrides[name] { return .local(name: local) }
        if let web = webOverrides[name]   { return .web(url: web) }
        let auto = slug(name)
        if Bundle.main.url(forResource: auto, withExtension: "lottie") != nil
            || Bundle.main.url(forResource: auto, withExtension: "json") != nil {
            return .local(name: auto)
        }
        return nil
    }

    // Helper für Einträge
    private static func lot(_ name: String, aspect: CGFloat = 16/9, fill: Bool = false) -> HowToContent {
        if let src = lottieSource(for: name) {
            return .lottie(source: src, fill: fill, aspect: aspect)
        } else {
            // Voll lokalisierbarer Hinweis via "key::arg" Notation
            return .section(
                title: "howto.note.title",
                bullets: [
                    String(format: "howto.note.noSource::%@", name),
                    String(format: "howto.note.addFile::%@::%@", slug(name), slug(name))
                ]
            )
        }
    }
    private static func lotFill(_ name: String, aspect: CGFloat = 16/9) -> HowToContent {
        lot(name, aspect: aspect, fill: true)
    }

    // MARK: generischer Fallback (etwas ausführlicher)
    private static let generic: [HowToContent] = [
        .sec("Setup", [
            "howto.generic.setup.1",
            "howto.generic.setup.2"
        ]),
        .sec("Ausführung", [
            "howto.generic.execution.1",
            "howto.generic.execution.2"
        ]),
        .breathing([
            "howto.generic.breathing.1",
            "howto.generic.breathing.2"
        ]),
        .mistakes([
            "howto.generic.mistakes.1",
            "howto.generic.mistakes.2"
        ])
    ]

    // MARK: Map: Basis-Inhalte (gekürzt auf die häufigsten – erweitere nach Bedarf)
    // WICHTIG: privat halten, damit niemand enrich() umgeht.
    private static let map: [String: [HowToContent]] = [
        // ---- Warm-ups / Cardio / Basics
        "Jumping Jacks": [
            lot("Jumping Jacks"),
            .sec("Ausführung", [
                "Beine spreizen/schließen, Arme über Kopf und zurück.",
                "Leise landen, gleichmäßiger Rhythmus."
            ])
        ],
        "High Knees": [
            lot("High Knees"),
            .sec("Ausführung", [
                "Knie bis Hüfthöhe anheben, Arme aktiv mitnehmen.",
                "Oberkörper aufrecht, auf dem Ballen landen."
            ])
        ],
        "Butt Kicks": [
            lot("Butt Kicks"),
            .sec("Ausführung", [
                "Ferse Richtung Gesäß, schneller Wechsel.",
                "Körper aufrecht, Blick nach vorn."
            ])
        ],
        "Burpees (leicht)": [
            lot("Burpees (leicht)"),
            .sec("Ausführung", [
                "Squat → Hände Boden → Schritt in Plank → zurück → Streckung.",
                "Optional ohne Liegestütz."
            ])
        ],
        "Burpees": [
            lot("Burpees"),
            .sec("Ausführung", [
                "Wie leicht, aber mit Liegestütz und Sprung am Ende.",
                "Core stabil, leise landen."
            ])
        ],
        "Mountain Climbers": [
            lot("Mountain Climbers"),
            .sec("Ausführung", [
                "Im Plank Knie dynamisch Richtung Brust ziehen.",
                "Hüfte ruhig, Rücken lang."
            ])
        ],
        "Arm Circles": [
            lot("Arm Circles"),
            .sec("Ausführung", [
                "Arme seitlich, kleine zu großen Kreisen; Richtung wechseln."
            ])
        ],
        "Arm Circles rückwärts": [
            lot("Arm Circles rückwärts"),
            .sec("Ausführung", [
                "Rückwärts kreisen, Schultern tief."
            ])
        ],
        "Arm Circles groß": [
            lot("Arm Circles groß"),
            .sec("Ausführung", [
                "Große Kreise, Richtung wechseln."
            ])
        ],
        "Arm Swings": [
            lot("Arm Swings"),
            .sec("Ausführung", [
                "Arme locker vor/zurück schwingen, Brust öffnen."
            ])
        ],
        "Hip Opener": [
            lot("Hip Opener"),
            .sec("Ausführung", [
                "Knie im Stand kreisen/öffnen, Hüfte mobilisieren."
            ])
        ],
        "Shoulder Stretch": [
            lot("Shoulder Stretch"),
            .sec("Ausführung", [
                "Ein Arm gestreckt quer vor den Körper, mit der anderen Hand sanft zur Brust ziehen.",
                "Dehnung in hinterer Schulter/Trizeps spüren; 30–60s pro Seite."
            ])
        ],
        "Torso Twists": [
            lot("Torso Twists"),
            .sec("Ausführung", [
                "Rumpf rechts/links rotieren, Hüfte stabil."
            ])
        ],
        "Leichte Nacken- & Schulterkreise": [
            lot("Leichte Nacken- & Schulterkreise"),
            .sec("Ausführung", [
                "Nacken/Schultern sanft kreisen, Spannung lösen."
            ])
        ],

        // ---- Unterkörper / Hinge / Knie
        "Kniebeugen": [
            lot("Kniebeugen"),
            .sec("Setup", [
                "Füße schulterbreit, Zehen leicht außen, Brust stolz."
            ]),
            .sec("Ausführung", [
                "Hüfte nach hinten/unten, Knie folgen Zehen.",
                "Über Mittelfuß/Ferse hochdrücken."
            ])
        ],
        "Ausfallschritte": [
            lot("Ausfallschritte"),
            .sec("Ausführung", [
                "Großer Schritt, hinteres Knie Richtung Boden.",
                "Druck über vordere Ferse zurück."
            ])
        ],
        "Side Lunges": [
            lot("Side Lunges"),
            .sec("Ausführung", [
                "Seitlich absetzen, Hüfte nach hinten.",
                "Standbein gestreckt halten, Brust offen."
            ])
        ],
        "Bulgarian Split Squats (ohne Erhöhung)": [
            lot("Bulgarian Split Squats (ohne Erhöhung)"),
            .sec("Ausführung", [
                "Ausfallschritt-Position, hinterer Fuß am Boden.",
                "Knie über der Zehenlinie, aufrecht bleiben."
            ])
        ],
        "Jump Squats": [
            lot("Jump Squats"),
            .sec("Ausführung", [
                "Aus Kniebeuge explosiv abspringen.",
                "Leise landen, Spannung halten."
            ])
        ],
        "Hip Hinge / Good Mornings": [
            lot("Hip Hinge / Good Mornings"),
            .sec("Ausführung", [
                "Hüfte nach hinten schieben, langer Rücken.",
                "Nur so tief, wie neutral möglich."
            ])
        ],
        "Good Mornings (langsam)": [
            lot("Good Mornings (langsam)"),
            .sec("Tempo", [
                "3–4s exzentrisch, 1–2s halten, kontrolliert hoch."
            ])
        ],

        // ---- Oberkörper / Push / Rücken
        "Liegestütze": [
            lot("Liegestütze"),
            .sec("Setup", [
                "Hände unter/leicht außerhalb Schultern, Körper Linie."
            ]),
            .sec("Ausführung", [
                "Ellenbogen ~45°, Brust Richtung Boden, ruhig strecken."
            ])
        ],
        "Enge Liegestütze (Trizeps)": [
            lot("Enge Liegestütze (Trizeps)"),
            .sec("Ausführung", [
                "Ellenbogen nah am Körper, Trizeps-Fokus."
            ])
        ],
        "Liegestütze (Tempo 3-1-1)": [
            lot("Liegestütze (Tempo 3-1-1)"),
            .sec("Tempo", [
                "3s runter – 1s halten – 1s hoch."
            ])
        ],
        "Liegestütze mit Klatschen": [
            lot("Liegestütze mit Klatschen"),
            .sec("Power", [
                "Explosiv drücken, weiche Landung, Core stabil."
            ])
        ],
        "Pike Push-ups": [
            lot("Pike Push-ups"),
            .sec("Ausführung", [
                "Hüfte hoch (V-Position), Ellenbogen beugen/strecken.",
                "Schultern arbeiten lassen, Nacken lang."
            ])
        ],
        "Plank mit Schulter-Taps": [
            lot("Plank mit Schulter-Taps"),
            .sec("Ausführung", [
                "Abwechselnd Schulter antippen, Becken ruhig.",
                "Füße breiter für Stabilität."
            ])
        ],
        "Superman Pulls": [
            lot("Superman Pulls"),
            .sec("Ausführung", [
                "Bauchlage, Arme/Brust leicht anheben, Ellbogen zur Hüfte ziehen."
            ])
        ],
        "Superman Hold": [
            lot("Superman Hold"),
            .sec("Ausführung", [
                "Bauchlage, Arme/Beine anheben und halten.",
                "Blick zum Boden, Nacken lang."
            ])
        ],
        "Prone W-Raises": [
            lot("Prone W-Raises"),
            .sec("Ausführung", [
                "Arme in W-Form, Schulterblätter nach hinten/unten."
            ])
        ],
        "Reverse Snow Angels": [
            lot("Reverse Snow Angels"),
            .sec("Ausführung", [
                "Arme knapp über Boden in weitem Bogen führen."
            ])
        ],

        // ---- Core
        "Plank": [
            lot("Plank"),
            .sec("Setup", [
                "Unterarme unter Schultern, Körper Linie, Core an."
            ])
        ],
        "Plank (fortgeschritten)": [
            lot("Plank (fortgeschritten)"),
            .sec("Progression", [
                "Längere Haltezeit / enger Stand / Gewichtsverlagerung."
            ])
        ],
        "Plank mit Beinheben": [
            lot("Plank mit Beinheben"),
            .sec("Ausführung", [
                "Im Plank abwechselnd Bein anheben, Becken ruhig."
            ])
        ],
        "Bicycle Crunches": [
            lot("Bicycle Crunches"),
            .sec("Ausführung", [
                "Rotation aus Oberkörper, nicht am Kopf ziehen.",
                "LWS am Boden halten."
            ])
        ],
        "Reverse Crunches": [
            lot("Reverse Crunches"),
            .sec("Ausführung", [
                "Knie zur Brust, Becken kippen/rollen, langsam ab."
            ])
        ],
        "Crunches": [
            lot("Crunches"),
            .sec("Ausführung", [
                "Brustbein zu den Rippen, LWS bleibt am Boden."
            ])
        ],
        "Side Plank": [
            lotFill("Side Plank"),
            .sec("Cues", [
                "Hüfte hoch, Linie halten, kein Einsacken."
            ])
        ],
        "Side Plank mit Hüftheben": [
            lot("Side Plank mit Hüftheben"),
            .sec("Ausführung", [
                "Seitstütz, Hüfte rhythmisch heben/senken."
            ])
        ],
        "Plank Walkouts": [
            lot("Plank Walkouts"),
            .sec("Ausführung", [
                "Aus dem Stand mit Händen vorlaufen in Plank, zurück."
            ])
        ],
        "Hollow Hold": [
            lot("Hollow Hold"),
            .sec("Setup", [
                "LWS in den Boden, Rippen runter, Arme/Beine gestreckt."
            ])
        ],
        "Hollow Rock (leicht)": [
            lot("Hollow Rock (leicht)"),
            .sec("Ausführung", [
                "Kleine Wippbewegung, Spannung halten."
            ])
        ],
        "Toe Touches": [
            lot("Toe Touches"),
            .sec("Ausführung", [
                "Finger zu den Zehen heben, Bauch aktiv."
            ])
        ],
        "Russian Twists": [
            lot("Russian Twists"),
            .sec("Ausführung", [
                "Seitlich rotieren & Boden antippen, Rücken lang."
            ])
        ],
        "Dead Bug (aktivieren)": [
            lot("Dead Bug (aktivieren)"),
            .sec("Ausführung", [
                "Tabletop, gegengleich Arm/Bein strecken, LWS bleibt am Boden."
            ])
        ],
        "Hip Bridges": [
            lot("Hip Bridges"),
            .sec("Ausführung", [
                "Fersen in Boden, Hüfte hoch, oben 1–2s halten."
            ])
        ],
        "Glute Bridge March": [
            lot("Glute Bridge March"),
            .sec("Ausführung", [
                "Aus Brücke abwechselnd Knie anheben, Hüfte stabil."
            ])
        ],
        "Bird Dog": [
            lot("Bird Dog"),
            .sec("Ausführung", [
                "Vierfüßler, gegengleich Arm/Bein strecken, Becken ruhig."
            ])
        ],

        // ---- Mobility / Stretch
        "Cat-Cow": [
            lot("Cat-Cow"),
            .sec("Ausführung", [
                "Wirbelsäule rund/hohl bewegen, ruhig atmen."
            ])
        ],
        "Neck Rolls": [
            lot("Neck Rolls"),
            .sec("Hinweis", [
                "Sehr sanft, keine Endrange in Schmerz."
            ])
        ],
        "Hamstring Stretch": [
            lot("Hamstring Stretch"),
            .sec("Ausführung", [
                "Rückseite Oberschenkel dehnen (Stand/Liege)."
            ])
        ],
        "Hip Flexor Stretch": [
            lot("Hip Flexor Stretch"),
            .sec("Ausführung", [
                "Halbknieend, Becken nach hinten kippen, Hüfte vor."
            ])
        ],
        "Thoracic Rotation": [
            lot("Thoracic Rotation"),
            .sec("Ausführung", [
                "Brustwirbelsäule mobil drehen, Hüfte ruhig."
            ])
        ],
        "Child’s Pose": [
            lot("Child’s Pose"),
            .sec("Hinweis", [
                "Gesäß zu Fersen, Arme lang, Schultern entspannen."
            ])
        ],
        "Deep Breathing": [
            lot("Deep Breathing"),
            .sec("Hinweis", [
                "Nasenatmung, Rippen 360° expandieren, lange Ausatmung."
            ])
        ],
        "World’s Greatest Stretch (dynamisch)": [
            lot("World’s Greatest Stretch (dynamisch)"),
            .sec("Ausführung", [
                "Große Sequenz: Hüfte, BWS, hintere Kette mobilisieren."
            ])
        ],
        "Glute Stretch": [
            lot("Glute Stretch"),
            .sec("Ausführung", [
                "Gesäßmuskulatur dehnen (Fig4/Sitz)."
            ])
        ],
        "Shoulder Opener an der Wand": [
            lot("Shoulder Opener an der Wand"),
            .sec("Ausführung", [
                "Unterarm an Wand, Brust sanft öffnen."
            ])
        ],
        "Ankle Dorsiflexion Mobilisation": [
            lot("Ankle Dorsiflexion Mobilisation"),
            .sec("Ausführung", [
                "Knie über Zehen schieben, Ferse unten (Sprunggelenk)."
            ])
        ],
        "Half Standing Forward Fold": [
            lot("Half Standing Forward Fold"),
            .sec("Hinweis", [
                "Locker hängen lassen, keine Schmerzen provozieren."
            ])
        ],
        "Spinal Waves": [
            lot("Spinal Waves"),
            .sec("Ausführung", [
                "Welle durch die Wirbelsäule, segmentiert."
            ])
        ],
        "90/90 Hip Rotation": [
            lot("90/90 Hip Rotation"),
            .sec("Ausführung", [
                "90/90 Sitz, Hüfte rotieren, Seitenwechsel."
            ])
        ],
        "Pectoral Doorway Stretch": [
            lot("Pectoral Doorway Stretch"),
            .sec("Ausführung", [
                "Unterarm/Türrahmen, Brust öffnen, Seiten wechseln."
            ])
        ],
        "Lunging Straight Leg Calf Stretching": [
            lot("Lunging Straight Leg Calf Stretching"),
            .sec("Ausführung", [
                "Wade an Wand/Step dehnen, Ferse unten."
            ])
        ],
        "Box Breathing": [
            lot("Box Breathing"),
            .sec("Pattern", [
                "4-4-4-4 (einhalten): einhalten–ausatmen–halten."
            ])
        ],
        "Lateral Hip Opener": [
            lot("Lateral Hip Opener"),
            .sec("Ausführung", [
                "Seitliche Hüftöffnung, sanft in die Dehnung."
            ])
        ],
        "Lat Stretch an Stange": [
            lot("Lat Stretch an Stange"),
            .sec("Ausführung", [
                "Seitlich greifen/lehnen, Lat lang machen."
            ])
        ],
        "Quad Stretch": [
            lot("Quad Stretch"),
            .sec("Ausführung", [
                "Fuß fassen, Knie nebeneinander, Hüfte strecken."
            ])
        ],
        "Happy Baby": [
            lot("Happy Baby"),
            .sec("Hinweis", [
                "Knie zur Achsel, Rücken am Boden, ruhig atmen."
            ])
        ],
        "Spinal Twist (liegend)": [
            lot("Spinal Twist (liegend)"),
            .sec("Hinweis", [
                "Beide Schultern möglichst am Boden lassen."
            ])
        ],
        "Cobra Stretch": [
            lot("Cobra Stretch"),
            .sec("Hinweis", [
                "Ellbogen weich, nur schmerzfrei strecken."
            ])
        ],

        // ---- Alias-Varianten als eigene Map-Einträge
        "Stretching Brust": [
            lot("Pectoral Doorway Stretch"),
            .sec("Ausführung", [
                "Unterarm/Türrahmen, Brust öffnen, Seiten wechseln."
            ])
        ],
        "world geratest stretch": [
            lot("World’s Greatest Stretch (dynamisch)"),
            .sec("Ausführung", [
                "Große Sequenz: Hüfte, BWS, hintere Kette mobilisieren."
            ])
        ],
        "stretching schultern": [
            lot("Shoulder Opener an der Wand"),
            .sec("Ausführung", [
                "Unterarm an Wand, Brust sanft öffnen."
            ])
        ],
        "stretching rücken": [
            lot("Cat-Cow"),
            .sec("Ausführung", [
                "Wirbelsäule rund/hohl bewegen, ruhig atmen."
            ])
        ],
        "Schulter taps im plank": [
            lot("Plank mit Schulter-Taps"),
            .sec("Ausführung", [
                "Abwechselnd Schulter antippen, Becken ruhig.",
                "Füße breiter für Stabilität."
            ])
        ],
        "Dehnung brust": [
            lot("Pectoral Doorway Stretch"),
            .sec("Ausführung", [
                "Unterarm/Türrahmen, Brust öffnen, Seiten wechseln."
            ])
        ],
        "stretching triez's": [
            lot("Trizeps Stretch"),
            .sec("Ausführung", [
                "Arm über Kopf, Ellbogen beugen, Hand Richtung Schulterblatt.",
                "Mit der anderen Hand den Ellbogen sanft nach hinten/unten führen."
            ])
        ],
        "Katzenbuckel/Pferderücken": [
            lot("Cat-Cow"),
            .sec("Ausführung", [
                "Wirbelsäule rund/hohl bewegen, ruhig atmen."
            ])
        ],
        "stretching Hüfte": [
            lot("Hip Flexor Stretch"),
            .sec("Ausführung", [
                "Halbknieend, Becken nach hinten kippen, Hüfte vor."
            ])
        ],
        "World's Greatest Stretch": [
            lot("World’s Greatest Stretch (dynamisch)"),
            .sec("Ausführung", [
                "Große Sequenz: Hüfte, BWS, hintere Kette mobilisieren."
            ])
        ],
        "stretching Bauch": [
            lot("Cobra Stretch"),
            .sec("Hinweis", [
                "Ellbogen weich, nur schmerzfrei strecken."
            ])
        ],
    ]

    // MARK: - Automatische Anreicherung für ALLE Übungen
    private static func enrich(name: String, blocks: [HowToContent]) -> [HowToContent] {
        // vorhandene Titel sammeln (case-insensitive)
        let titles = Set(blocks.compactMap {
            if case let .section(_, title, _) = $0 { return title.lowercased() }
            return nil
        })
        func missing(_ key: String) -> Bool { !titles.contains(key.lowercased()) }

        let cat = category(for: name)
        var enriched = blocks

        if missing("Coaching Cues"), let cues = defaults[cat]?.cues {
            enriched.append(.cues(cues))
        }
        if missing("Atmung"), let breath = defaults[cat]?.breathing {
            enriched.append(.breathing(breath))
        }
        if missing("Häufige Fehler"), let errs = defaults[cat]?.mistakes {
            enriched.append(.mistakes(errs))
        }
        if missing("Skalierung/Varianten"), let prog = defaults[cat]?.progressions {
            enriched.append(.progressions(prog))
        }
        return enriched
    }

    private enum Category {
        case strength, core, cardio, stretch, upperBack, push, hinge, squat, lunge, breathwork
    }

    private static func category(for name: String) -> Category {
        let n = normalize(name)
        if ["box breathing","deep breathing","atemfokus"].contains(where: { n.contains($0) }) { return .breathwork }
        if ["plank","crunch","hollow","dead bug","toe touches","russian twist","side plank"].contains(where: { n.contains($0) }) { return .core }
        if ["jumping jacks","high knees","butt kicks","burpees","mountain climbers"].contains(where: { n.contains($0) }) { return .cardio }
        if ["hamstring","hip flexor","cat-cow","child’s pose","child's pose","glute stretch","doorway","quad stretch","spinal","lat stretch","ankle dorsiflexion","90/90","thoracic","lateral hip opener","happy baby","cobra","forward fold"].contains(where: { n.contains($0) }) { return .stretch }
        if ["reverse snow angels","prone w-raises","superman"].contains(where: { n.contains($0) }) { return .upperBack }
        if ["liegestütze","push-ups","pike"].contains(where: { n.contains($0) }) { return .push }
        if ["good mornings","hip hinge"].contains(where: { n.contains($0) }) { return .hinge }
        if ["kniebeugen","squat"].contains(where: { n.contains($0) }) { return .squat }
        if ["ausfallschritte","lunge","split squat","side lunges"].contains(where: { n.contains($0) }) { return .lunge }
        return .strength
    }

    // Defaults pro Kategorie (werden nur ergänzt, wenn nicht vorhanden)
    private struct Defaults {
        let breathing: [String]
        let mistakes: [String]
        let progressions: [String]
        let cues: [String]
    }

    // ===============================
    // HowToDB.Defaults (final)
    // ===============================
    private static let defaults: [Category: Defaults] = [
        .cardio: .init(
            breathing: [
                "howto.defaults.cardio.breathing.1",
                "howto.defaults.cardio.breathing.2"
            ],
            mistakes: [
                "howto.defaults.cardio.mistakes.1",
                "howto.defaults.cardio.mistakes.2"
            ],
            progressions: [
                "howto.defaults.cardio.progressions.1",
                "howto.defaults.cardio.progressions.2"
            ],
            cues: [
                "howto.defaults.cardio.cues.1",
                "howto.defaults.cardio.cues.2"
            ]
        ),
        .core: .init(
            breathing: [
                "howto.defaults.core.breathing.1",
                "howto.defaults.core.breathing.2"
            ],
            mistakes: [
                "howto.defaults.core.mistakes.1",
                "howto.defaults.core.mistakes.2"
            ],
            progressions: [
                "howto.defaults.core.progressions.1",
                "howto.defaults.core.progressions.2"
            ],
            cues: [
                "howto.defaults.core.cues.1",
                "howto.defaults.core.cues.2"
            ]
        ),
        .stretch: .init(
            breathing: [
                "howto.defaults.stretch.breathing.1",
                "howto.defaults.stretch.breathing.2"
            ],
            mistakes: [
                "howto.defaults.stretch.mistakes.1",
                "howto.defaults.stretch.mistakes.2"
            ],
            progressions: [
                "howto.defaults.stretch.progressions.1",
                "howto.defaults.stretch.progressions.2"
            ],
            cues: [
                "howto.defaults.stretch.cues.1",
                "howto.defaults.stretch.cues.2"
            ]
        ),
        .upperBack: .init(
            breathing: [
                "howto.defaults.upperBack.breathing.1",
                "howto.defaults.upperBack.breathing.2"
            ],
            mistakes: [
                "howto.defaults.upperBack.mistakes.1",
                "howto.defaults.upperBack.mistakes.2"
            ],
            progressions: [
                "howto.defaults.upperBack.progressions.1",
                "howto.defaults.upperBack.progressions.2"
            ],
            cues: [
                "howto.defaults.upperBack.cues.1",
                "howto.defaults.upperBack.cues.2"
            ]
        ),
        .push: .init(
            breathing: [
                "howto.defaults.push.breathing.1",
                "howto.defaults.push.breathing.2"
            ],
            mistakes: [
                "howto.defaults.push.mistakes.1",
                "howto.defaults.push.mistakes.2"
            ],
            progressions: [
                "howto.defaults.push.progressions.1",
                "howto.defaults.push.progressions.2"
            ],
            cues: [
                "howto.defaults.push.cues.1",
                "howto.defaults.push.cues.2"
            ]
        ),
        .hinge: .init(
            breathing: [
                "howto.defaults.hinge.breathing.1",
                "howto.defaults.hinge.breathing.2"
            ],
            mistakes: [
                "howto.defaults.hinge.mistakes.1",
                "howto.defaults.hinge.mistakes.2"
            ],
            progressions: [
                "howto.defaults.hinge.progressions.1",
                "howto.defaults.hinge.progressions.2"
            ],
            cues: [
                "howto.defaults.hinge.cues.1",
                "howto.defaults.hinge.cues.2"
            ]
        ),
        .squat: .init(
            breathing: [
                "howto.defaults.squat.breathing.1",
                "howto.defaults.squat.breathing.2"
            ],
            mistakes: [
                "howto.defaults.squat.mistakes.1",
                "howto.defaults.squat.mistakes.2"
            ],
            progressions: [
                "howto.defaults.squat.progressions.1",
                "howto.defaults.squat.progressions.2"
            ],
            cues: [
                "howto.defaults.squat.cues.1",
                "howto.defaults.squat.cues.2"
            ]
        ),
        .lunge: .init(
            breathing: [
                "howto.defaults.lunge.breathing.1",
                "howto.defaults.lunge.breathing.2"
            ],
            mistakes: [
                "howto.defaults.lunge.mistakes.1",
                "howto.defaults.lunge.mistakes.2"
            ],
            progressions: [
                "howto.defaults.lunge.progressions.1",
                "howto.defaults.lunge.progressions.2"
            ],
            cues: [
                "howto.defaults.lunge.cues.1",
                "howto.defaults.lunge.cues.2"
            ]
        ),
        .strength: .init(
            breathing: [
                "howto.defaults.strength.breathing.1",
                "howto.defaults.strength.breathing.2"
            ],
            mistakes: [
                "howto.defaults.strength.mistakes.1",
                "howto.defaults.strength.mistakes.2"
            ],
            progressions: [
                "howto.defaults.strength.progressions.1",
                "howto.defaults.strength.progressions.2"
            ],
            cues: [
                "howto.defaults.strength.cues.1",
                "howto.defaults.strength.cues.2"
            ]
        ),
        .breathwork: .init(
            breathing: [
                "howto.defaults.breathwork.breathing.1",
                "howto.defaults.breathwork.breathing.2"
            ],
            mistakes: [
                "howto.defaults.breathwork.mistakes.1",
                "howto.defaults.breathwork.mistakes.2"
            ],
            progressions: [
                "howto.defaults.breathwork.progressions.1",
                "howto.defaults.breathwork.progressions.2"
            ],
            cues: [
                "howto.defaults.breathwork.cues.1",
                "howto.defaults.breathwork.cues.2"
            ]
        )
    ]


}
// ===============================
// AutoL10n (final)
// ===============================
enum AutoL10n {

    // --- unverändert: Slugify ---
    static func slug(_ s: String) -> String {
        var t = s
        t = t.replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "Ä", with: "Ae")
            .replacingOccurrences(of: "Ö", with: "Oe")
            .replacingOccurrences(of: "Ü", with: "Ue")
            .replacingOccurrences(of: "ß", with: "ss")
        t = t.lowercased()
            .replacingOccurrences(of: "&", with: " und ")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "–", with: " ")
            .replacingOccurrences(of: "—", with: " ")
        t = t.replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "_{2,}", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return t.isEmpty ? "unnamed" : t
    }

    // Titel-Keys: wir bleiben bei deinen existierenden Section-Keys (DE-Slugs)
    static func canonicalSectionSlugForTitle(_ sectionTitle: String) -> String {
        let s = slug(sectionTitle)
        switch s {
        case "ausfuhrung", "ausfuehrung", "execution", "exec": return "ausfuehrung"
        case "atmung", "breathing":                                 return "atmung"
        case "haufige_fehler", "haeufige_fehler", "common_mistakes", "mistakes": return "haeufige_fehler"
        case "skalierung_varianten", "scaling_variations", "progression", "regression", "varianten": return "skalierung_varianten"
        case "cues", "coaching_cues", "coaching", "hinweise":        return "cues"
        case "setup", "vorbereitung":                                return "setup"
        case "tempo":                                                return "tempo"
        case "power":                                                return "power"
        case "pattern":                                              return "pattern"
        case "hinweis", "note":                                      return "note"
        case "safety", "sicherheit":                                 return "safety"
        default: return s
        }
    }

    // Bullet-Keys: probiere EN-Slug zuerst, dann DE-Slug, dann Roh-Slug
    static func bulletSlugCandidates(_ sectionTitle: String) -> [String] {
        let s = slug(sectionTitle)
        switch s {
        case "ausfuhrung", "ausfuehrung", "execution", "exec":
            return ["execution", "ausfuehrung", s]
        case "atmung", "breathing":
            return ["breathing", "atmung", s]
        case "haufige_fehler", "haeufige_fehler", "common_mistakes", "mistakes":
            return ["common_mistakes", "haeufige_fehler", s]
        case "skalierung_varianten", "scaling_variations", "progression", "regression", "varianten":
            return ["scaling_variations", "skalierung_varianten", s]
        case "cues", "coaching_cues", "coaching", "hinweise":
            return ["coaching_cues", "cues", s]
        case "setup", "vorbereitung":
            return ["setup", s]
        case "tempo":
            return ["tempo", s]
        case "power":
            return ["power", s]
        case "pattern":
            return ["pattern", s]
        case "hinweis", "note":
            return ["note", "hinweis", s]
        case "safety", "sicherheit":
            return ["safety", "sicherheit", s]
        default:
            return [s]
        }
    }

    // Öffentlich: Section- & Bullet-Key Builder
    static func keyForTitle(_ exerciseName: String) -> String {
        "howto.title.\(slug(exerciseName))"
    }

    static func keyForSectionTitle(_ sectionTitle: String) -> String {
        "howto.section.\(canonicalSectionSlugForTitle(sectionTitle))"
    }

    // Nur „erste Wahl“ – wird in SectionCard eh durch Candidates ersetzt
    static func keyForBulletPrimary(_ exerciseName: String, sectionTitle: String, index: Int) -> String {
        let first = bulletSlugCandidates(sectionTitle).first ?? slug(sectionTitle)
        return "howto.\(slug(exerciseName)).\(first).\(index)"
    }

    // Hilfsfunktion für SectionCard: gibt alle Kandidaten (fertige Keys) zurück
    static func bulletKeyCandidates(exerciseName: String, sectionTitle: String, index: Int) -> [String] {
        bulletSlugCandidates(sectionTitle).map { slugPart in
            "howto.\(slug(exerciseName)).\(slugPart).\(index)"
        }
    }

    static func translateOrFallback(_ key: String, fallback: String, using app: AppSettings) -> String {
        let localized = app.localized(key)
        return (localized != key) ? localized : fallback
    }
}
