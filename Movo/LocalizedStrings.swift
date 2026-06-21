//
//  LanguageManager+HowToL10n.swift
//

import Foundation
import Combine

// MARK: - LanguageManager mit Bundle-Fallback (de/en)
final class LanguageManager: ObservableObject {
    @Published var currentLanguage: String = Locale.current.languageCode ?? "de" // System oder "de"

    // MARK: Öffentliche API

    /// 1) Einfacher Aufruf ohne Platzhalter
    func localizedString(for key: String) -> String {
        // 1) interne Dicts (de/en) – Abwärtskompatibilität
        let dict = currentLanguage.starts(with: "de") ? LocalizedStrings.de : LocalizedStrings.en
        if let v = dict[key] { return v }
        if let v = LocalizedStrings.en[key] { return v } // Fallback en-Dict

        // 2) Bundle-Lookup in Localizable.strings für gewünschte Sprache (de/en)
        if let bundle = bundleForCurrentLanguage() {
            let localized = bundle.localizedString(forKey: key, value: key, table: nil)
            if localized != key { return localized }
        }

        // 3) letzter Fallback: Key
        return key
    }

    /// 2) Aufruf mit Platzhaltern (z. B. %d / %@)
    func localizedString(for key: String, _ args: CVarArg...) -> String {
        let format = localizedString(for: key)
        guard !args.isEmpty else { return format }
        return String(format: format, arguments: args)
    }

    // MARK: - Helpers

    private func bundleForCurrentLanguage() -> Bundle? {
        // normalisiere Sprachkürzel: "de" oder "en" (du kannst hier weitere Sprachen ergänzen)
        let code = currentLanguage.starts(with: "de") ? "de" : "en"
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }
}

// MARK: - L10n Helper
struct L10n {
    static func t(_ key: String, _ manager: LanguageManager) -> String {
        manager.localizedString(for: key)
    }

    /// Erlaubt Kurzform "key::arg1::arg2" ODER direkten Text als Key:
    /// - Wenn `raw` das Schema "key::..." hat → als Key interpretieren und formatieren
    /// - Sonst: versuche `raw` als Key; wenn nicht vorhanden → gib `raw` zurück
    static func tSmart(_ raw: String, _ manager: LanguageManager) -> String {
        let parts = raw.split(separator: "::").map(String.init)
        guard let first = parts.first else { return raw }
        let fmt = manager.localizedString(for: first)
        if parts.count > 1 {
            let args: [CVarArg] = parts.dropFirst().map { $0 as NSString }
            return String(format: fmt, arguments: args)
        } else {
            // Falls `first` unbekannter Key ist, kommt `first` (gleich `raw`) zurück → genau das Verhalten,
            // das wir für deutsche, frei geschriebene Bullets wollen.
            return fmt
        }
    }
}

struct LocalizedStrings {
    static let de: [String: String] = [
        "tab.feed": "Plan", // ADDED
        "tab.body": "Körper", // NEW
        "body.muscle_map.title": "Muskel-Level", // ADDED
        "body.title": "Körperstatus",
        "body.metrics.restingHR": "Ruhepuls",
        "body.metrics.vo2": "VO₂ Max",
        "body.metrics.respRate": "Atemfrequenz",
        "body.metrics.spo2": "Blutsauerstoff",
        "body.metrics.wristTemp": "Handgelenkstemp.",
        "body.recovery.title": "Recovery Zone",
        "body.recovery.muscleStatus": "Muskelstatus",
        "body.status.recovered": "Erholt",
        "body.status.recovering": "Erholung",
        "body.status.hours": "h",
        
        // BodyView Metrics
        "body.metric.weight": "Gewicht",
        "body.metric.bmi": "BMI",
        "body.metric.hr": "Ruhepuls",
        "body.metric.fat": "Körperfett",
        "body.metric.leanMass": "Magermasse",
        "body.metric.vo2": "VO₂ Max",
        "body.metric.resp": "Atemfrequenz",
        "body.metric.spo2": "Blutsauerstoff",
        "body.metric.temp": "Handgelenkstemp.",
        "body.metric.fitness": "Fitnessniveau",
        
        // BodyView Score
        "body.score.excellent": "Hervorragend",
        "body.score.strong": "Stark",
        "body.score.good": "Gut",
        "body.score.recovery_needed": "Erholung nötig",
        "body.score.optimal": "Optimal",
        "body.score.okay": "Okay",
        "body.score.low": "Niedrig",
        
        // BodyView Sleep
        "body.sleep.title": "SCHLAF",
        "body.sleep.tip": "Konsistenz ist der Schlüssel. Versuche, jeden Tag zur gleichen Zeit ins Bett zu gehen.",
        
        // BodyView Load
        "body.load.high": "Hoch",
        "body.load.medium": "Mittel",
        "body.load.low": "Niedrig",
        
        // BodyView Status
        "body.status.underweight": "Untergewicht",
        "body.status.normal": "Normalgewicht",
        "body.status.overweight": "Übergewicht",
        "body.status.obese": "Adipositas",
        
        // Common
        "common.today": "Heute",
        "common.yesterday": "Gestern",
        "common.last": "Zuletzt",
        "common.first_measurement": "Erste Messung",
        
        // BodyView Recovery
        "body.recovery.info": "Tippe auf die Liste für Details",
        "body.recovery.noData": "Keine Trainingsdaten gefunden.",
        "body.recovery.status.recovering": "Erholung",
        "body.recovery.status.good": "Regeneration",
        "body.recovery.status.ready": "Bereit",
        "body.recovery.status.peak": "Topform",
        "body.recovery.status.idle": "Trainieren",
        
        "body.recovery.progress": "Erholung",
        "body.recovery.lastTraining": "Letztes Training",
        "body.recovery.statusLabel": "Status",
        
        
        "body.recovery.infoTitle": "Information",
        
        "body.recovery.desc.recovering": "Dieser Muskel wurde kürzlich stark beansprucht. Gib ihm Zeit zur Erholung, damit er wachsen kann.",
        "body.recovery.desc.good": "Die Erholung ist im Gange. Leichtes Training ist möglich, aber intensive Belastung sollte vermieden werden.",
        "body.recovery.desc.ready": "Der Muskel ist fast vollständig erholt. Du kannst ihn wieder trainieren, aber achte auf dein Gefühl.",
        "body.recovery.desc.peak": "Idealer Zeitpunkt! Der Muskel ist vollständig erholt und bereit für maximale Leistung.",
        "body.recovery.desc.idle": "Es ist schon länger her. Ein Trainingsreiz wäre jetzt optimal, um Kraftverluste zu vermeiden.",
        
        // Muscles
        "muscle.chest": "Brust",
        "muscle.back": "Rücken",
        "muscle.legs": "Beine",
        "muscle.shoulders": "Schultern",
        "muscle.biceps": "Bizeps",
        "muscle.triceps": "Trizeps",
        "muscle.abs": "Bauch",
        "muscle.calves": "Waden",
        "muscle.forearms": "Unterarme",
        "muscle.traps": "Nacken",
        "muscle.unknown": "Unbekannt",
        
        "muscle.glutes": "Gesäß",
        "muscle.fullbody": "Ganzkörper",
        "muscle.cardio": "Ausdauer",
        "muscle.lowerback": "Unterer Rücken",
        "muscle.posteriorchain": "Hintere Kette",
        "muscle.grip": "Griffkraft",
        "muscle.adductors": "Adduktoren",
        "muscle.quads": "Quadrizeps",
        "muscle.hamstrings": "Oberschenkelrückseite",
        "muscle.lats": "Latissimus",
        "muscle.obliques": "Seitliche Bauchmuskeln",
        "muscle.erector_spinae": "Rückenstrecker",
        "muscle.rhomboids": "Rautenmuskel",
        "muscle.glutes_medius": "Mittlerer Gesäßmuskel",
        "muscle.brachialis": "Armbeuger",
        "muscle.heart": "Herz",
        "muscle.deltoids": "Deltamuskel",
        "muscle.core": "Rumpf",
        "muscle.hip_flexors": "Hüftbeuger",
        "muscle.rotator_cuff": "Rotatorenmanschette",
        "muscle.arms": "Arme",
        
        // Add Metric Sheet
        "addMetric.value": "Wert",
        "addMetric.date": "Datum",
        "addMetric.newEntry": "Neuer Eintrag",
        "addMetric.invalidNumber": "Bitte gültige Zahl eingeben",
        "addMetric.errorSave": "Speichern für diesen Typ nicht unterstützt.",
        "addMetric.add": "hinzufügen",
        
        // Movo Score
        "score.title": "MOVO SCORE",
        "score.breakdown": "Zusammensetzung",
        "score.recovery": "Erholung",
        "score.load": "Belastung",
        "score.sleep": "Schlaf",
        "score.activity": "Aktivität",
        "score.training": "Training",
        
        "score.detail.durationQuality": "Dauer & Qualität",
        "score.detail.stepsMovement": "Schritte & Bewegung",
        "score.detail.workouts": "Workouts",
        "score.detail.stressRegeneration": "Stress & Regeneration",
        "score.detail.baseline": "Basiswert",
        
        "score.detail.slept": "%.1fh geschlafen",
        "score.detail.steps": "%d Schritte",
        "score.detail.trainingDone": "Training absolviert",
        "score.detail.noTraining": "Kein Training",
        "score.loading": "Lade...",
        "score.enterSleep": "Schlaf eintragen",
        
        "score.detail.description": "Dein Movo Score basiert auf deinen täglichen Aktivitäten, deinem Schlaf und deiner Erholung. Versuche alle Ringe zu füllen!",
        "score.detail.navTitle": "Score Details",
        
        // BodyView Edit
        "body.edit.title": "Bearbeiten",
        "body.edit.done": "Fertig",
        "body.edit.description": "Wähle die Metriken aus, die im Dashboard angezeigt werden sollen.",
        
        // Metric Details & Info
        "body.detail.verlauf": "Verlauf",
        "body.detail.trend": "Trend",
        "body.detail.avg": "Ø 7 Tage",
        "body.detail.max": "Max",
        "body.detail.about": "Über",
        "body.detail.understood": "Verstanden",
        "body.detail.measuredAt": "Gemessen um:",
        "body.detail.noData": "Keine Daten in diesem Zeitraum",
        "body.detail.trend.stable": "Stabil",
        "body.detail.trend.up": "Steigend",
        "body.detail.trend.down": "Sinkend",
        
        "body.detail.info1": "Diese Metrik gibt Aufschluss über deine körperliche Verfassung.",
        "body.detail.info2": "Die Werte werden aus deinen HealthKit-Daten oder manuellen Eingaben gesammelt.",
        "body.detail.fitnessCalcTitle": "Berechnung Fitnessniveau:",
        "body.detail.fitnessCalcDesc": "Dein Fitnessniveau (0-100 Pkt) berechnet sich aus deiner täglichen Aktivität (Schritte) und deinen absolvierten Trainings.",
        
        // Manual Sleep
        "sleep.manual.title": "Schlaf eintragen",
        "sleep.manual.desc": "Schlafdauer für heute nachtragen",
        "sleep.manual.save": "Speichern",
        "sleep.manual.cancel": "Abbrechen",
        "sleep.manual.hours": "%.1f Std.",
        
        // Login Screen
        "login.welcome": "Willkommen bei",
        "login.tagline": "Trainingslog, Schritte & Challenges\nohne Schnickschnack.",
        "login.feature.training": "Training",
        "login.feature.steps": "Schritte",
        "login.feature.analysis": "Analyse",
        "login.apple.signin": "Mit Apple anmelden",
        "login.google.continue": "Weiter mit Google",
        "login.email.signin": "Mit E-Mail anmelden",
        "login.back": "Zurück",
        "login.link.account": "Account verknüpfen",
        "login.signin": "Anmelden",
        "login.email.placeholder": "E-Mail",
        "login.password.placeholder": "Passwort",
        "login.button.login": "Einloggen",
        "login.create.account": "Konto erstellen",
        "login.forgot.password": "Passwort vergessen?",
        "login.error.email.required": "Bitte gib zuerst deine E-Mail ein.",
        "login.error.presenter": "Konnte Präsentationscontroller nicht finden.",
        "login.error.apple.failed": "Apple Login fehlgeschlagen. Bitte erneut versuchen.",
        "login.password.reset.sent": "E-Mail zum Zurücksetzen wurde gesendet.",
        
        // Register Screen
        "register.link.account": "Konto verknüpfen",
        "register.create.account": "Konto erstellen",
        "register.password.min": "Passwort (min. 6 Zeichen)",
        "register.password.repeat": "Passwort wiederholen",
        "register.accept.terms": "Ich akzeptiere die Nutzungsbedingungen",
        "register.success.linked": "Konto verknüpft. Viel Spaß!",
        "register.success.created": "Konto erstellt. Willkommen!",
        "register.cancel": "Abbrechen",
        
        // Streaks
        "streak.title": "Streak",
        "streak.days": "Tage",
        "streak.weeks": "Wochen",
        "streak.current": "Aktuelle Streak",
        "streak.best": "Beste Streak",
        "streak.share": "Streak teilen",
        "streak.keepGoing": "Weiter so!",
        
        // Common
        "common.done": "Fertig",
        "common.save": "Speichern",
        "common.delete": "Löschen",
        "common.back": "Zurück",
        "common.days": "Tage",
        "common.weeks": "Wochen",
        "time.daysAgo": "Vor %d Tagen",
        
        // Screen 1: Welcome + Name
        "onboarding.welcome": "Willkommen bei",
        "onboarding.welcome.subtitle": "Lass uns deine Fitnessreise personalisieren",
        "onboarding.welcome.message": "Dein persönlicher Fitness-Tracker",
        "onboarding.welcome.description": "Erreiche deine Ziele mit personalisierten Trainingsplänen und detaillierten Statistiken",
        "onboarding.name.question": "Wie sollen wir dich nennen?",
        "onboarding.name.placeholder": "Dein Name",
        "onboarding.letsgo": "Los geht's!",
        
        // Screen 2: Fitness Goals
        "onboarding.goals.title": "Was sind deine Fitnessziele?",
        "onboarding.goals.subtitle": "Wähle alle aus, die auf dich zutreffen",
        "onboarding.goal.loseWeight": "Abnehmen",
        "onboarding.goal.loseWeight.desc": "Körperfett reduzieren und schlanker werden",
        "onboarding.goal.buildMuscle": "Muskeln aufbauen",
        "onboarding.goal.buildMuscle.desc": "Muskelmasse und Definition steigern",
        "onboarding.goal.stayFit": "Fit bleiben",
        "onboarding.goal.stayFit.desc": "Gesundheit und Fitness erhalten",
        "onboarding.goal.gainStrength": "Kraft steigern",
        "onboarding.goal.gainStrength.desc": "Maximalkraft und Power verbessern",
        "onboarding.goal.improveEndurance": "Ausdauer verbessern",
        "onboarding.goal.improveEndurance.desc": "Kondition und Durchhaltevermögen steigern",
        
        // Screen 3: Experience Level
        "onboarding.level.title": "Wie ist dein Trainingslevel?",
        "onboarding.level.subtitle": "Hilft uns, passende Empfehlungen zu geben",
        "onboarding.level.beginner": "Anfänger",
        "onboarding.level.beginner.desc": "Neu im Fitness oder nach längerer Pause",
        "onboarding.level.intermediate": "Fortgeschritten",
        "onboarding.level.intermediate.desc": "Trainiere regelmäßig seit 6+ Monaten",
        "onboarding.level.advanced": "Profi",
        "onboarding.level.advanced.desc": "Erfahrener Athlet mit konstantem Training",
        
        // Screen 4: Training Frequency
        "onboarding.frequency.title": "Lass uns deine Ziele erreichen!",
        "onboarding.frequency.subtitle": "Wie oft wirst du pro Woche trainieren?",
        "onboarding.frequency.perweek": "pro Woche",
        "onboarding.frequency.times": "%dx pro Woche",
        
        // Screen 5: Personal Questions
        "onboarding.personal.title": "Noch ein paar Details",
        "onboarding.personal.subtitle": "Für bessere Empfehlungen (optional)",
        "onboarding.personal.age": "Alter",
        "onboarding.personal.gender": "Geschlecht",
        "onboarding.personal.equipment": "Verfügbares Equipment",
        "onboarding.personal.location": "Trainingsort",
        "onboarding.gender.male": "Männlich",
        "onboarding.gender.female": "Weiblich",
        "onboarding.gender.other": "Divers",
        "onboarding.gender.preferNotToSay": "Keine Angabe",
        "onboarding.equipment.fullGym": "Fitnessstudio",
        "onboarding.equipment.dumbbells": "Kurzhanteln",
        "onboarding.equipment.barbell": "Langhantel",
        "onboarding.equipment.kettlebell": "Kettlebell",
        "onboarding.equipment.resistanceBands": "Widerstandsbänder",
        "onboarding.equipment.bodyweight": "Nur Körpergewicht",
        "onboarding.location.gym": "Fitnessstudio",
        "onboarding.location.home": "Zuhause",
        "onboarding.location.outdoor": "Draußen",
        
        // Screen 6: Muscle Focus
        "onboarding.focus.title": "Welche Bereiche möchtest du trainieren?",
        "onboarding.focus.subtitle": "Tippe auf die Muskelgruppen",
        "onboarding.focus.fullbody": "Ganzkörper-Training",
        "onboarding.focus.selected": "%d Muskelgruppen ausgewählt",
        
        // Screen 7: Ranked System Showcase
        "onboarding.ranked.title": "Werde stärker",
        "onboarding.ranked.subtitle": "Verfolge deinen Fortschritt für jede Muskelgruppe",
        "onboarding.ranked.start": "Start",
        "onboarding.ranked.now": "Jetzt",
        "onboarding.ranked.progress": "12 Monate Fortschritt",
        "onboarding.ranked.feature1": "Individuelle Ranks für jede Muskelgruppe",
        "onboarding.ranked.feature2": "Verfolge deine Entwicklung über Zeit",
        "onboarding.ranked.feature3": "Schalte Badges und Levels frei",
        
        
        "templates.empty.createButton" : "Vorlage erstellen",
        // Screen 8: Apple Watch Showcase
        "onboarding.watch.title": "Trainiere smarter mit Apple Watch",
        "onboarding.watch.subtitle": "Perfekte Integration für dein Handgelenk",
        "onboarding.watch.sets": "Sätze",
        "onboarding.watch.kg": "kg",
        "onboarding.watch.time": "Zeit",
        "onboarding.watch.feature1": "Echtzeit-Herzfrequenz-Tracking",
        "onboarding.watch.feature2": "Live Activities auf Dynamic Island",
        "onboarding.watch.feature3": "Nahtlose Synchronisation zwischen Geräten",
        
        // Screen 9: Templates Showcase
        "onboarding.templates.title": "Erstelle deine erste Trainingsvorlage",
        "onboarding.templates.subtitle": "Spare Zeit mit vorgefertigten Workouts",
        "onboarding.templates.create": "Vorlagenname",
        "onboarding.templates.name": "z.B. Oberkörper-Tag",
        "onboarding.templates.exercises": "Übungen auswählen",
        "onboarding.templates.selected": "%d Übungen ausgewählt",
        "onboarding.templates.feature1": "Schnellstart für deine Lieblingsworkouts",
        "onboarding.templates.feature2": "Unbegrenzt eigene Vorlagen erstellen",
        "onboarding.templates.feature3": "Teile Vorlagen mit Freunden",
        
        // Screen 10: Activity Window Showcase
        "onboarding.activity.title": "Entdecke deine Trainingsmuster",
        "onboarding.activity.subtitle": "Finde heraus, wann du am besten trainierst",
        "onboarding.activity.heatmap": "Aktivitäts-Heatmap",
        "onboarding.activity.feature1": "Erkenne deine besten Trainingszeiten",
        "onboarding.activity.feature2": "Visualisiere trainierte Muskelgruppen",
        "onboarding.activity.feature3": "Detaillierte Statistiken und Insights",
        
        // Screen 11: Social Proof
        "onboarding.social.badge": "7K+ 5★ Bewertungen",
        "onboarding.social.mission": "Unsere Mission ist es, 10 Millionen Menschen zu helfen, ihre Fitnessziele zu erreichen",
        "onboarding.social.review1.title": "Diese App ist fantastisch",
        "onboarding.social.review1.text": "Diese App ist wirklich unterschätzt. Es gibt keine andere App, die das Workout-Logging so gut macht!",
        "onboarding.social.review2.title": "Bester Workout-Tracker",
        "onboarding.social.review2.text": "Ich nutze Movo seit 3 Monaten. Habe Jefit, Strong und Hevy ausprobiert, aber Movo ist der klare Gewinner!",
        
        // Screen 12: Hard Paywall
        "onboarding.paywall.title": "Gestalte deine Testphase",
        "onboarding.paywall.subtitle": "7 Tage kostenlos, dann entscheidest du",
        "onboarding.paywall.timeline.title": "Das erwartet dich in deiner Testwoche:",
        "onboarding.paywall.timeline.today": "Heute – Alle Features freischalten",
        "onboarding.paywall.timeline.today.desc": "Sofortiger Zugriff auf alle Pro-Features",
        "onboarding.paywall.timeline.day5": "Tag 5 – Erinnerung",
        "onboarding.paywall.timeline.day5.desc": "Wir erinnern dich rechtzeitig vor Ablauf",
        "onboarding.paywall.timeline.day7": "Tag 7 – Deine Entscheidung",
        "onboarding.paywall.timeline.day7.desc": "Du wirst nur belastet, wenn du nicht kündigst",
        "onboarding.paywall.recommended": "EMPFOHLEN",
        "onboarding.paywall.onetime": "EINMALIG",
        "onboarding.paywall.peryear": "pro Jahr",
        "onboarding.paywall.permonth": "pro Monat",
        "onboarding.paywall.lifetime": "einmalig",
        "onboarding.paywall.trial.desc": "7 Tage kostenlos, dann %@/Jahr",
        "onboarding.paywall.yearly.desc": "Bestes Preis-Leistungs-Verhältnis",
        "onboarding.paywall.monthly.desc": "Maximale Flexibilität, jederzeit kündbar",
        "onboarding.paywall.lifetime.desc": "Einmal zahlen, für immer nutzen",
        "onboarding.paywall.disclaimer": "Einmaliger In-App-Kauf oder Abo. Kündigung jederzeit möglich. Preise können variieren.",
        "onboarding.paywall.cta.trial": "7-Tage-Trial starten",
        "onboarding.paywall.cta.yearly": "Jahresabo abschließen",
        "onboarding.paywall.cta.monthly": "Monatsabo abschließen",
        "onboarding.paywall.cta.lifetime": "Lifetime kaufen",
        "onboarding.paywall.cancel": "Jederzeit kündbar • Kein Risiko",
        
        // Screen 13: Subscription Confirmation
        "onboarding.confirm.title": "Starte deine Reise",
        "onboarding.confirm.subtitle": "Bestätige deine Auswahl",
        "onboarding.confirm.plan": "Gewählter Plan",
        "onboarding.confirm.feature1": "Unbegrenzter Zugriff auf alle Features",
        "onboarding.confirm.feature2": "Erweiterte Statistiken & PR-Tracking",
        "onboarding.confirm.feature3": "Apple Watch Integration",
        "onboarding.confirm.feature4": "Widgets & Live Activities",
        "onboarding.confirm.feature5": "Muscle Ranking System",
        "onboarding.confirm.starttrial": "7-Tage-Trial starten",
        "onboarding.confirm.subscribe": "Jetzt abonnieren",
        "onboarding.confirm.buy": "Jetzt kaufen",
        "onboarding.confirm.secure": "Sichere Zahlung über Apple",
        "onboarding.confirm.error": "Kauf fehlgeschlagen. Bitte versuche es erneut.",
        "onboarding.plan.yearly": "Jahresabo",
        "onboarding.plan.monthly": "Monatsabo",
        "onboarding.plan.lifetime": "Lifetime",
        
        // Screen 14: Personal Setup
        "onboarding.setup.title": "Personalisiere dein Erlebnis",
        "onboarding.setup.subtitle": "Fast fertig, %@!",
        "onboarding.setup.unit": "Gewichtseinheit",
        "onboarding.setup.weight": "Aktuelles Gewicht",
        "onboarding.setup.height": "Körpergröße",
        "onboarding.setup.steps": "Tägliches Schrittziel",
        
        // Screen 15: Permissions
        "onboarding.permissions.title": "Features aktivieren",
        "onboarding.permissions.subtitle": "Erlaube Zugriff für das volle Movo-Erlebnis",
        "onboarding.permissions.health": "Apple Health",
        "onboarding.permissions.health.desc": "Synchronisiere Schritte, Kalorien, Workouts und mehr",
        "onboarding.permissions.notifications": "Benachrichtigungen",
        "onboarding.permissions.notifications.desc": "Erhalte Erinnerungen für Pausen-Timer und Streaks",
        "onboarding.permissions.tap": "Tippe auf 'Weiter' um Berechtigungen zu erteilen",
        
        // Screen 16: Final
        "onboarding.final.title": "Alles bereit, %@!",
        "onboarding.final.subtitle": "Willkommen bei Movo.\\nLass uns gemeinsam Großes erreichen.",
        "onboarding.final.goals": "Deine Ziele: %d ausgewählt",
        "onboarding.final.frequency": "Trainingsfrequenz: %dx pro Woche",
        "onboarding.final.plan.yearly": "Movo Pro (7-Tage-Trial)",
        "onboarding.final.plan.monthly": "Movo Pro (Monatlich)",
        "onboarding.final.plan.lifetime": "Movo Pro (Lifetime)",
        "onboarding.final.motivation": "Lass uns gemeinsam Großes erreichen 💪",
        
        // Workout & Flow
        "rest": "Pause",
        "round.of": "Runde %d von %d",
        
        // ➜ Add to LocalizedStrings.de
        "howto.lottie.missing"     : "„%@“ (.lottie/.json) nicht gefunden.",
        "howto.lottie.advice"      : "Lege „%@.lottie“ oder „%@.json“ ins Bundle oder hinterlege einen Web-Link.",

        "howto.section.execution"  : "Ausführung",
        "howto.section.breathing"  : "Atmung",
        "howto.section.mistakes"   : "Häufige Fehler",
        "howto.section.progressions": "Skalierung/Varianten",
        "howto.section.note"       : "Hinweis",
      
        
        
        

        "round.number": "Runde %d/%d",
        "round.next": "Nächste Runde %d",
        "next.round.exercise": "Runde %d – Nächste: %@",
        "skip.rest": "Pause überspringen",
        "challenge.swap.title": "Challenge tauschen",
        "challenge.swap.current": "Aktuell:",
        "templates.search.placeholder": "Vorlagen durchsuchen …",
        "keep.progress": "Fortschritt beibehalten",
        "filter.currentTypeOnly": "Nur aktueller Typ",
        "challenge.type.workouts": "Workouts",
        "challenge.type.steps": "Schritte",
        "challenge.type.weeklyVolume": "Trainingsvolumen",
        "challenge.type.streak": "Streak",
        "challenge.type.weeklySessions": "Aktive Tage",

        
       

          "paywall.cta.trial": "Start my free trial",

        
        
        // ➜ Ergänze in LocalizedStrings.de:
        "profile.edit"                : "Profil bearbeiten",
        "profile.edit.title"          : "Profil bearbeiten",
        "profile.photo.change"        : "Profilbild ändern",
        "profile.info.title"          : "Profilinformationen",
        "profile.displayName"         : "Anzeigename",
        "profile.username"            : "Benutzername",
        "profile.aboutMe"             : "Über mich",
        "profile.info.note.title"     : "Hinweis",
        "profile.info.note.text"      : "Dein Anzeigename wird öffentlich angezeigt. Der Benutzername ist eindeutig.",
        "profile.streak.title"        : "Streak",
        "iap.restore.started"         : "Wiederherstellung gestartet – später IAP-Manager einbinden.",
        "settings.logout.confirm"     : "Möchtest du dich wirklich abmelden?",
        
        "cloud.button.syncNow"        : "Mit Cloud synchronisieren",
        "cloud.button.syncing"       : "Synchronisiere",
        "cloud.lastSync.prefix"       : "Stand:",

        
        "cloud.title" : "Movo Cloud",
        "cloud.subtitle" : "Movo synchronisiert NICHT automatisch. Du speicherst & synchronisierst manuell, wenn du möchtest.",
        "cloud.row.subtitle" : "Manuelles Speichern & Synchronisieren",
        "cloud.status.ready" : "Bereit zum Synchronisieren",
        "cloud.status.syncing" : "Synchronisiere…",
        "cloud.syncNow" : "Jetzt synchronisieren",
        "cloud.explainer" : "Tippe auf „Jetzt synchronisieren“, um Trainings und Einstellungen in der Cloud zu sichern oder auf andere Geräte zu übertragen.",

        // Profile Redesign
        "profile.stats.volume": "Last", // or Volumen
        "profile.friends.add": "Freunde hinzufügen",
        "settings.title.short": "Einstellungen", 
        "profile.stats.minutes": "Min", // Suffix
      

        // (Optionaler Alias, falls du dich mal vertippst)
        "skip.reset": "Pause überspringen",
        "training.stretch.title": "Stretch & Mobility",
        "training.stretch.subtitle": "Beweglichkeit & Regeneration",
        "training.stretch.duration": "10–15 Min",
        "training.stretch.level": "Alle Level",

        "training.meditation.title": "Meditation & Fokus",
        "training.meditation.subtitle": "Achtsamkeit & Atmung",
        "training.meditation.duration": "8–12 Min",
        "training.meditation.level": "Alle Level",

        "training.core.title": "Core Crusher",
        "training.core.subtitle": "Bauch & Rumpf",
        "training.core.duration": "12–15 Min",
        "training.core.level": "Alle Level",

        "workout.start": "🚀 Workout starten",
        "exercise.number": "Übung %d",
        "next.exercise": "Nächste: %@",
        "exercise.skip": "Übung überspringen",
        "pause": "Pause",
        "resume": "Fortsetzen",
        "add.time": "+15s",
        "finish": "🎉 Beenden",
        "workout.complete": "Workout abgeschlossen",
        "week.complete": "Woche geschafft 🎉",
        "feedback.placeholder": "Dein Feedback...",
        "save": "Abschließen & Speichern",
        "saved": "Gespeichert 🙌",

        // Wochen & Sets
        "week.number": "Woche %d",
        "sets.completed": "%d/%d Sets abgeschlossen",

        // Challenges
        "challenge.workouts.title": "5 Workouts pro Woche",
        "challenge.workouts.desc": "Schließe 5 Workouts bis Sonntag ab",
        "challenge.steps.title": "10.000 Schritte pro Tag",
        "challenge.steps.desc": "Halte dich täglich aktiv",
        "challenges.title": "Herausforderungen",

        // Allgemein
        "reset.progress": "Fortschritt zurücksetzen",
        "weight": "Gewicht",
        "reps": "Wiederholungen",
        "equipment": "Geräte",
        "warmup": "Aufwärmen",
        "cooldown": "Abkühlen",
        "training.units": "Trainingseinheiten",
        "duration": "Dauer",
        "calories": "Kalorien",
        "focus": "Fokus",
        "start": "Starten",
        "level": "Level",
        "days": "Tage",                    // ⬅️ ergänzt
        "common.viewAll": "Alle ansehen",  // ⬅️ schon genutzt
        
        "time.mmss" : "%dmin %02ds",       // DE: "%dmin %02ds"


        // Templates
        "templates.title": "Trainingsvorlagen",
        "templates.empty.title": "Noch keine Vorlagen",
        "templates.empty.subtitle": "Tippe auf das ➕, um deine erste Vorlage zu erstellen.",
        "templates.empty.button": "Neue Vorlage erstellen",
        "templates.section.default": "Movo Vorlagen",
        "templates.section.custom": "Eigene Vorlagen",
        "templates.edit": "Bearbeiten",
        "templates.share": "Teilen",
        "templates.delete": "Löschen",
        "templates.pin": "Auf Home anpinnen",
        "templates.unpin": "Vom Home lösen",
        "templates.exercisesCount": "%d Übungen",

        "templates.favorites.title": "Favoriten auf Home",
        "templates.favorites.desc": "Pinne deine wichtigsten Routinen an, um sie hier direkt zu starten.",
        "templates.favorites.select": "Routinen auswählen",
        
        // QR Code View
        "template.qr.scan": "Scanne diesen Code mit deiner Kamera",
        "template.qr.step1": "Öffne die Kamera-App",
        "template.qr.step2": "Richte die Kamera auf den QR-Code",
        "template.qr.step3": "Tippe auf 'In Movo öffnen'",
        "template.qr.share": "QR-Code teilen",
        "template.qr.sharetext": "Trainingsvorlage",
        "template.qr.scaninstruction": "Scanne diesen QR-Code mit deiner Kamera, um die Vorlage in Movo zu importieren.",
        "exercise": "Übung",
        "exercises": "Übungen",

        // ---- Ergänzungen DE ----

        // Onboarding Phase 2 (Corrected)
        "onboarding.easyLogging.title": "Starte ein Training",
        "onboarding.easyLogging.subtitle": "Wähle eine Vorlage zum Starten.",
        "onboarding.trackIt.title": "Tracke es",
        "onboarding.trackIt.subtitle": "Logge Sätze. Konzentriere dich aufs Training.",
        "onboarding.finished.title": "Überprüfen & Abschließen",
        "onboarding.finished.subtitle": "Deine Reise geht weiter.",
        
        // Template Names
        "Push": "Push",
        "Pull": "Pull",
        "Legs": "Beine",
        "Upper Body": "Oberkörper",
        "Lower Body": "Unterkörper",
        "Full Body A": "Ganzkörper A",
        "Full Body B": "Ganzkörper B",
        "Cardio & Core": "Cardio & Core",
        "Arms": "Arme",
        
        "training.addExercise.new": "Neue Übung hinzufügen \"%@\"",
        
        // Onboarding Phase 2 - Statistics & Permissions
        "onboarding.statistics.title": "Visualisiere dein Wachstum",
        "onboarding.statistics.subtitle": "Tiefe Einblicke in deine Trainingsgewohnheiten und Muskelerholung.",
        "onboarding.statistics.activityStreak": "Aktivitäts-Serie",
        "onboarding.notifications.title": "Bleib konsequent",
        "onboarding.notifications.subtitle": "Erhalte Erinnerungen zum Trainieren und Fortschritt verfolgen.",
        "onboarding.health.title": "Mit Health synchronisieren",
        "onboarding.health.subtitle": "Importiere deine Workouts und Biometrie automatisch.",
        
        // Onboarding - Social Feed
        "onboarding.social.title": "Werde Teil der Community",
        "onboarding.social.subtitle": "Verbinde dich mit Freunden und teile deine Erfolge.",
        "onboarding.social.you": "Du",
        "onboarding.social.post1": "hat ein Training abgeschlossen",
        "onboarding.social.post2": "hat Level 10 erreicht",
        "onboarding.social.post3": "hat Movo gestartet",
        "onboarding.social.post4": "hat einen PR geschafft",
        "onboarding.social.post5": "hat eine Challenge beendet",
        "onboarding.social.time1": "vor 2 Std.",
        "onboarding.social.time2": "vor 4 Std.",
        "onboarding.social.time3": "Gerade eben",
        "onboarding.social.time4": "vor 5 Std.",
        "onboarding.social.time5": "vor 1 Tag",
        
        // Onboarding - Reviews
        "onboarding.reviews.title": "Unterstütze einen Solo-Entwickler",
        "onboarding.reviews.subtitle": "Hi! Dein Feedback hilft uns, Movo jeden Tag ein Stückchen besser zu machen.",
        
        // Rest Timer
        "rest.pause": "Pause",
        "rest.minutes": "Minuten",
        "rest.seconds": "Sekunden",
        "rest.start": "Start",
        "rest.resume": "Weiter",
        "rest.reset": "Zurücksetzen",
        "rest.cancel": "Abbrechen",
        "rest.done": "Fertig",
        
        // Home - Resume Training
        "home.resume.title": "Training fortsetzen?",
        "home.resume.discard": "Verwerfen",
        "home.resume.continue": "Fortsetzen",

        // MARK: - New Exercises (Gym)


        // History
        "history.empty": "Noch keine Trainings – starte dein erstes Workout!",

        // Friends & Social
        "Friends": "Freunde",
        "Requests": "Anfragen",
        "Search": "Suche",
        "Incoming": "Eingehend",
        "Outgoing": "Gesendet",
        "Suggested": "Vorschläge",
        "Search Users": "Nutzer suchen...",
        "common.close": "Schließen",
        "common.edit": "Bearbeiten",
        "No Friends": "Keine Freunde",
        "Add friends via search": "Füge Freunde über die Suche hinzu.",
        "No incoming requests": "Keine offenen Anfragen",
        "exercise.hip_thrust_barbell.instr": "Oberen Rücken auf Bank, Hantel über Hüfte. Hüfte heben.",
        "exercise.cable_crossover": "Cable Crossover",
        "exercise.cable_crossover.instr": "Stehe mittig zwischen den Türmen. Ziehe die Griffe vor dem Körper zusammen.",
        "exercise.pec_deck": "Pec Deck Machine",
        "exercise.pec_deck.instr": "Setze dich mit geradem Rücken hin. Führe die Polster vor der Brust zusammen.",
        "exercise.decline_bench_press": "Decline Bench Press",
        "exercise.decline_bench_press.instr": "Lege dich auf die Negativbank. Drücke die Hantel nach oben.",
        "exercise.tbar_row": "T-Bar Row",
        "exercise.tbar_row.instr": "Stelle dich über die Hantel, Brust gestützt oder vorgebeugt. Ziehe das Gewicht zur Brust.",
        "exercise.lat_pulldown_close": "Lat Pulldown (Close Grip)",
        "exercise.lat_pulldown_close.instr": "Verwende den V-Griff. Ziehe zur Brust und lehne dich leicht zurück.",
        "exercise.single_arm_row": "Single Arm Row",
        "exercise.single_arm_row.instr": "Knie auf Bank. Ziehe die Hantel zur Hüfte.",
        "exercise.back_extension": "Back Extension",
        "exercise.back_extension.instr": "Hüfte auf dem Polster. Oberkörper absenken und wieder aufrichten.",
        "exercise.hack_squat": "Hack Squat",
        "exercise.hack_squat.instr": "Schultern unter die Polster. Tief beugen und wieder hochdrücken.",
        "exercise.goblet_squat": "Goblet Squat",
        "exercise.goblet_squat.instr": "Halte Gewicht vor der Brust. Tief beugen.",
        "exercise.sumo_deadlift": "Sumo Deadlift",
        "exercise.sumo_deadlift.instr": "Breiter Stand. Griff innerhalb der Knie. Heben.",
        "exercise.seated_calf_raise": "Seated Calf Raise",
        "exercise.seated_calf_raise.instr": "Sitzen, Polster auf Oberschenkel. Fersen anheben.",
        "exercise.hip_abduction": "Hip Abduction Machine",
        "exercise.hip_abduction.instr": "Drücke die Beine gegen den Widerstand nach außen.",
        "exercise.hip_adduction": "Hip Adduction Machine",
        "exercise.hip_adduction.instr": "Drücke die Beine gegen den Widerstand zusammen.",
        "exercise.upright_row": "Upright Row",
        "exercise.upright_row.instr": "Ziehe die Stange bis zur Brusthöhe, Ellbogen führen.",
        "exercise.front_raise": "Front Raise",
        "exercise.front_raise.instr": "Hebe die Hantel vor dem Körper bis auf Schulterhöhe.",
        "exercise.reverse_fly_machine": "Reverse Fly (Machine)",
        "exercise.reverse_fly_machine.instr": "Blick zur Maschine. Drücke die Griffe nach hinten außen.",
        "exercise.preacher_curl": "Preacher Curl",
        "exercise.preacher_curl.instr": "Arme über das Polster legen. Gewicht curlen.",
        "exercise.concentration_curl": "Concentration Curl",
        "exercise.concentration_curl.instr": "Sitzend, Ellbogen am Innenoberschenkel. Curlen.",
        "exercise.triceps_extension_overhead": "Triceps Extension (Overhead)",
        "exercise.triceps_extension_overhead.instr": "Hantel über Kopf halten. Hinter den Kopf absenken und strecken.",
        "exercise.woodchopper": "Cable Woodchopper",
        "exercise.woodchopper.instr": "Rotiere den Oberkörper und ziehe das Kabel diagonal.",
        "exercise.russian_twist": "Russian Twist",
        "exercise.russian_twist.instr": "Sitzend, zurücklehnen. Oberkörper von Seite zu Seite drehen.",
        "exercise.ab_wheel": "Ab Wheel Rollout",
        "exercise.ab_wheel.instr": "Knien. Rad nach vorne rollen, Spannung halten. Zurückrollen.",
        "exercise.smith_squat": "Smith Machine Squat",
        "exercise.smith_squat.instr": "Kniebeuge in der geführten Multipresse.",
        "exercise.smith_bench": "Smith Machine Bench Press",
        "exercise.smith_bench.instr": "Bankdrücken in der geführten Multipresse.",
        "exercise.cable_curl": "Cable Curl",
        "exercise.cable_curl.instr": "Curls am tiefen Block des Kabelzugs.",
        "exercise.cable_lateral_raise": "Cable Lateral Raise",
        "exercise.cable_lateral_raise.instr": "Griff vom tiefen Block seitlich anheben.",
        "exercise.shrug_dumbbell": "Shrug (Dumbbell)",
        "exercise.shrug_dumbbell.instr": "Schwere Hanteln halten. Schultern zu den Ohren ziehen.",
        "exercise.wrist_curl": "Wrist Curl",
        "exercise.wrist_curl.instr": "Unterarme auf Bank ablegen. Handgelenke beugen.",
        "exercise.dead_bug": "Dead Bug",
        "exercise.dead_bug.instr": "Rückenlage. Arm und gegenüberliegendes Bein absenken.",
        "exercise.elliptical": "Elliptical",
        "exercise.elliptical.instr": "Benutze den Crosstrainer.",
        "exercise.stair_climber": "Stair Climber",
        "exercise.stair_climber.instr": "Stufen steigen.",
        "exercise.trap_bar_deadlift": "Trap Bar Deadlift",
        "exercise.trap_bar_deadlift.instr": "In der Trap Bar stehen. In die Knie gehen und heben.",
        "exercise.landmine_press": "Landmine Press",
        "exercise.landmine_press.instr": "Drücke die verankerte Langhantel einarmig über Kopf.",
        "exercise.box_jump": "Box Jump",
        "exercise.box_jump.instr": "Springe auf die Box.",
        "exercise.kettlebell_swing": "Kettlebell Swing",
        "exercise.kettlebell_swing.instr": "Aus der Hüfte schwingen, Kettlebell bis auf Augenhöhe.",
        "exercise.farmers_walk.instr": "Gehe mit schweren Gewichten in den Händen.",
        "exercise.close_grip_bench.instr": "Bankdrücken mit schulterbreitem Griff.",
        "exercise.side_plank.instr": "Seitlich auf Stützarm halten. Körper gerade.",
        "exercise.good_morning.instr": "Hantel im Nacken. Oberkörper vorbeugen, Beine leicht gebeugt.",
        "exercise.arnold_press_dumbbell": "Arnold Press (Kurzhanteln)",
        "exercise.bench_press_barbell": "Bankdrücken (Langhantel)",
        "exercise.incline_bench_press_barbell": "Schrägbankdrücken (Langhantel)",
        "exercise.bench_press_dumbbell": "Bankdrücken (Kurzhanteln)",
        "exercise.incline_bench_press_dumbbell": "Schrägbankdrücken (Kurzhanteln)",
        "exercise.chest_fly_cable": "Fliegende (Kabelzug)",
        "exercise.chest_press_machine": "Brustpresse (Maschine)",
        "exercise.push_up": "Liegestütze",
        "exercise.dip": "Dips",
        "exercise.squat_barbell": "Kniebeugen (Langhantel)",
        "exercise.front_squat_barbell": "Front-Kniebeugen (Langhantel)",
        "exercise.leg_press": "Beinpresse",
        "exercise.leg_extension": "Beinstrecker",
        "exercise.leg_curl_lying": "Beinbeuger (Liegend)",
        "exercise.deadlift_barbell": "Kreuzheben (Langhantel)",
        "exercise.romanian_deadlift_dumbbell": "Rumänisches Kreuzheben (Kurzhanteln)",
        "exercise.bulgarian_split_squat": "Bulgarische Split Kniebeugen",
        "exercise.calf_raise_standing": "Wadenheben (Stehend)",
        "exercise.pull_up": "Klimmzüge",
        "exercise.lat_pulldown_cable": "Latzug (Kabel)",
        "exercise.seated_row_cable": "Rudern sitzend (Kabel)",
        "exercise.bent_over_row_barbell": "Langhantelrudern",
        "exercise.face_pull": "Face Pulls",
        "exercise.overhead_press_barbell": "Schulterdrücken (Langhantel)",
        "exercise.shoulder_press_dumbbell": "Schulterdrücken (Kurzhantel)",
        "exercise.lateral_raise_dumbbell": "Seitheben (Kurzhantel)",
        "exercise.bicep_curl_barbell": "Bizeps Curls (Langhantel)",
        "exercise.bicep_curl_dumbbell": "Bizeps Curls (Kurzhantel)",
        "exercise.hammer_curl": "Hammer Curls",
        "exercise.triceps_pushdown_cable": "Trizepsdrücken (Kabel)",
        "exercise.skullcrusher_ez_bar": "Skullcrusher (SZ-Stange)",
        "exercise.plank": "Unterarmstütz (Plank)",
        "exercise.crunch": "Crunches",
        "exercise.hanging_leg_raise": "Hängendes Beinheben",
        "exercise.running_treadmill": "Laufen (Laufband)",
        "exercise.cycling_indoor": "Radfahren (Indoor)",
        "exercise.rowing_machine": "Rudermaschine",
        "exercise.jump_rope": "Seilspringen",
        "exercise.yoga": "Yoga",
        "exercise.stretching": "Dehnen",
        "exercise.hip_thrust_barbell": "Hip Thrust (Langhantel)",

        "exercise.close_grip_bench": "Enges Bankdrücken",
        "exercise.side_plank": "Seitstütz (Side Plank)",
        "exercise.good_morning": "Good Mornings",
        "exercise.farmers_walk": "Farmer's Walk",

        "exercise.ab_crunch_machine": "Bauchpresse (Maschine)",
        "exercise.ab_crunch_machine.instr": "Setze dich in die Maschine. Beuge den Oberkörper mit den Bauchmuskeln nach vorne.",


        // Missing Translations (Audit Fix)
        "exercise.instructions.shoulder_press_dumbbell": "Drücke die Kurzhanteln über Kopf.",
        "exercise.instructions.bench_press_incline": "Bankdrücken auf der Schrägbank mit der Langhantel.",
        "exercise.instructions.bench_press_incline_dumbbell": "Bankdrücken auf der Schrägbank mit Kurzhanteln.",
        "exercise.instructions.chest_fly_cable": "Führe die Kabel vor der Brust zusammen.",
        "exercise.instructions.dip": "Beuge und strecke die Arme am Barren.",
        "exercise.instructions.front_squat": "Kniebeuge mit der Hantel vor der Brust.",
        "exercise.instructions.leg_extension": "Strecke die Beine gegen den Widerstand.",
        "exercise.instructions.leg_curl_lying": "Beuge die Beine im Liegen.",
        "exercise.instructions.rdl_dumbbell": "Rumänisches Kreuzheben mit Kurzhanteln.",
        "exercise.instructions.calf_raise_standing": "Wadenheben im Stehen.",
        "exercise.instructions.lat_pulldown": "Ziehe die Stange zur Brust.",
        "exercise.instructions.seated_row": "Rudern im Sitzen am Kabelzug.",
        "exercise.instructions.face_pull": "Ziehe das Seil zum Gesicht.",
        "exercise.instructions.lateral_raise": "Seitheben mit Kurzhanteln.",
        "exercise.instructions.hammer_curl": "Curls mit Hammergriff.",
        "exercise.instructions.triceps_pushdown": "Drücke das Kabel nach unten.",
        "exercise.instructions.skullcrusher": "Trizepsstrecken im Liegen (Stirndrücken).",
        "exercise.instructions.plank": "Halte die Unterarmstütz-Position.",
        "exercise.instructions.crunch": "Crunches für die Bauchmuskeln.",
        "exercise.instructions.leg_raise": "Beinheben hängend oder liegend.",
        "exercise.instructions.cycling_indoor": "Fahre auf dem Ergometer.",
        "exercise.instructions.jump_rope": "Springseil springen.",
        "exercise.instructions.yoga": "Führe Yoga-Posen aus.",
        "exercise.instructions.stretching": "Dehne die Muskeln.",
        "exercise.instructions.triceps_dip_machine": "Drücke die Griffe der Trizepsmaschine nach unten.",
        
        "paywall.h1": "Training. Einfach. Jeden Tag.",
           "paywall.h2": "„Wir sind in der Beta – alle Pro-Features sind aktuell kostenlos.",
           "paywall.bullet.plan": "Personalisierte Pläne & Empfehlungen",
           "paywall.bullet.stats": "Erweiterte Statistiken & PR-Verlauf",
        
        "premium.active.title": "Movo Premium Aktiv",
        "premium.manage": "Verwalten",
        "premium.upgrade.title": "Upgrade auf Pro",
        "premium.upgrade.desc": "Nutze das volle Potenzial",
           "paywall.bullet.motivation": "Motivation durch Ziele & Badges",

           "paywall.timeline.title": "Das erwartet dich in deiner Testwoche:",
           "paywall.timeline.today.title": "Heute – Alles freischalten",
           "paywall.timeline.today.text": "Sofortiger Zugriff auf alle Pro-Features.",
           "paywall.timeline.reminder.title": "In 5 Tagen – Erinnerung",
           "paywall.timeline.reminder.text": "Wir erinnern dich rechtzeitig vor Ablauf.",
           "paywall.timeline.end.title": "In 7 Tagen – Ende der Testwoche",
           "paywall.timeline.end.text": "Du wirst nur belastet, wenn du nicht kündigst.",

        

        /* Plans */
      

        /* CTA */
        "paywall.cta.yearly.trial" : "7 Tage kostenlos testen",
        "paywall.cta.yearly.subscribe" : "Jahresabo abschließen",
        "paywall.cta.monthly.subscribe" : "Monatlich abonnieren",
        "paywall.cta.lifetime.buy" : "Einmalig kaufen",
        "paywall.cta.beta.start" : "Beta-Zugang starten",

        /* Footer & Premium Overlay */
      
        
        
           "paywall.plan.yearly.title": "Jahresplan",
           "paywall.plan.yearly.tag": "7 Tage kostenlos",
           "paywall.plan.yearly.price": "29,99€/Jahr",
           "paywall.plan.yearly.foot": "nur 2,49€/Monat",
           "paywall.plan.monthly.title": "Monatlich",
           "paywall.plan.monthly.price": "2,99€/Monat",
           "paywall.plan.beta.title": "Beta-Zugang",
           "paywall.plan.beta.tag": "Alle Pro-Features kostenlos freischalten",
           "paywall.plan.beta.price": "0,00 €",
           "paywall.plan.badge.best": "BESTES ANGEBOT",
           "paywall.plan.badge.beta": "BETA",
        

           "paywall.disclaimer": "Einmaliger In-App-Kauf oder Abo. Kündigung jederzeit möglich. Preise können variieren.",
           "paywall.cta": "Kostenlos starten",
           "paywall.cta.beta": "Jetzt kostenlos freischalten",
           "paywall.terms": "AGB",
           "paywall.privacy": "Datenschutz",

           "premium.locked": "Premium-Statistiken",
           "premium.unlock": "Kostenlos freischalten",
        // Home
        "home.title": "Dein Training",
        "home.statsTitle": "Deine Aktivität",
        "home.startTraining": "Training starten",
        "home.currentTraining": "Aktuelles Training",
        "home.defaultTrainingTitle": "Dein Training",
        "home.today": "Heute",
        "home.since": "Seit",
        "home.continue": "Weiter trainieren",
        "home.recentTrainings": "Letzte Trainings",
        "home.recentTrainingsPlaceholder": "Hier werden deine vergangenen Trainingseinheiten angezeigt.",
        "home.viewDetails": "Details ansehen",
        "home.templates": "Trainingsvorlagen",
        
        
        "lastTraining.title": "Trainingsverlauf",
        "lastTraining.header": "Letztes Training",
        "lastTraining.none": "Noch keine Trainings",

        "lastTraining.stat.totalSessions": "Trainings insgesamt",
        "lastTraining.stat.thisWeek": "Diese Woche",
        "lastTraining.stat.currentStreak": "Aktuelle Serie",
        "lastTraining.stat.currentStreak.value": "%d Tage",
        "lastTraining.stat.avgPerWeek": "Durchschnitt pro Woche",
        "lastTraining.stat.avgPerWeek.value": "%.1f / Woche",

        "lastTraining.recent.title": "Letzte Trainings",
        "lastTraining.empty.title": "Keine Trainings",
        "lastTraining.empty.description": "Starte dein erstes Training, um deinen Fortschritt zu verfolgen!",

        "lastTraining.motivation.30": "Unaufhaltbarer Champion! 🏆",
        "lastTraining.motivation.14": "Du brennst! 🔥",
        "lastTraining.motivation.7": "Eine Woche am Stück! ⭐",
        "lastTraining.motivation.50": "Konstanz zahlt sich aus! 💪",
        "lastTraining.motivation.20": "Du baust Momentum auf! 🚀",
        "lastTraining.motivation.default": "Jede Wiederholung zählt! 💯",

        "lastTraining.motivation.sub.streak7": "Halte die Serie am Leben!",
        "lastTraining.motivation.sub.weekGood": "Starke Woche!",
        "lastTraining.motivation.sub.default": "Du machst Fortschritte!",

 
        "weight.card.title" : "Gewicht, kg",

     
      
        "date.oneWeekAgo": "Vor 1 Woche",
        "date.weeksAgo": "Vor %d Wochen",

      

        "time.minutes.short": "%d Min",
        "time.hoursMinutes.short": "%dh %dm",

        "home.streak.title": "STREAK",
        "home.streak.days": "TAGE",
        "home.steps.title": "SCHRITTE",
        
        "streak.unlocked.title": "Du hast eine Streak freigeschaltet!",
        "streak.weeks.label": "Wochen-Streak",
        "streak.hint": "Logge Workouts, um deine Streak fortzusetzen!",
        "common.continue": "Weiter",
        "profile.streakHeader": "Streak",

        // Menü
        
        "common.goal": "Ziel",
        "common.category": "Kategorie",

        "statistics.empty.range": "Keine Daten im Zeitraum.",
        "statistics.no.data": "Keine Daten vorhanden",
        "statistics.volume.per.day": "Volumen je Tag",
        "statistics.pr.timeline": "PR-Verlauf (est. 1RM)",
        "statistics.sets.distribution": "Satzverteilung (Wdh.)",
        "statistics.weight.distribution.format": "Gewichtsverteilung (%@)",
        "statistics.top.days.volume": "Top-Tage (Volumen)",
        "statistics.sessions": "Sessions",
        "statistics.volume": "Volumen",
        "statistics.avg.reps": "Ø Wdh.",
        "statistics.best.set": "Bestes Set",
        "statistics.est1rm": "Est. 1RM",

        "menu.profile": "Profil anzeigen",
        "menu.settings": "Einstellungen",
        "menu.login": "Einloggen",
        "menu.logout": "Logout",

        // Dashboard
        "dashboard.title": "Challenges",
        "dashboard.trainingUnits": "Trainingseinheiten",

        // Woche
        "week.title": "Woche",
        "week.duration": "Dauer",
        "week.calories": "Kalorien",
        "week.focus": "Fokus",
        "week.equipment": "Equipment",
        "week.warmup": "Warm-up",
        "week.exercises": "Übungen",
        "week.cooldown": "Cool-down",
        "week.start": "Start",

        // Notifications
        "notifications.challengesTitle": "Deine Challenges",
        "notifications.challengesBody": "Hast du heute alle Ziele erreicht? Schau in die App!",
        "notifications.workoutDone": "Workout erledigt!",
        "notifications.workoutDoneBody": "Super! Du hast heute ein Workout abgeschlossen 💪",
        "notifications.stepsDone": "Schrittziel erreicht!",
        "notifications.stepsDoneBody": "Toll! Du hast heute dein Schrittziel erreicht 🚶‍♂️",

        // Template Management
        "template.new": "Neue Vorlage",
        "template.edit": "Vorlage bearbeiten",
        "template.section": "Vorlage",
        "template.name.placeholder": "Name eingeben",
        "template.exercises": "Übungen auswählen",
        "template.search.placeholder": "Übung suchen...",
        "template.cancel": "Abbrechen",
        "template.save": "Vorlage speichern",
        "template.save.changes": "Änderungen sichern",

        // Settings
        "settings.title": "Einstellungen",
        "settings.appearance": "Erscheinung",
        "settings.mode": "Darstellung",
        "settings.color": "Akzentfarbe",
        "settings.general": "Allgemein",
        "settings.notifications": "Benachrichtigungen",
        "settings.language": "Sprache",
        "settings.account": "Konto",
        "settings.logout": "Abmelden",
        "settings.about": "Über",
        "settings.version": "Version",
        "settings.units.metric": "Metrisch",
        "settings.units.imperial": "Imperial",
        "settings.goals.trainingDays": "Trainingstage",
        "settings.goals.daysPerWeek": "%dx/Woche",

        // Training
        "training.title.placeholder": "Titel eingeben …",
        "training.searchExercise": "Übung suchen",
        "training.addExerciseNav": "Übung hinzufügen",
        "training.cancel": "Abbrechen",
        "training.save": "Speichern",
        "start.training": "Training starten",
        "training.completeAll": "Abschließen",
        "training.resetAll": "Zurücksetzen",
        "training.addExercise": "Übung hinzufügen",
        "training.addSet": "Satz hinzufügen",
        "training.kg": "kg",
        "training.reps": "Wdh",
        "training.training": "Training",
        
        
        
    
 

        // Exercise Management
        "exerciseManagement.title": "Übungen verwalten",
        "exerciseManagement.newExercise": "Neue Übung",
        "exerciseManagement.add": "Hinzufügen",

        // New Exercise
        "newExercise.title": "Neue Übung",
        "newExercise.placeholder": "Neue Übung eingeben",
        "newExercise.add": "Hinzufügen",
        "newExercise.cancel": "Abbrechen",

        // Profile
        "profile.title": "Profil",
        "profile.close": "Schließen",
        "profile.guest": "Gast",
        "profile.level": "Level %d",
        "profile.xpProgress": "%d / %d XP bis Level %d",
        "profile.xp": "XP",
        "profile.coins": "Coins",
        "profile.streak": "🔥 %d-Tage Streak",
        "profile.streakHint": "Bleib dran für neue Abzeichen!",
        "profile.badges": "Abzeichen",
        "training.pauseTimer" : "Pausen-Timer",
        "training.done" : "Fertig",


        // Profile – Körperwerte (neu)
        "profile.metrics.title": "Körperwerte",
        "profile.metrics.edit": "Körperwerte bearbeiten",
        "profile.metrics.importHealth": "Aus Apple Health übernehmen",
        "profile.metrics.weightKg": "Gewicht (kg)",
        "profile.metrics.heightCm": "Größe (cm)",
        "profile.metrics.bodyFatPct": "Körperfett (%)",
        "profile.metrics.restingHR": "Ruhepuls (bpm)",
        "profile.metrics.bmi": "BMI",
        "profile.metrics.healthImport.title": "Health-Import",
        "profile.metrics.health.unavailable": "Health nicht verfügbar.",
        "profile.metrics.health.authFailed": "Health-Zugriff fehlgeschlagen",
        "training.discardMessage" : "Möchtest du dieses Training verwerfen? Deine Eingaben gehen verloren.",


        // Units
        "workouts.unit": "Workouts",
        "steps.unit": "Schritte",
        "steps.today": "Heutige Schritte",   // ⬅️ neu für StepCounterView

        // Programme
        "training.shred.title": "Shred & Sculpt",
        "training.shred.subtitle": "Kraft & Fettverbrennung",
        "training.shred.duration": "6 Wochen",
        "training.shred.level": "Fortgeschritten",
        "training.fullbody.title": "Full Body Blast",
        "training.fullbody.subtitle": "Ganzkörper Power",
        "training.fullbody.duration": "6 Wochen",
        "training.fullbody.level": "Mittel",
        "privacy.private" : "Privat",


        // History
        "history.title": "Trainingsverlauf",
        "history.search.placeholder": "Training oder Datum suchen",
        "history.sort.help": "Sortieren (neu/alt)",
        "history.exercises": "Übungen",
        "history.sets": "Sätze",
        
        
        "paywall.title" : "Statistiken freischalten",
        "paywall.bullet.best" : "Bestes Training & Wochenansicht",
        "paywall.bullet.total" : "Gesamtgewicht & Volumen-Charts",
        "paywall.bullet.top" : "Top-Übungen & PR-Timeline",
        "paywall.bullet.details" : "Detail-Stats je Übung",
        "paywall.unlock" : "Einmalig freischalten",
        "paywall.restoring" : "Wird entsperrt…",
        "paywall.restore" : "Käufe wiederherstellen",

     
        

        // Details
        "details.title": "Details",
        "details.exercises": "Übungen",
        "details.sets": "Sätze",
        "details.duration": "Dauer",
        "details.weight": "Gewicht",
        "details.set": "Satz",
        "details.reps": "Wdh",

        // Statistics
        "statistics.title": "Statistik",
        "statistics.period": "Zeitraum",
        "statistics.period.week": "Woche",
        "statistics.period.month": "Monat",
        "statistics.period.year": "Jahr",
        "statistics.period.all": "Alle",
        "statistics.progress": "Verlauf",
        "statistics.duration.chart": "Trainingsdauer (Minuten)",
        "statistics.minutes": "Minuten",
        "statistics.exercise.stats": "Übungsstatistiken",
        "statistics.exercise.select": "Übung auswählen",
        "statistics.trainings": "Trainings",
        "statistics.time": "Zeit",
        "statistics.total.weight": "Gesamtgewicht",
        "statistics.max.weight": "Max Gewicht",
        "statistics.avg.weight": "Ø Gewicht",
        "statistics.weight.progress": "Gewichtsentwicklung",
        "statistics.unlock.title": "Statistiken freischalten",
        "statistics.unlock.subtitle": "Erhalte Zugriff auf detaillierte Auswertungen, Fortschrittscharts und mehr.",
        "statistics.unlock.button": "Freischalten",
        "statistics.unlock.restore": "Käufe wiederherstellen",
        "statistics.workouts.per.week": "Trainings pro Woche",
        "statistics.top.exercises": "Top-Übungen (Volumen)",
        "statistics.exercise": "Übung",
        "statistics.best.training": "Bestes Training",
        "training.restOverTitle" : "Pause vorbei",
        "live.running"  : "🏋️ Training läuft",
        "live.sets"     : "Sätze",
        "live.duration" : "Dauer",
        "live.weight"   : "Gewicht",
        "training.restOverBody"  : "Weiter trainieren!",
        "statistics.exercise.none": "Keine Übungen im ausgewählten Zeitraum gefunden.",

        "settings.cloudSync" : "Movo Cloud",
        "settings.design.title" : "Design & Darstellung",
        "settings.design.subtitle" : "Farbschema, Karten, Buttons, Typo",
        "settings.units" : "Einheiten",
        "settings.legal" : "Rechtliches",

        "settings.legal.imprint.title" : "Impressum & AGB",
        "settings.legal.imprint.subtitle" : "Rechtliche Hinweise",
        "settings.legal.privacy.title" : "Datenschutz",
        "settings.legal.privacy.subtitle" : "DSGVO-konforme Datenschutzerklärung",
        "settings.legal.consent.title" : "Einwilligungen verwalten",
        "settings.legal.consent.subtitle" : "Analytics, Werbung, Crash-Reports",

        "settings.aboutApp.title" : "Über die App",
        "settings.aboutApp.subtitle" : "Was sie dir bringt",
       

        "alert.logout.message" : "Möchtest du dich wirklich abmelden?",

        "cloud.status.guest" : "Lokaler Modus (Gast)",
        "cloud.status.active" : "Movo Cloud aktiv",
        "cloud.subtitle.guest" : "Melde dich an, um Daten mit der Movo Cloud zu synchronisieren.",
        "cloud.subtitle.active.last" : "Angemeldet: %@ • UID: %@ • Letzter Sync: %@",
        "cloud.subtitle.active.waiting" : "Angemeldet: %@ • UID: %@ • Warte auf ersten Sync …",
        "cloud.subtitle.noEmail" : "ohne E-Mail",

        "metrics.trainings" : "Trainings",
        "metrics.templates" : "Vorlagen",
        "metrics.challenges" : "Challenges",
        "metrics.units" : "Einheiten",

        "imprint.header.title" : "Rechtliches",
        "imprint.header.subtitle" : "Impressum und Allgemeine Geschäftsbedingungen.",
        "imprint.tab.impressum" : "Impressum",
        "imprint.tab.agb" : "AGB",
        "imprint.navTitle" : "Impressum & AGB",
        "imprint.contact" : "Kontakt",

        "privacy.header.title" : "Datenschutz",
        "privacy.header.subtitle" : "Transparenz über Daten, Zwecke und Rechte (DSGVO).",
        "privacy.title" : "Datenschutzerklärung",
        "privacy.quick" : "Schnellzugriff",
        "privacy.manageConsents" : "Einwilligungen verwalten",
        "privacy.contact" : "Datenschutz-Kontakt",

        "consent.title" : "Einwilligungen",
        "consent.subtitle" : "Bestimme selbst, wie wir Daten für Analyse & Werbung nutzen.",
        "consent.notice" : "Du kannst deine Einwilligungen jederzeit mit Wirkung für die Zukunft widerrufen. Ohne Einwilligung nutzen wir nur technisch erforderliche Datenverarbeitungen.",
        "consent.analytics.title" : "Analytics (z. B. Nutzungsstatistiken)",
        "consent.analytics.subtitle" : "Hilft uns, die App zu verbessern. Keine personalisierte Werbung.",
        "consent.ads.title" : "Werbung (personalisierte Anzeigen)",
        "consent.ads.subtitle" : "Erfordert ggf. Datenübermittlung an Drittanbieter.",
        "consent.crash.title" : "Absturzberichte",
        "consent.crash.subtitle" : "Fehlerdiagnose & Stabilität (z. B. Crashlytics).",
        "consent.personal.title" : "Personalisierung",
        "consent.personal.subtitle" : "Individuelle Inhalte & Empfehlungen.",
        "consent.rejectAll" : "Alle ablehnen",
        "consent.acceptAll" : "Alle akzeptieren",
        "consent.lastUpdated" : "Zuletzt aktualisiert: %@",

        "about.title" : "Über die App",
        "about.subtitle" : "Das bekommst du mit %@",
        "about.card.benefits" : "Das bringt dir die App",
        "about.benefit.plan.title" : "Ein Wochenplan, der machbar ist",
        "about.benefit.plan.text" : "Klare Struktur von Warm-up über Übungen bis Cool-down. Dein Fortschritt speichert automatisch – Etappe für Etappe.",
        "about.benefit.challenges.title" : "Challenges & Badges, die ziehen",
        "about.benefit.challenges.text" : "Greifbare Ziele wie Workouts/Woche, Schritte, Weekly Volume & Streaks. Bronze, Silber, Gold – und ein Ring, der zeigt, wie nah du dran bist.",
        "about.benefit.rewards.title" : "Belohnungssystem mit Sog",
        "about.benefit.rewards.text" : "XP, Coins und Streaks nach jedem Workout. Sichtbare Level-Ups sorgen für das gute „Dranbleib-Gefühl“.",
        "about.benefit.steps.title" : "Alltagsbewegung zählt automatisch",
        "about.benefit.steps.text" : "Schritte aus Apple Health werden übernommen. Wochensummen & Zielstatus siehst du sogar direkt im Widget.",
        "about.benefit.achievements.title" : "Erfolge, die man sieht",
        "about.benefit.achievements.text" : "Pushs wie „Workout erledigt“ und „Schrittziel erreicht“. Zähler & Ringe machen kleine Siege groß.",
        "about.benefit.templates.title" : "Eigene Vorlagen in Minuten",
        "about.benefit.templates.text" : "Routine benennen, Übungen auswählen, speichern – fertig. Persönliche Trainings ohne Fummelei.",
        "about.support.title" : "Support",
        "about.support.email" : "Support per E-Mail",
        "badge.firstWorkout": "Erstes Workout",
        "badge.streak7": "7-Tage Streak",
        "badge.coinCollector": "Münzsammler",
        "badge.level5": "Level 5 erreicht",
        "gamification.title": "Dein Fortschritt",
        "gamification.badges.empty": "Noch keine Badges freigeschaltet",
        "steps.title": "Schritte",
        "steps.kpi.today": "Heute",
        "steps.kpi.avgPerDay": "Ø/Tag",
        "steps.kpi.best": "Best",
        "steps.kpi.goalDays": "Ziel-Tage",
        "steps.goal.title": "Ziel",
        "steps.dailyGoal": "Tagesziel",
        "steps.noDataRange": "Keine Schrittdaten im Zeitraum",
        "steps.noData": "Keine Daten",
        "steps.list.title": "Tage",
        "steps.menu.csvShare": "Als CSV teilen",
        "steps.menu.csvMake": "CSV erzeugen",
        "steps.menu.openHealth": "In Health öffnen",
        "common.ios16.required": "iOS 16 benötigt",
        "exercise.tapForDetails": "Tippe für Details",
        "exercise.muscleGroups": "Muskelgruppe(n)",
        "exercise.instructions": "Anleitung",
        "exercise.lastTraining": "Letztes Training",
        "exercise.volume.30d": "Volumen (30 Tage)",
        "exercise.recentSets": "Letzte Sätze",
        "exercise.chart.empty": "Noch keine Daten für den Verlauf",
        "exercise.noData.sets": "Noch keine Trainingsdaten vorhanden",
        "exercise.set.item": "Satz %d: %d Wdh",
        "exercise.badge.10trainings": "10× Training",
        "exercise.badge.newMax": "Neues Max",

        // Notes
        "notes.title": "Notizen",
        "notes.new": "Neue Notiz",
        "notes.empty": "Noch keine Notizen – füge die erste hinzu.",
        "notes.placeholder": "Notiz eingeben …",
        "notes.emptySingle": "Leere Notiz",
        "exercise.instructions.arnold_press_dumbbell": "Starte mit den Hanteln vor der Brust, drehe beim Hochdrücken die Handflächen nach vorn.",
        "exercise.instructions.back_extension_weight": "Halte zusätzlich ein Gewicht vor der Brust während der Rückenstreckung.",
        "exercise.instructions.bench_dip": "Stütze dich rücklings auf eine Bank, senke den Körper und drücke dich wieder hoch.",
        "exercise.instructions.bench_press_barbell": "Lege dich auf die Bank, greife die Langhantel schulterbreit und drücke sie hoch.",
        "exercise.instructions.bench_press_dumbbell": "Lege dich auf die Bank, halte Kurzhanteln und drücke sie gleichmäßig nach oben.",
        "exercise.instructions.bench_press_smith_machine": "Führe die Bankdrückbewegung in der geführten Langhantelmaschine aus.",
        "exercise.instructions.bench_press_close_grip_barbell": "Greife die Langhantel eng, senke sie zur Brust und drücke sie hoch.",
        "exercise.instructions.bench_press_wide_grip_barbell": "Greife die Langhantel weit, senke sie kontrolliert und drücke sie nach oben.",
        "exercise.instructions.bent_over_one_arm_row_dumbbell": "Stütze dich mit einer Hand ab, ziehe die Kurzhantel mit der anderen zum Körper.",
        "exercise.instructions.bent_over_row_barbell": "Beuge den Oberkörper nach vorn, ziehe die Langhantel zur Taille.",
        "exercise.instructions.bent_over_row_dumbbell": "Ziehe zwei Kurzhanteln gleichzeitig zur Hüfte bei vorgeneigtem Oberkörper.",
        "exercise.instructions.bent_over_row_underhand_barbell": "Greife die Langhantel im Untergriff und ziehe sie zum unteren Bauch.",
        "exercise.instructions.bicep_curl_barbell": "Halte die Langhantel schulterbreit und beuge die Arme kontrolliert.",
        "exercise.instructions.bicep_curl_cable": "Ziehe den Kabelgriff zur Brust mit gebeugten Ellenbogen.",
        "exercise.instructions.bicep_curl_dumbbell": "Halte Kurzhanteln an den Seiten und beuge die Arme kontrolliert nach oben.",
        "exercise.instructions.bicep_curl_machine": "Führe kontrollierte Curls mit der Maschine aus.",
        "exercise.instructions.biceps_curl_scottbank": "Lehne die Arme auf die Scottbank und führe Curls mit kontrollierter Bewegung aus.",
        "exercise.instructions.box_squat_barbell": "Senke dich mit einer Langhantel auf eine Box und stehe dann explosiv auf.",
        "exercise.instructions.bulgarian_split_squat": "Stelle ein Bein nach hinten auf eine Bank und führe einbeinige Kniebeugen aus.",
        "exercise.instructions.cable_crossover": "Ziehe beide Kabelzüge vor dem Körper zusammen auf Brusthöhe.",
        "exercise.instructions.cable_crunch": "Ziehe das Kabelseil nach unten, während du den Oberkörper beugst.",
        "exercise.instructions.cable_kickback": "Strecke das Bein nach hinten mit Kabelwiderstand.",
        "exercise.instructions.cable_pull_through": "Beuge dich vor und ziehe das Kabel durch die Beine nach vorn.",
        "exercise.instructions.cable_twist": "Ziehe das Kabel seitlich über den Körper zur anderen Seite.",
        "exercise.instructions.calf_press_on_leg_press": "Drücke das Gewicht mit den Zehen nach oben.",
        "exercise.instructions.calf_press_on_seated_leg_press": "Führe Wadenheben auf der sitzenden Beinpresse aus.",
        "exercise.instructions.chest_dip": "Senke den Körper an den Dip-Stangen ab und drücke dich wieder hoch.",
        "exercise.instructions.chest_fly_dumbbell": "Führe die Hanteln seitlich auseinander und wieder zusammen.",
        "exercise.instructions.chest_fly_kabel_oben": "Ziehe die Kabel von oben in einer Bogenbewegung zusammen.",
        "exercise.instructions.chest_fly_kabel_von_unten": "Ziehe die Kabel von unten nach oben zusammen.",
        "exercise.instructions.chest_press_machine": "Drücke die Griffe der Maschine gerade nach vorn.",
        "exercise.instructions.clean_barbell": "Ziehe die Langhantel vom Boden explosiv bis zu den Schultern.",
        "exercise.instructions.clean_and_jerk_barbell": "Führe Clean aus und stoße die Hantel anschließend über Kopf.",
        "exercise.instructions.concentration_curl_dumbbell": "Führe Bizepscurls mit dem Ellenbogen am Oberschenkel ausgeführt.",
        "exercise.instructions.crunch_machine": "Führe Crunches mit zusätzlichem Widerstand an der Maschine aus.",
        "exercise.instructions.deadlift_barbell": "Hebe die Langhantel mit geradem Rücken vom Boden an.",
        "exercise.instructions.deadlift_dumbbell": "Führe Kreuzheben mit Kurzhanteln neben den Beinen aus.",
        "exercise.instructions.deadlift_smith_machine": "Führe Kreuzheben mit der Smith-Maschine aus.",
        "exercise.instructions.decline_bench_press_barbell": "Lege dich auf eine Schrägbank und drücke die Langhantel nach oben.",
        "exercise.instructions.decline_bench_press_dumbbell": "Führe dieselbe Bewegung mit Kurzhanteln auf der Schrägbank aus.",
        "exercise.instructions.decline_bench_press_smith_machine": "Führe die Übung mit der Smith-Maschine auf der Schrägbank aus.",
        "exercise.instructions.deficit_deadlift_barbell": "Stelle dich erhöht und führe Kreuzheben für mehr Bewegungsumfang aus.",
        "exercise.instructions.dumbbell_row": "Ziehe die Kurzhantel mit gebeugtem Rücken zur Taille.",
        "exercise.instructions.dumbbell_shoulder_press": "Drücke die Kurzhanteln über den Kopf.",
        "exercise.instructions.ez_bar_curl": "Beuge die Arme mit der SZ-Stange kontrolliert.",
        "exercise.instructions.face_pull_cable": "Ziehe das Seil auf Augenhöhe zu deinem Gesicht.",
        "exercise.instructions.floor_press_barbell": "Lege dich auf den Boden und drücke die Langhantel nach oben.",
        "exercise.instructions.front_raise_plate": "Hebe eine Gewichtsscheibe vor den Körper auf Schulterhöhe.",
        "exercise.instructions.front_squat_barbell": "Lege die Langhantel auf die vordere Schulter und führe Kniebeugen aus.",
        "exercise.instructions.glute_kickback_machine": "Drücke das Bein nach hinten mit Hilfe der Maschine.",
        "exercise.instructions.goblet_squat_kettlebell": "Halte die Kettlebell vor der Brust und mache eine Kniebeuge.",
        "exercise.instructions.good_morning_barbell": "Beuge den Oberkörper nach vorn mit einer Langhantel auf den Schultern.",
        "exercise.instructions.hack_squat_machine": "Führe Kniebeugen in der Hackenschmidt-Maschine aus.",
        "exercise.instructions.hack_squat_barbell": "Halte die Langhantel hinter dem Körper und führe eine Kniebeuge aus.",
        "exercise.instructions.hammer_curl_band": "Führe den Curl mit neutralem Griff gegen den Widerstand des Bands aus.",
        "exercise.instructions.hammer_curl_cable": "Führe den Curl mit neutralem Griff am Kabelzug aus.",
        "exercise.instructions.hammer_curl_dumbbell": "Führe den Curl mit neutralem Griff mit Kurzhanteln aus.",
        "exercise.instructions.hang_clean_barbell": "Reiße die Langhantel explosiv aus dem Hang zur Schulter.",
        "exercise.instructions.hang_snatch_barbell": "Reiße die Langhantel aus dem Hang über den Kopf.",
        "exercise.instructions.high_pull_barbell": "Ziehe die Langhantel explosiv bis zur Brust.",
        "exercise.instructions.incline_bench_press_barbell": "Drücke die Langhantel schräg nach oben von der Bank.",
        "exercise.instructions.incline_bench_press_cable": "Führe Schrägbankdrücken mit Kabelzug aus.",
        "exercise.instructions.incline_bench_press_dumbbell": "Drücke die Kurzhanteln schräg nach oben.",
        "exercise.instructions.incline_bench_press_smith_machine": "Drücke die Stange der Smith-Maschine schräg nach oben.",
        "exercise.instructions.incline_chest_fly_dumbbell": "Führe Schrägbankfliegende mit Kurzhanteln aus.",
        "exercise.instructions.incline_chest_press_machine": "Drücke die Griffe der Maschine von der Schrägbank nach vorne.",
        "exercise.instructions.incline_curl_dumbbell": "Führe Bizepscurls auf der Schrägbank mit Kurzhanteln aus.",
        "exercise.instructions.incline_row_dumbbell": "Rudere mit Kurzhanteln auf einer schrägen Bank.",
        "exercise.instructions.inverted_row_bodyweight": "Ziehe dich unter einer Stange zum Körper hoch.",
        "exercise.instructions.iso_lateral_chest_press_machine": "Drücke die Griffe einzeln mit der Brustmuskulatur nach vorne.",
        "exercise.instructions.iso_lateral_row_machine": "Ziehe die Griffe einzeln zur Körpermitte.",
        "exercise.instructions.jump_shrug_barbell": "Springe leicht und ziehe die Schultern mit der Langhantel explosiv nach oben.",
        "exercise.instructions.jump_squat": "Mache eine explosive Kniebeuge mit einem Sprung nach oben.",
        "exercise.instructions.kettlebell_swing": "Schwinge die Kettlebell mit gestreckten Armen nach vorne.",
        "exercise.instructions.kettlebell_turkish_get_up": "Stehe kontrolliert mit einer Kettlebell über Kopf auf.",
        "exercise.instructions.klappmesser_crunch": "Berühre mit Händen und Füßen gleichzeitig in der Luft.",
        "exercise.instructions.knee_raise_captain_s_chair": "Ziehe die Knie im Hängesitz kontrolliert zur Brust.",
        "exercise.instructions.lat_pulldown_cable": "Ziehe die Stange zum oberen Brustbein.",
        "exercise.instructions.lat_pulldown_machine": "Ziehe die Griffe der Maschine kontrolliert nach unten.",
        "exercise.instructions.lat_pulldown_single_arm": "Ziehe einseitig mit Kabel oder Griff nach unten.",
        "exercise.instructions.lat_pulldown_underhand_band": "Ziehe das Widerstandsband im Untergriff nach unten.",
        "exercise.instructions.lat_pulldown_underhand_cable": "Ziehe die Stange mit Untergriff zum Brustbein.",
        "exercise.instructions.lat_pulldown_wide_grip_cable": "Ziehe die Stange mit breitem Griff nach unten.",
        "exercise.instructions.lateral_raise_band": "Hebe die Arme seitlich mit einem Widerstandsband.",
        "exercise.instructions.lateral_raise_dumbbell": "Hebe die Kurzhanteln seitlich auf Schulterhöhe.",
        "exercise.instructions.lateral_raise_machine": "Hebe die Arme seitlich mit der Maschine.",
        "exercise.instructions.leg_extension_machine": "Strecke die Beine an der Beinstreckmaschine.",
        "exercise.instructions.leg_press": "Drücke das Gewicht mit den Beinen weg.",
        "exercise.instructions.lunge_barbell": "Mache Ausfallschritte mit einer Langhantel.",
        "exercise.instructions.lunge_bodyweight": "Mache Ausfallschritte mit dem eigenen Körpergewicht.",
        "exercise.instructions.lunge_dumbbell": "Mache Ausfallschritte mit Kurzhanteln.",
        "exercise.instructions.lying_leg_curl_machine": "Beuge die Beine an der liegenden Beinbeugemaschine.",
        "exercise.instructions.overhead_press_barbell": "Drücke die Langhantel über den Kopf.",
        "exercise.instructions.overhead_press_cable": "Drücke das Kabelgewicht über den Kopf.",
        "exercise.instructions.overhead_press_dumbbell": "Drücke die Kurzhanteln über Kopf.",
        "exercise.instructions.overhead_press_smith_machine": "Drücke die Stange der Smith-Maschine über den Kopf.",
        "exercise.instructions.overhead_squat_barbell": "Führe eine Kniebeuge mit einer über Kopf gehaltenen Langhantel aus.",
        "exercise.instructions.pec_deck_machine": "Führe fliegende Bewegungen mit der Maschine aus.",
        "exercise.instructions.pendlay_row_barbell": "Rudere die Langhantel vom Boden mit explosiver Bewegung.",
        "exercise.instructions.pistol_squat": "Führe eine einbeinige Kniebeuge mit Kontrolle aus.",
        "exercise.instructions.power_clean_barbell": "Reiße die Langhantel in einer schnellen Bewegung zur Schulter.",
        "exercise.instructions.preacher_curl_barbell": "Führe Bizepscurls an der Scottbank mit der Langhantel aus.",
        "exercise.instructions.preacher_curl_machine": "Führe Bizepscurls an der Scott-Maschine aus.",
        "exercise.instructions.pull_up": "Ziehe dich mit einem Obergriff an einer Stange hoch.",
        "exercise.instructions.pull_up_assisted": "Ziehe dich mit Unterstützung an einer Stange hoch.",
        "exercise.instructions.pull_up_band": "Ziehe dich mit Hilfe eines Widerstandsbands an einer Stange hoch.",
        "exercise.instructions.pullover": "Senke das Gewicht hinter dem Kopf ab und bringe es wieder nach oben.",
        "exercise.instructions.pullover_dumbbell": "Führe die Bewegung mit einer Kurzhantel über dem Kopf aus.",
        "exercise.instructions.pullover_machine": "Führe den Pullover kontrolliert an der Maschine aus.",
        "exercise.instructions.push_press": "Drücke die Langhantel mit Schwung über den Kopf.",
        "exercise.instructions.push_up": "Drücke den Körper vom Boden nach oben.",
        "exercise.instructions.push_up_band": "Führe Liegestütze mit zusätzlichem Widerstandsband aus.",
        "exercise.instructions.push_up_knees": "Führe Liegestütze auf den Knien aus.",
        "exercise.instructions.rack_pull_barbell": "Hebe die Langhantel vom Rack in halber Deadlift-Position.",
        "exercise.instructions.reverse_crunch": "Ziehe die Beine zur Brust und hebe das Becken leicht an.",
        "exercise.instructions.reverse_curl_band": "Beuge die Arme mit Handrücken nach oben gegen ein Widerstandsband.",
        "exercise.instructions.reverse_curl_barbell": "Führe Curls mit der Langhantel im Obergriff aus.",
        "exercise.instructions.reverse_curl_dumbbell": "Führe Curls mit Kurzhanteln im Obergriff aus.",
        "exercise.instructions.reverse_fly_cable": "Ziehe die Kabelarme seitlich nach hinten.",
        "exercise.instructions.reverse_fly_dumbbell": "Führe fliegende Bewegungen mit Kurzhanteln zur Seite aus.",
        "exercise.instructions.reverse_fly_machine": "Ziehe die Griffe der Maschine seitlich nach hinten.",
        "exercise.instructions.romanian_deadlift_dumbbell": "Senke die Kurzhanteln mit gestreckten Beinen kontrolliert ab.",
        "exercise.instructions.rowing_machine": "Ziehe den Griff kontrolliert zur Körpermitte und lasse ihn zurück.",
        "exercise.instructions.running_treadmill": "Laufe auf dem Laufband mit gleichmäßigem Tempo.",
        "exercise.instructions.russian_twist": "Drehe den Oberkörper im Sitzen von Seite zu Seite.",
        "exercise.instructions.seated_calf_raise_machine": "Hebe die Fersen mit Widerstand an der Wadenmaschine.",
        "exercise.instructions.seated_calf_raise_plate_loaded": "Führe die Wadenübung mit Gewichtsscheiben aus.",
        "exercise.instructions.seated_leg_curl_machine": "Beuge die Beine an der sitzenden Beinbeugemaschine.",
        "exercise.instructions.seated_leg_press_machine": "Drücke das Gewicht mit den Beinen aus sitzender Position.",
        "exercise.instructions.seated_overhead_press_barbell": "Drücke die Langhantel über Kopf im Sitzen.",
        "exercise.instructions.seated_overhead_press_dumbbell": "Drücke die Kurzhanteln über Kopf im Sitzen.",
        "exercise.instructions.seated_palms_up_wrist_curl_dumbbell": "Rolle die Kurzhanteln mit Handflächen nach oben ein.",
        "exercise.instructions.seated_row_cable": "Ziehe das Kabel sitzend zur Körpermitte.",
        "exercise.instructions.seated_row_machine": "Ziehe die Griffe der Maschine zur Brust.",
        "exercise.instructions.seated_wide_grip_row_cable": "Ziehe das Kabel mit weitem Griff zur Brust.",
        "exercise.instructions.shoulder_press_machine": "Drücke die Griffe über den Kopf.",
        "exercise.instructions.shoulder_press_plate_loaded": "Drücke das Gewicht mit einer Plate-loaded-Maschine über Kopf.",
        "exercise.instructions.shoulder_press_dumbbells": "Drücke Kurzhanteln über Kopf.",
        "exercise.instructions.shrug_barbell": "Ziehe die Schultern mit der Langhantel nach oben.",
        "exercise.instructions.shrug_dumbbells": "Ziehe die Schultern mit Kurzhanteln nach oben.",
        "exercise.instructions.shrug_machine": "Ziehe die Griffe der Maschine mit den Schultern nach oben.",
        "exercise.instructions.shrug_smith_machine": "Führe Shrugs mit der Smith Machine aus.",
        "exercise.instructions.side_bend_cable": "Beuge dich seitlich mit Kabelzug.",
        "exercise.instructions.side_bend_dumbbell": "Beuge dich seitlich mit einer Kurzhantel.",
        "exercise.instructions.sit_up": "Rolle den Oberkörper bis zu den Knien auf.",
        "exercise.instructions.skullcrusher_barbell": "Senke die Langhantel zur Stirn und strecke die Arme wieder.",
        "exercise.instructions.skullcrusher_dumbbell": "Führe dieselbe Bewegung mit Kurzhanteln aus.",
        "exercise.instructions.snatch_barbell": "Ziehe die Langhantel explosiv über den Kopf.",
        "exercise.instructions.spider_curls": "Führe Bizepscurls in Bauchlage über einer Bank aus.",
        "exercise.instructions.split_jerk_barbell": "Stoße das Gewicht mit einem Ausfallschritt über den Kopf.",
        "exercise.instructions.squat_band": "Führe Kniebeugen mit Widerstandsband aus.",
        "exercise.instructions.squat_barbell": "Mache Kniebeugen mit der Langhantel auf dem Rücken.",
        "exercise.instructions.squat_bodyweight": "Mache Kniebeugen ohne zusätzliches Gewicht.",
        "exercise.instructions.squat_dumbbell": "Halte Kurzhanteln und mache Kniebeugen.",
        "exercise.instructions.squat_machine": "Führe Kniebeugen mit einer geführten Maschine aus.",
        "exercise.instructions.squat_smith_machine": "Führe Kniebeugen mit der Smith Machine aus.",
        "exercise.instructions.squat_row_band": "Kombiniere Kniebeugen mit Rudern gegen das Band.",
        "exercise.instructions.standing_calf_raise_barbell": "Hebe die Fersen mit Langhantel auf den Schultern.",
        "exercise.instructions.standing_calf_raise_bodyweight": "Hebe die Fersen ohne Zusatzgewicht.",
        "exercise.instructions.standing_calf_raise_dumbbell": "Hebe die Fersen mit Kurzhanteln.",
        "exercise.instructions.standing_calf_raise_machine": "Führe die Wadenübung an der Maschine stehend aus.",
        "exercise.instructions.standing_calf_raise_smith_machine": "Führe die Übung an der Smith Machine mit Gewicht aus.",
        "exercise.instructions.step_up": "Steige mit einem Bein auf eine Plattform und ziehe das andere nach.",
        "exercise.instructions.stiff_leg_deadlift_barbell": "Senke die Langhantel mit gestreckten Beinen kontrolliert.",
        "exercise.instructions.stiff_leg_deadlift_dumbbell": "Senke die Kurzhanteln mit gestreckten Beinen kontrolliert.",
        "exercise.instructions.stiff_leg_deadlift_band": "Senke den Oberkörper gegen den Widerstand des Bands.",
        "exercise.instructions.strict_military_press_barbell": "Drücke die Langhantel im Stehen streng über Kopf.",
        "exercise.instructions.sumo_deadlift_barbell": "Hebe das Gewicht mit breiter Beinstellung.",
        "exercise.instructions.sumo_deadlift_high_pull_barbell": "Kombiniere Sumo-Deadlift mit hohem Zug zur Brust.",
        "exercise.instructions.superman": "Hebe Arme und Beine gleichzeitig im Liegen an.",
        "exercise.instructions.supine_press": "Drücke das Gewicht im Liegen nach oben.",
        "exercise.instructions.sz_curl": "Führe Bizepscurls mit SZ-Stange aus.",
        "exercise.instructions.t_bar_row": "Ziehe das Gewicht mit neutralem Griff zur Körpermitte.",
        "exercise.instructions.thruster_barbell": "Kombiniere Front Squat mit Schulterdrücken.",
        "exercise.instructions.thruster_kettlebell": "Führe die Kombi aus Squat und Press mit Kettlebell aus.",
        "exercise.instructions.toes_to_bar": "Führe die Füße im Hang bis zur Stange.",
        "exercise.instructions.torso_rotation_machine": "Drehe den Oberkörper gegen den Widerstand der Maschine.",
        "exercise.instructions.trap_bar_deadlift": "Hebe das Gewicht mit der Trap Bar vom Boden.",
        "exercise.instructions.tricep_pushdown_single_handed": "Drücke das Kabelgriff einzeln nach unten.",
        "exercise.instructions.triceps_dip": "Drücke den Körper mit den Armen nach oben.",
        "exercise.instructions.triceps_dip_assisted": "Führe Dips mit Unterstützung an der Maschine aus.",
        "exercise.instructions.triceps_extension_barbell": "Strecke die Arme über Kopf mit der Langhantel.",
        "exercise.instructions.triceps_extension_cable": "Strecke die Arme mit dem Kabelzug.",
        "exercise.instructions.triceps_extension_dumbbell": "Strecke die Arme mit einer oder zwei Kurzhanteln.",
        "exercise.instructions.triceps_extension_machine": "Führe die Bewegung an der Maschine aus.",
        "exercise.instructions.triceps_extension": "Führe eine beliebige Trizepsstreckung aus.",
        "exercise.instructions.upright_row_barbell": "Ziehe die Langhantel eng am Körper nach oben.",
        "exercise.instructions.upright_row_cable": "Ziehe das Kabel eng am Körper nach oben.",
        "exercise.instructions.upright_row_dumbbell": "Ziehe Kurzhanteln eng am Körper nach oben.",
        "exercise.instructions.v_up": "Berühre Hände und Füße gleichzeitig in der Luft.",
        "exercise.instructions.wrist_roller": "Rolle ein Gewicht mit den Handgelenken nach oben.",
        "exercise.instructions.none": "Keine Anleitung verfügbar",

        "exercise.instructions.zercher_squat_barbell": "Halte die Langhantel in den Ellenbeugen und führe Kniebeugen aus.",
        // Zeit-Qualifier
        "time.perDay": "pro Tag",
        "time.perWeek": "pro Woche",

        // Streak
        "challenge.streak.title.format": "%d-Tage-Streak",
        "challenge.streak.desc.format": "Trainiere %d Tage hintereinander.",

        // Aktive Tage pro Woche
        "challenge.sessions.perWeek.format": "%d aktive Tage/Woche",
        "current": "Aktuell",
      


   
        
        
          "howto.header.subtitle": "Kurz & praxisnah – Ausführung, Atmung, Fehler, Varianten.",

          "howto.lottie.notFound.body": "Animation „%@“ nicht gefunden.",
          "howto.note.title": "Hinweis",
          "howto.note.noSource": "Keine Lottie-Quelle für „%@“ gefunden.",
          "howto.note.addFile": "Lege eine Datei „%@.lottie“ oder „%@.json“ ins Bundle.",

         
    

        /* Plank — Skalierung/Varianten */

          "howto.generic.setup.1": "Stabiler Stand/Unterlage, genug Platz und Licht.",
          "howto.generic.setup.2": "Aufwärmen und Bewegungsumfang prüfen.",
          "howto.generic.execution.1": "Bewegung kontrolliert und ohne Schwung ausführen.",
          "howto.generic.execution.2": "Neutraler Rücken, Gelenke in Linie halten.",
          "howto.generic.breathing.1": "Ruhig einatmen; in der Anstrengung ausatmen.",
          "howto.generic.breathing.2": "Nicht die Luft anhalten – gleichmäßig bleiben.",
          "howto.generic.mistakes.1": "Zu schnelle Wiederholungen / fehlende Kontrolle.",
          "howto.generic.mistakes.2": "In Schmerz hinein arbeiten statt Range anzupassen.",

          "howto.defaults.cardio.breathing.1": "Ruhig und rhythmisch atmen; nicht die Luft anhalten.",
          "howto.defaults.cardio.breathing.2": "In der Ausatmung weich landen und Spannung halten.",
          "howto.defaults.cardio.mistakes.1": "Zu hart landen – Fersen schlagen auf.",
          "howto.defaults.cardio.mistakes.2": "Oberkörper kippt stark nach vorn; Arme werden „vergessen“.",
          "howto.defaults.cardio.progressions.1": "Leichter: kürzere Intervalle (20–30s), geringere Sprunghöhe.",
          "howto.defaults.cardio.progressions.2": "Schwerer: längere Intervalle (45–60s), Tempo erhöhen.",
          "howto.defaults.cardio.cues.1": "Leise landen, Knie folgen den Zehen.",
          "howto.defaults.cardio.cues.2": "Arme aktiv mitnehmen (Taktgeber).",

          "howto.defaults.core.breathing.1": "Ruhig ein; in der Ausatmung Rippen runter & Core aktiv.",
          "howto.defaults.core.breathing.2": "Kein Pressen – gleichmäßig atmen.",
          "howto.defaults.core.mistakes.1": "Hohlkreuz / LWS hebt ab.",
          "howto.defaults.core.mistakes.2": "Am Kopf ziehen (bei Crunch-Varianten).",
          "howto.defaults.core.progressions.1": "Leichter: Hebel/Range verkürzen, kürzere Haltezeit.",
          "howto.defaults.core.progressions.2": "Schwerer: Hebel verlängern, einseitig, länger halten.",
          "howto.defaults.core.cues.1": "Rippen zu den Hüften, Nacken lang.",
          "howto.defaults.core.cues.2": "Bewegung aus dem Rumpf, nicht aus Schwung.",

          "howto.defaults.stretch.breathing.1": "Lang ausatmen und in die Dehnung „einschmelzen“.",
          "howto.defaults.stretch.breathing.2": "Nie in Schmerz hinein atmen, Range kontrolliert halten.",
          "howto.defaults.stretch.mistakes.1": "Mit Schwung federn; in Endränge drücken.",
          "howto.defaults.stretch.mistakes.2": "Ausweichbewegungen (Hohlkreuz, Schultern hochziehen).",
          "howto.defaults.stretch.progressions.1": "Leichter: kleinere Range, kürzere Haltezeit.",
          "howto.defaults.stretch.progressions.2": "Schwerer: Haltezeit verlängern, Winkel leicht intensivieren.",
          "howto.defaults.stretch.cues.1": "Rücken lang, Nacken weich.",
          "howto.defaults.stretch.cues.2": "Beckenposition steuert die Dehnintensität.",

          "howto.defaults.upperBack.breathing.1": "Ein beim Absenken, aus beim Aktivieren/Anheben.",
          "howto.defaults.upperBack.breathing.2": "Schulterblätter bewusst bewegen (Pro-/Retraction).",
          "howto.defaults.upperBack.mistakes.1": "Kopf in den Nacken; LWS überstrecken.",
          "howto.defaults.upperBack.mistakes.2": "Mit Schwung arbeiten statt kontrolliert.",
          "howto.defaults.upperBack.progressions.1": "Leichter: kleinere Range, kürzere Sätze.",
          "howto.defaults.upperBack.progressions.2": "Schwerer: längere Haltezeit, Tempo 3–1–1.",
          "howto.defaults.upperBack.cues.1": "Schulterblätter „in die Hosentaschen“.",
          "howto.defaults.upperBack.cues.2": "Arme lang, Nacken neutral.",

          "howto.defaults.push.breathing.1": "Ein beim Absenken, aus beim Hochdrücken.",
          "howto.defaults.push.breathing.2": "Core bracen, Rippen unten.",
          "howto.defaults.push.mistakes.1": "Ellenbogen zu weit außen (>60°).",
          "howto.defaults.push.mistakes.2": "Durchhängen in der Mitte (Hohlkreuz).",
          "howto.defaults.push.progressions.1": "Leichter: auf Knien; erhöhte Hände (Box/Bank).",
          "howto.defaults.push.progressions.2": "Schwerer: enger Stand, Tempo/Paused Reps, explosiv.",
          "howto.defaults.push.cues.1": "Schulterblätter breit, Unterarme senkrecht.",
          "howto.defaults.push.cues.2": "Drücke den Boden aktiv weg.",

          "howto.defaults.hinge.breathing.1": "Einatmen oben, ausatmen über die Anspannung nach oben.",
          "howto.defaults.hinge.breathing.2": "Bauchdruck aufbauen, Rücken lang.",
          "howto.defaults.hinge.mistakes.1": "Rundrücken; Knie wandern zu weit nach vorn.",
          "howto.defaults.hinge.mistakes.2": "Zu tiefe Range → Neutralität geht verloren.",
          "howto.defaults.hinge.progressions.1": "Leichter: kleinere Range, Hände an Hüfte (Feedback).",
          "howto.defaults.hinge.progressions.2": "Schwerer: Tempo 3–1–1; isometrischer Halt unten.",
          "howto.defaults.hinge.cues.1": "Hüfte nach hinten schieben, Krone lang nach vorn.",
          "howto.defaults.hinge.cues.2": "Gewicht über Mittelfuß/Ferse.",

          "howto.defaults.squat.breathing.1": "Ein beim Absenken, aus beim Aufrichten.",
          "howto.defaults.squat.breathing.2": "Optional kurzes Bracing vor dem Hochkommen.",
          "howto.defaults.squat.mistakes.1": "Knie kollabieren nach innen; Fersen heben ab.",
          "howto.defaults.squat.mistakes.2": "Zu schneller Richtungswechsel am Wendepunkt.",
          "howto.defaults.squat.progressions.1": "Leichter: Box Squat / Tiefe begrenzen.",
          "howto.defaults.squat.progressions.2": "Schwerer: Tempo/Paused Reps; Jump Squats.",
          "howto.defaults.squat.cues.1": "Knie zeigen in Zehenrichtung.",
          "howto.defaults.squat.cues.2": "Druck über Mittelfuß/Ferse.",

          "howto.defaults.lunge.breathing.1": "Ein beim Absenken, aus beim Aufrichten.",
          "howto.defaults.lunge.breathing.2": "Core stabil, Becken ruhig.",
          "howto.defaults.lunge.mistakes.1": "Vorderes Knie kippt nach innen.",
          "howto.defaults.lunge.mistakes.2": "Zu große Vorneige im Oberkörper.",
          "howto.defaults.lunge.progressions.1": "Leichter: kleinerer Schritt; Haltepunkt oben.",
          "howto.defaults.lunge.progressions.2": "Schwerer: Tempo/Paused; Sprungvarianten.",
          "howto.defaults.lunge.cues.1": "Lange Wirbelsäule, Blick neutral.",
          "howto.defaults.lunge.cues.2": "Druck über die vordere Ferse zurück.",

          "howto.defaults.strength.breathing.1": "Ruhig atmen; in der Anstrengung ausatmen.",
          "howto.defaults.strength.breathing.2": "Core aktiv für Stabilität.",
          "howto.defaults.strength.mistakes.1": "Schwung statt Kontrolle.",
          "howto.defaults.strength.mistakes.2": "Schmerz ignorieren statt Range anzupassen.",
          "howto.defaults.strength.progressions.1": "Leichter: Range/Lever reduzieren.",
          "howto.defaults.strength.progressions.2": "Schwerer: Hebel verlängern / Tempo verlangsamen.",
          "howto.defaults.strength.cues.1": "Bewegung flüssig, Gelenke neutral führen.",
          "howto.defaults.strength.cues.2": "Qualität vor Wiederholungszahl.",

          "howto.defaults.breathwork.breathing.1": "Nase ein, ruhig und länger durch den Mund aus.",
          "howto.defaults.breathwork.breathing.2": "Regelmäßiger Rhythmus, Schultern entspannt.",
          "howto.defaults.breathwork.mistakes.1": "Atem anhalten oder hecheln.",
          "howto.defaults.breathwork.mistakes.2": "Schultern hochziehen, Nacken verspannen.",
          "howto.defaults.breathwork.progressions.1": "Leichter: Zyklen verkürzen.",
          "howto.defaults.breathwork.progressions.2": "Schwerer: Zyklen verlängern (z. B. 4–6–6–4).",
          "howto.defaults.breathwork.cues.1": "Sanft, geräuscharm, gleichmäßig.",
          "howto.defaults.breathwork.cues.2": "Achtsamkeit auf Bauch- und Rippenbewegung.",

          "howto.title.jump_squats": "Sprungkniebeugen",
          "howto.title.kniebeugen": "Kniebeugen",
          "howto.title.plank": "Plank",

          "howto.jump_squats.ausfuehrung.1": "Aus Kniebeuge explosiv abspringen.",
        "howto.jump_squats.ausfuehrung.2": "Leise landen, Spannung halten.",
        

       

        
        
        // Einheiten
        
        
        /* Abschnittstitel */
        "howto.section.setup" : "Setup",
        "howto.section.ausfuehrung" : "Ausführung",
        "howto.section.atmung" : "Atmung",
        "howto.section.haeufige_fehler" : "Häufige Fehler",
        "howto.section.skalierung_varianten" : "Skalierung/Varianten",
        "howto.section.coaching_cues" : "Coaching Cues",
        "howto.section.hinweis" : "Hinweis",
        "howto.section.tempo" : "Tempo",
        "howto.section.power" : "Power",
        "howto.section.pattern" : "Pattern",
        "howto.section.progression" : "Progression",
        "howto.section.safety" : "Sicherheit",

        /* === Übungen === */

        /* Jumping Jacks */
        "howto.jumping_jacks.setup.1" : "Lockerer, athletischer Stand mit Platz um dich herum.",
        "howto.jumping_jacks.coaching_cues.1" : "Weich landen; gleichmäßiger Rhythmus.",
        "howto.jumping_jacks.coaching_cues.2" : "Arme unterstützen Takt und Haltung.",
        "howto.jumping_jacks.atmung.1" : "Ruhig und rhythmisch atmen.",
        "howto.jumping_jacks.atmung.2" : "In der Ausatmung weich landen.",
        "howto.jumping_jacks.haeufige_fehler.1" : "Hart auf den Fersen landen.",
        "howto.jumping_jacks.haeufige_fehler.2" : "Oberkörper kippt nach vorn; Arme „vergessen“.",
        "howto.jumping_jacks.haeufige_fehler.3" : "Atem anhalten bei höherem Tempo.",
        "howto.jumping_jacks.skalierung_varianten.1" : "Leichter: kürzere Intervalle (20–30 s) oder geringere Höhe/Tempo.",
        "howto.jumping_jacks.skalierung_varianten.2" : "Schwerer: längere Intervalle (45–60 s) oder höheres Tempo.",
        "howto.jumping_jacks.skalierung_varianten.3" : "Schwerer: Tempowechsel oder leichte Zusatzlast (wenn sicher).",

        /* High Knees */
        "howto.high_knees.setup.1" : "Lockerer, athletischer Stand mit Platz um dich herum.",
        "howto.high_knees.coaching_cues.1" : "Weich landen; gleichmäßiger Rhythmus.",
        "howto.high_knees.coaching_cues.2" : "Arme unterstützen Takt und Haltung.",
        "howto.high_knees.atmung.1" : "Ruhig und rhythmisch atmen.",
        "howto.high_knees.atmung.2" : "In der Ausatmung weich landen.",
        "howto.high_knees.haeufige_fehler.1" : "Hart auf den Fersen landen.",
        "howto.high_knees.haeufige_fehler.2" : "Oberkörper kippt nach vorn; Arme „vergessen“.",
        "howto.high_knees.haeufige_fehler.3" : "Atem anhalten bei höherem Tempo.",
        "howto.high_knees.skalierung_varianten.1" : "Leichter: kürzere Intervalle (20–30 s) oder geringere Höhe/Tempo.",
        "howto.high_knees.skalierung_varianten.2" : "Schwerer: längere Intervalle (45–60 s) oder höheres Tempo.",
        "howto.high_knees.skalierung_varianten.3" : "Schwerer: Tempowechsel oder leichte Zusatzlast (wenn sicher).",

        /* Butt Kicks */
        "howto.butt_kicks.setup.1" : "Lockerer, athletischer Stand mit Platz um dich herum.",
        "howto.butt_kicks.coaching_cues.1" : "Weich landen; gleichmäßiger Rhythmus.",
        "howto.butt_kicks.coaching_cues.2" : "Arme unterstützen Takt und Haltung.",
        "howto.butt_kicks.atmung.1" : "Ruhig und rhythmisch atmen.",
        "howto.butt_kicks.atmung.2" : "In der Ausatmung weich landen.",
        "howto.butt_kicks.haeufige_fehler.1" : "Hart auf den Fersen landen.",
        "howto.butt_kicks.haeufige_fehler.2" : "Oberkörper kippt nach vorn; Arme „vergessen“.",
        "howto.butt_kicks.haeufige_fehler.3" : "Atem anhalten bei höherem Tempo.",
        "howto.butt_kicks.skalierung_varianten.1" : "Leichter: kürzere Intervalle (20–30 s) oder geringere Höhe/Tempo.",
        "howto.butt_kicks.skalierung_varianten.2" : "Schwerer: längere Intervalle (45–60 s) oder höheres Tempo.",
        "howto.butt_kicks.skalierung_varianten.3" : "Schwerer: Tempowechsel oder leichte Zusatzlast (wenn sicher).",

        /* Burpees (leicht) */
        "howto.burpees_leicht.setup.1" : "Lockerer, athletischer Stand mit Platz um dich herum.",
        "howto.burpees_leicht.coaching_cues.1" : "Weich landen; gleichmäßiger Rhythmus.",
        "howto.burpees_leicht.coaching_cues.2" : "Arme unterstützen Takt und Haltung.",
        "howto.burpees_leicht.atmung.1" : "Ruhig und rhythmisch atmen.",
        "howto.burpees_leicht.atmung.2" : "In der Ausatmung weich landen.",
        "howto.burpees_leicht.haeufige_fehler.1" : "Hart auf den Fersen landen.",
        "howto.burpees_leicht.haeufige_fehler.2" : "Oberkörper kippt nach vorn; Arme „vergessen“.",
        "howto.burpees_leicht.haeufige_fehler.3" : "Atem anhalten bei höherem Tempo.",
        "howto.burpees_leicht.skalierung_varianten.1" : "Leichter: kürzere Intervalle (20–30 s) oder geringere Höhe/Tempo.",
        "howto.burpees_leicht.skalierung_varianten.2" : "Schwerer: längere Intervalle (45–60 s) oder höheres Tempo.",
        "howto.burpees_leicht.skalierung_varianten.3" : "Schwerer: Tempowechsel oder leichte Zusatzlast (wenn sicher).",

        /* Burpees */
        "howto.burpees.setup.1" : "Lockerer, athletischer Stand mit Platz um dich herum.",
        "howto.burpees.coaching_cues.1" : "Weich landen; gleichmäßiger Rhythmus.",
        "howto.burpees.coaching_cues.2" : "Arme unterstützen Takt und Haltung.",
        "howto.burpees.atmung.1" : "Ruhig und rhythmisch atmen.",
        "howto.burpees.atmung.2" : "In der Ausatmung weich landen.",
        "howto.burpees.haeufige_fehler.1" : "Hart auf den Fersen landen.",
        "howto.burpees.haeufige_fehler.2" : "Oberkörper kippt nach vorn; Arme „vergessen“.",
        "howto.burpees.haeufige_fehler.3" : "Atem anhalten bei höherem Tempo.",
        "howto.burpees.skalierung_varianten.1" : "Leichter: kürzere Intervalle (20–30 s) oder geringere Höhe/Tempo.",
        "howto.burpees.skalierung_varianten.2" : "Schwerer: längere Intervalle (45–60 s) oder höheres Tempo.",
        "howto.burpees.skalierung_varianten.3" : "Schwerer: Tempowechsel oder leichte Zusatzlast (wenn sicher).",

        /* Mountain Climbers */
        "howto.mountain_climbers.setup.1" : "Lockerer, athletischer Stand mit Platz um dich herum.",
        "howto.mountain_climbers.coaching_cues.1" : "Weich landen; gleichmäßiger Rhythmus.",
        "howto.mountain_climbers.coaching_cues.2" : "Arme unterstützen Takt und Haltung.",
        "howto.mountain_climbers.atmung.1" : "Ruhig und rhythmisch atmen.",
        "howto.mountain_climbers.atmung.2" : "In der Ausatmung weich landen.",
        "howto.mountain_climbers.haeufige_fehler.1" : "Hart auf den Fersen landen.",
        "howto.mountain_climbers.haeufige_fehler.2" : "Oberkörper kippt nach vorn; Arme „vergessen“.",
        "howto.mountain_climbers.haeufige_fehler.3" : "Atem anhalten bei höherem Tempo.",
        "howto.mountain_climbers.skalierung_varianten.1" : "Leichter: kürzere Intervalle (20–30 s) oder geringere Höhe/Tempo.",
        "howto.mountain_climbers.skalierung_varianten.2" : "Schwerer: längere Intervalle (45–60 s) oder höheres Tempo.",
        "howto.mountain_climbers.skalierung_varianten.3" : "Schwerer: Tempowechsel oder leichte Zusatzlast (wenn sicher).",

        /* Arm Circles */
        "howto.arm_circles.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.arm_circles.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.arm_circles.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.arm_circles.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.arm_circles.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.arm_circles.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.arm_circles.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.arm_circles.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.arm_circles.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.arm_circles.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.arm_circles.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Arm Circles rückwärts */
        "howto.arm_circles_rueckwaerts.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.arm_circles_rueckwaerts.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.arm_circles_rueckwaerts.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.arm_circles_rueckwaerts.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.arm_circles_rueckwaerts.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.arm_circles_rueckwaerts.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.arm_circles_rueckwaerts.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.arm_circles_rueckwaerts.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.arm_circles_rueckwaerts.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.arm_circles_rueckwaerts.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.arm_circles_rueckwaerts.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Arm Circles groß */
        "howto.arm_circles_gross.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.arm_circles_gross.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.arm_circles_gross.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.arm_circles_gross.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.arm_circles_gross.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.arm_circles_gross.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.arm_circles_gross.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.arm_circles_gross.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.arm_circles_gross.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.arm_circles_gross.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.arm_circles_gross.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Arm Swings */
        "howto.arm_swings.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.arm_swings.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.arm_swings.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.arm_swings.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.arm_swings.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.arm_swings.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.arm_swings.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.arm_swings.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.arm_swings.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.arm_swings.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.arm_swings.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Hip Opener */
        "howto.hip_opener.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.hip_opener.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.hip_opener.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.hip_opener.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.hip_opener.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.hip_opener.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.hip_opener.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.hip_opener.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.hip_opener.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.hip_opener.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.hip_opener.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Shoulder Stretch */
        "howto.shoulder_stretch.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.shoulder_stretch.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.shoulder_stretch.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.shoulder_stretch.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.shoulder_stretch.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.shoulder_stretch.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.shoulder_stretch.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.shoulder_stretch.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.shoulder_stretch.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.shoulder_stretch.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.shoulder_stretch.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Torso Twists */
        "howto.torso_twists.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.torso_twists.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.torso_twists.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.torso_twists.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.torso_twists.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.torso_twists.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.torso_twists.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.torso_twists.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.torso_twists.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.torso_twists.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.torso_twists.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Leichte Nacken- & Schulterkreise */
        "howto.leichte_nacken_und_schulterkreise.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.leichte_nacken_und_schulterkreise.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.leichte_nacken_und_schulterkreise.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.leichte_nacken_und_schulterkreise.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.leichte_nacken_und_schulterkreise.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.leichte_nacken_und_schulterkreise.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.leichte_nacken_und_schulterkreise.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.leichte_nacken_und_schulterkreise.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.leichte_nacken_und_schulterkreise.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.leichte_nacken_und_schulterkreise.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.leichte_nacken_und_schulterkreise.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Kniebeugen */
        "howto.kniebeugen.setup.1" : "Füße schulterbreit; Zehen leicht außen; Brust stolz.",
        "howto.kniebeugen.coaching_cues.1" : "Knie in Zehenrichtung führen.",
        "howto.kniebeugen.coaching_cues.2" : "Druck über Mittelfuß/Ferse, aufrecht bleiben.",
        "howto.kniebeugen.atmung.1" : "Ein beim Absenken, aus beim Aufrichten.",
        "howto.kniebeugen.atmung.2" : "Optional kurzes Bracing vor dem Hochkommen.",
        "howto.kniebeugen.haeufige_fehler.1" : "Knie kollabieren nach innen; Fersen heben ab.",
        "howto.kniebeugen.haeufige_fehler.2" : "Starke Vorneige im Oberkörper.",
        "howto.kniebeugen.haeufige_fehler.3" : "Zu schneller Richtungswechsel unten.",
        "howto.kniebeugen.skalierung_varianten.1" : "Leichter: Box Squat / Tiefe begrenzen.",
        "howto.kniebeugen.skalierung_varianten.2" : "Schwerer: Tempo- oder Pausenwiederholungen.",
        "howto.kniebeugen.skalierung_varianten.3" : "Schwerer: Jump Squats oder Zusatzlast.",

        /* Ausfallschritte */
        "howto.ausfallschritte.setup.1" : "Langer Schrittsand; Oberkörper aufrecht, Hüfte gerade.",
        "howto.ausfallschritte.coaching_cues.1" : "Vorderes Knie folgt den Zehen.",
        "howto.ausfallschritte.coaching_cues.2" : "Über die vordere Ferse zurückdrücken.",
        "howto.ausfallschritte.atmung.1" : "Ein beim Absenken, aus beim Aufrichten.",
        "howto.ausfallschritte.atmung.2" : "Core stabil; Becken ruhig.",
        "howto.ausfallschritte.haeufige_fehler.1" : "Vorderes Knie kippt nach innen.",
        "howto.ausfallschritte.haeufige_fehler.2" : "Oberkörper zu weit nach vorn geneigt.",
        "howto.ausfallschritte.haeufige_fehler.3" : "Zu kurze, enge Schritte.",
        "howto.ausfallschritte.skalierung_varianten.1" : "Leichter: kürzerer Schritt oder kurze Pause oben.",
        "howto.ausfallschritte.skalierung_varianten.2" : "Schwerer: Tempo-/Pause-Reps.",
        "howto.ausfallschritte.skalierung_varianten.3" : "Schwerer: Sprungausfallschritte (falls verträglich).",

        /* Side Lunges */
        "howto.side_lunges.setup.1" : "Langer Schrittsand; Oberkörper aufrecht, Hüfte gerade.",
        "howto.side_lunges.coaching_cues.1" : "Vorderes Knie folgt den Zehen.",
        "howto.side_lunges.coaching_cues.2" : "Über die vordere Ferse zurückdrücken.",
        "howto.side_lunges.atmung.1" : "Ein beim Absenken, aus beim Aufrichten.",
        "howto.side_lunges.atmung.2" : "Core stabil; Becken ruhig.",
        "howto.side_lunges.haeufige_fehler.1" : "Vorderes Knie kippt nach innen.",
        "howto.side_lunges.haeufige_fehler.2" : "Oberkörper zu weit nach vorn geneigt.",
        "howto.side_lunges.haeufige_fehler.3" : "Zu kurze, enge Schritte.",
        "howto.side_lunges.skalierung_varianten.1" : "Leichter: kürzerer Schritt oder kurze Pause oben.",
        "howto.side_lunges.skalierung_varianten.2" : "Schwerer: Tempo-/Pause-Reps.",
        "howto.side_lunges.skalierung_varianten.3" : "Schwerer: Sprungausfallschritte (falls verträglich).",

        /* Bulgarian Split Squats (ohne Erhöhung) */
        "howto.bulgarian_split_squats_ohne_erhoehung.setup.1" : "Füße schulterbreit; Zehen leicht außen; Brust stolz.",
        "howto.bulgarian_split_squats_ohne_erhoehung.coaching_cues.1" : "Knie in Zehenrichtung führen.",
        "howto.bulgarian_split_squats_ohne_erhoehung.coaching_cues.2" : "Druck über Mittelfuß/Ferse, aufrecht bleiben.",
        "howto.bulgarian_split_squats_ohne_erhoehung.atmung.1" : "Ein beim Absenken, aus beim Aufrichten.",
        "howto.bulgarian_split_squats_ohne_erhoehung.atmung.2" : "Optional kurzes Bracing vor dem Hochkommen.",
        "howto.bulgarian_split_squats_ohne_erhoehung.haeufige_fehler.1" : "Knie kollabieren nach innen; Fersen heben ab.",
        "howto.bulgarian_split_squats_ohne_erhoehung.haeufige_fehler.2" : "Starke Vorneige im Oberkörper.",
        "howto.bulgarian_split_squats_ohne_erhoehung.haeufige_fehler.3" : "Zu schneller Richtungswechsel unten.",
        "howto.bulgarian_split_squats_ohne_erhoehung.skalierung_varianten.1" : "Leichter: Box Squat / Tiefe begrenzen.",
        "howto.bulgarian_split_squats_ohne_erhoehung.skalierung_varianten.2" : "Schwerer: Tempo- oder Pausenwiederholungen.",
        "howto.bulgarian_split_squats_ohne_erhoehung.skalierung_varianten.3" : "Schwerer: Jump Squats oder Zusatzlast.",

        /* Jump Squats */
        "howto.jump_squats.setup.1" : "Füße schulterbreit; Zehen leicht außen; Brust stolz.",
        "howto.jump_squats.coaching_cues.1" : "Knie in Zehenrichtung führen.",
        "howto.jump_squats.coaching_cues.2" : "Druck über Mittelfuß/Ferse, aufrecht bleiben.",
        "howto.jump_squats.atmung.1" : "Ein beim Absenken, aus beim Aufrichten.",
        "howto.jump_squats.atmung.2" : "Optional kurzes Bracing vor dem Hochkommen.",
        "howto.jump_squats.haeufige_fehler.1" : "Knie kollabieren nach innen; Fersen heben ab.",
        "howto.jump_squats.haeufige_fehler.2" : "Starke Vorneige im Oberkörper.",
        "howto.jump_squats.haeufige_fehler.3" : "Zu schneller Richtungswechsel unten.",
        "howto.jump_squats.skalierung_varianten.1" : "Leichter: Box Squat / Tiefe begrenzen.",
        "howto.jump_squats.skalierung_varianten.2" : "Schwerer: Tempo- oder Pausenwiederholungen.",
        "howto.jump_squats.skalierung_varianten.3" : "Schwerer: Jump Squats oder Zusatzlast.",

        /* Hip Hinge / Good Mornings */
        "howto.hip_hinge_good_mornings.setup.1" : "Füße hüftbreit; Hüfte nach hinten schieben, Rücken lang.",
        "howto.hip_hinge_good_mornings.coaching_cues.1" : "Bewegung aus der Hüfte, nicht aus den Knien.",
        "howto.hip_hinge_good_mornings.coaching_cues.2" : "Gewicht über Mittelfuß/Ferse halten.",
        "howto.hip_hinge_good_mornings.atmung.1" : "Einatmen oben; ausatmen über die Anspannung nach oben.",
        "howto.hip_hinge_good_mornings.atmung.2" : "Bauchdruck aufbauen; Rücken lang.",
        "howto.hip_hinge_good_mornings.haeufige_fehler.1" : "Rundrücken; Knie wandern zu weit nach vorn.",
        "howto.hip_hinge_good_mornings.haeufige_fehler.2" : "Zu tiefe Range – Neutralität geht verloren.",
        "howto.hip_hinge_good_mornings.haeufige_fehler.3" : "Nacken überstreckt.",
        "howto.hip_hinge_good_mornings.skalierung_varianten.1" : "Leichter: Range verkleinern; Hände an Hüfte (Feedback).",
        "howto.hip_hinge_good_mornings.skalierung_varianten.2" : "Schwerer: Tempo 3–1–1 oder isometrisch unten halten.",
        "howto.hip_hinge_good_mornings.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern vorhanden.",

        /* Good Mornings (langsam) */
        "howto.good_mornings_langsam.setup.1" : "Füße hüftbreit; Hüfte nach hinten schieben, Rücken lang.",
        "howto.good_mornings_langsam.coaching_cues.1" : "Bewegung aus der Hüfte, nicht aus den Knien.",
        "howto.good_mornings_langsam.coaching_cues.2" : "Gewicht über Mittelfuß/Ferse halten.",
        "howto.good_mornings_langsam.atmung.1" : "Einatmen oben; ausatmen über die Anspannung nach oben.",
        "howto.good_mornings_langsam.atmung.2" : "Bauchdruck aufbauen; Rücken lang.",
        "howto.good_mornings_langsam.haeufige_fehler.1" : "Rundrücken; Knie wandern zu weit nach vorn.",
        "howto.good_mornings_langsam.haeufige_fehler.2" : "Zu tiefe Range – Neutralität geht verloren.",
        "howto.good_mornings_langsam.haeufige_fehler.3" : "Nacken überstreckt.",
        "howto.good_mornings_langsam.skalierung_varianten.1" : "Leichter: Range verkleinern; Hände an Hüfte (Feedback).",
        "howto.good_mornings_langsam.skalierung_varianten.2" : "Schwerer: Tempo 3–1–1 oder isometrisch unten halten.",
        "howto.good_mornings_langsam.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern vorhanden.",

        /* Liegestütze */
        "howto.liegestuetze.setup.1" : "Hände unter/leicht außerhalb der Schultern; Körper in Linie.",
        "howto.liegestuetze.coaching_cues.1" : "Ellenbogen ~45°, Unterarme senkrecht.",
        "howto.liegestuetze.coaching_cues.2" : "Boden aktiv wegdrücken; Rippen unten.",
        "howto.liegestuetze.atmung.1" : "Ein beim Absenken, aus beim Hochdrücken.",
        "howto.liegestuetze.atmung.2" : "Core bracen; kein Aufspreizen.",
        "howto.liegestuetze.haeufige_fehler.1" : "Ellenbogen zu weit außen.",
        "howto.liegestuetze.haeufige_fehler.2" : "Durchhängen im Rumpf (Hohlkreuz).",
        "howto.liegestuetze.haeufige_fehler.3" : "Kopf schiebt vor / Nacken verliert Linie.",
        "howto.liegestuetze.skalierung_varianten.1" : "Leichter: Knie am Boden oder Hände erhöht.",
        "howto.liegestuetze.skalierung_varianten.2" : "Schwerer: Tempo-/Pause-Reps; engerer Stand.",
        "howto.liegestuetze.skalierung_varianten.3" : "Schwerer: explosiv/Klatschen oder Defizit-Liegestütze.",

        /* Enge Liegestütze (Trizeps) */
        "howto.enge_liegestuetze_trizeps.setup.1" : "Hände unter/leicht außerhalb der Schultern; Körper in Linie.",
        "howto.enge_liegestuetze_trizeps.coaching_cues.1" : "Ellenbogen ~45°, Unterarme senkrecht.",
        "howto.enge_liegestuetze_trizeps.coaching_cues.2" : "Boden aktiv wegdrücken; Rippen unten.",
        "howto.enge_liegestuetze_trizeps.atmung.1" : "Ein beim Absenken, aus beim Hochdrücken.",
        "howto.enge_liegestuetze_trizeps.atmung.2" : "Core bracen; kein Aufspreizen.",
        "howto.enge_liegestuetze_trizeps.haeufige_fehler.1" : "Ellenbogen zu weit außen.",
        "howto.enge_liegestuetze_trizeps.haeufige_fehler.2" : "Durchhängen im Rumpf (Hohlkreuz).",
        "howto.enge_liegestuetze_trizeps.haeufige_fehler.3" : "Kopf schiebt vor / Nacken verliert Linie.",
        "howto.enge_liegestuetze_trizeps.skalierung_varianten.1" : "Leichter: Knie am Boden oder Hände erhöht.",
        "howto.enge_liegestuetze_trizeps.skalierung_varianten.2" : "Schwerer: Tempo-/Pause-Reps; engerer Stand.",
        "howto.enge_liegestuetze_trizeps.skalierung_varianten.3" : "Schwerer: explosiv/Klatschen oder Defizit-Liegestütze.",

        /* Liegestütze (Tempo 3-1-1) */
        "howto.liegestuetze_tempo_3_1_1.setup.1" : "Hände unter/leicht außerhalb der Schultern; Körper in Linie.",
        "howto.liegestuetze_tempo_3_1_1.coaching_cues.1" : "Ellenbogen ~45°, Unterarme senkrecht.",
        "howto.liegestuetze_tempo_3_1_1.coaching_cues.2" : "Boden aktiv wegdrücken; Rippen unten.",
        "howto.liegestuetze_tempo_3_1_1.atmung.1" : "Ein beim Absenken, aus beim Hochdrücken.",
        "howto.liegestuetze_tempo_3_1_1.atmung.2" : "Core bracen; kein Aufspreizen.",
        "howto.liegestuetze_tempo_3_1_1.haeufige_fehler.1" : "Ellenbogen zu weit außen.",
        "howto.liegestuetze_tempo_3_1_1.haeufige_fehler.2" : "Durchhängen im Rumpf (Hohlkreuz).",
        "howto.liegestuetze_tempo_3_1_1.haeufige_fehler.3" : "Kopf schiebt vor / Nacken verliert Linie.",
        "howto.liegestuetze_tempo_3_1_1.skalierung_varianten.1" : "Leichter: Knie am Boden oder Hände erhöht.",
        "howto.liegestuetze_tempo_3_1_1.skalierung_varianten.2" : "Schwerer: Tempo-/Pause-Reps; engerer Stand.",
        "howto.liegestuetze_tempo_3_1_1.skalierung_varianten.3" : "Schwerer: explosiv/Klatschen oder Defizit-Liegestütze.",

        /* Liegestütze mit Klatschen */
        "howto.liegestuetze_mit_klatschen.setup.1" : "Hände unter/leicht außerhalb der Schultern; Körper in Linie.",
        "howto.liegestuetze_mit_klatschen.coaching_cues.1" : "Ellenbogen ~45°, Unterarme senkrecht.",
        "howto.liegestuetze_mit_klatschen.coaching_cues.2" : "Boden aktiv wegdrücken; Rippen unten.",
        "howto.liegestuetze_mit_klatschen.atmung.1" : "Ein beim Absenken, aus beim Hochdrücken.",
        "howto.liegestuetze_mit_klatschen.atmung.2" : "Core bracen; kein Aufspreizen.",
        "howto.liegestuetze_mit_klatschen.haeufige_fehler.1" : "Ellenbogen zu weit außen.",
        "howto.liegestuetze_mit_klatschen.haeufige_fehler.2" : "Durchhängen im Rumpf (Hohlkreuz).",
        "howto.liegestuetze_mit_klatschen.haeufige_fehler.3" : "Kopf schiebt vor / Nacken verliert Linie.",
        "howto.liegestuetze_mit_klatschen.skalierung_varianten.1" : "Leichter: Knie am Boden oder Hände erhöht.",
        "howto.liegestuetze_mit_klatschen.skalierung_varianten.2" : "Schwerer: Tempo-/Pause-Reps; engerer Stand.",
        "howto.liegestuetze_mit_klatschen.skalierung_varianten.3" : "Schwerer: explosiv/Klatschen oder Defizit-Liegestütze.",

        /* Pike Push-ups */
        "howto.pike_push_ups.setup.1" : "Hände unter/leicht außerhalb der Schultern; Körper in Linie.",
        "howto.pike_push_ups.coaching_cues.1" : "Ellenbogen ~45°, Unterarme senkrecht.",
        "howto.pike_push_ups.coaching_cues.2" : "Boden aktiv wegdrücken; Rippen unten.",
        "howto.pike_push_ups.atmung.1" : "Ein beim Absenken, aus beim Hochdrücken.",
        "howto.pike_push_ups.atmung.2" : "Core bracen; kein Aufspreizen.",
        "howto.pike_push_ups.haeufige_fehler.1" : "Ellenbogen zu weit außen.",
        "howto.pike_push_ups.haeufige_fehler.2" : "Durchhängen im Rumpf (Hohlkreuz).",
        "howto.pike_push_ups.haeufige_fehler.3" : "Kopf schiebt vor / Nacken verliert Linie.",
        "howto.pike_push_ups.skalierung_varianten.1" : "Leichter: Knie am Boden oder Hände erhöht.",
        "howto.pike_push_ups.skalierung_varianten.2" : "Schwerer: Tempo-/Pause-Reps; engerer Stand.",
        "howto.pike_push_ups.skalierung_varianten.3" : "Schwerer: explosiv/Klatschen oder Defizit-Liegestütze.",

        /* Plank mit Schulter-Taps */
        "howto.plank_mit_schulter_taps.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.plank_mit_schulter_taps.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.plank_mit_schulter_taps.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.plank_mit_schulter_taps.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.plank_mit_schulter_taps.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.plank_mit_schulter_taps.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.plank_mit_schulter_taps.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.plank_mit_schulter_taps.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.plank_mit_schulter_taps.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.plank_mit_schulter_taps.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.plank_mit_schulter_taps.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        /* Superman Pulls */
        "howto.superman_pulls.setup.1" : "Bauchlage oder Stand mit freier Schulterbewegung.",
        "howto.superman_pulls.coaching_cues.1" : "Schulterblätter nach hinten/unten („in die Hosentaschen“).",
        "howto.superman_pulls.coaching_cues.2" : "Arme lang, Nacken neutral.",
        "howto.superman_pulls.atmung.1" : "Ein beim Absenken, aus beim Aktivieren.",
        "howto.superman_pulls.atmung.2" : "Schulterblätter bewusst führen.",
        "howto.superman_pulls.haeufige_fehler.1" : "Kopf in den Nacken / LWS überstrecken.",
        "howto.superman_pulls.haeufige_fehler.2" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.superman_pulls.haeufige_fehler.3" : "Schultern zu den Ohren ziehen.",
        "howto.superman_pulls.skalierung_varianten.1" : "Leichter: kürzere Sätze oder kleinere Range.",
        "howto.superman_pulls.skalierung_varianten.2" : "Schwerer: längere Haltezeit; Tempo 3–1–1.",
        "howto.superman_pulls.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Bandzug.",

        /* Superman Hold */
        "howto.superman_hold.setup.1" : "Bauchlage oder Stand mit freier Schulterbewegung.",
        "howto.superman_hold.coaching_cues.1" : "Schulterblätter nach hinten/unten („in die Hosentaschen“).",
        "howto.superman_hold.coaching_cues.2" : "Arme lang, Nacken neutral.",
        "howto.superman_hold.atmung.1" : "Ein beim Absenken, aus beim Aktivieren.",
        "howto.superman_hold.atmung.2" : "Schulterblätter bewusst führen.",
        "howto.superman_hold.haeufige_fehler.1" : "Kopf in den Nacken / LWS überstrecken.",
        "howto.superman_hold.haeufige_fehler.2" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.superman_hold.haeufige_fehler.3" : "Schultern zu den Ohren ziehen.",
        "howto.superman_hold.skalierung_varianten.1" : "Leichter: kürzere Sätze oder kleinere Range.",
        "howto.superman_hold.skalierung_varianten.2" : "Schwerer: längere Haltezeit; Tempo 3–1–1.",
        "howto.superman_hold.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Bandzug.",
        
        
        "water.title" : "Wasseraufnahme",
        "water.unit" : "Wasser",
        "unit.ml" : "ml",

        "water.progressOfGoal" : "%d%% von %d ml Ziel",
        "water.hydrationTrend" : "Hydration-Verlauf",
        "water.noData.title" : "Keine Daten",
        "water.noData.description" : "Beginne, deine Wasseraufnahme zu tracken!",

        "water.goalsHit.title" : "Ziele erreicht",
        "water.goalsHit.value" : "%d von %d Tagen",

        "water.dailyGoal" : "Tagesziel",
        "water.goal.target" : "Ziel",
        "water.quickAdd" : "+%d ml",
        "water.undo.step" : "Rückgängig (-%d ml)",

     
        "statistics.today" : "Heute",

     
        
        
        /* Execution-Aliasse für alle Übungen */

        /* Jumping Jacks */
        "howto.jumping_jacks.execution.1" : "Brust offen, aufrecht bleiben; Arme aktiv mitnehmen.",
        "howto.jumping_jacks.execution.2" : "Weich auf dem Vorfuß landen; gleichmäßiger Rhythmus.",

        /* High Knees */
        "howto.high_knees.execution.1" : "Brust offen, aufrecht bleiben; Arme aktiv mitnehmen.",
        "howto.high_knees.execution.2" : "Weich auf dem Vorfuß landen; gleichmäßiger Rhythmus.",

        /* Butt Kicks */
        "howto.butt_kicks.execution.1" : "Brust offen, aufrecht bleiben; Arme aktiv mitnehmen.",
        "howto.butt_kicks.execution.2" : "Weich auf dem Vorfuß landen; gleichmäßiger Rhythmus.",

        /* Burpees (leicht) */
        "howto.burpees_leicht.execution.1" : "Brust offen, aufrecht bleiben; Arme aktiv mitnehmen.",
        "howto.burpees_leicht.execution.2" : "Weich auf dem Vorfuß landen; gleichmäßiger Rhythmus.",

        /* Burpees */
        "howto.burpees.execution.1" : "Brust offen, aufrecht bleiben; Arme aktiv mitnehmen.",
        "howto.burpees.execution.2" : "Weich auf dem Vorfuß landen; gleichmäßiger Rhythmus.",

        /* Mountain Climbers */
        "howto.mountain_climbers.execution.1" : "Brust offen, aufrecht bleiben; Arme aktiv mitnehmen.",
        "howto.mountain_climbers.execution.2" : "Weich auf dem Vorfuß landen; gleichmäßiger Rhythmus.",

        /* Arm Circles */
        "howto.arm_circles.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.arm_circles.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Arm Circles rückwärts */
        "howto.arm_circles_rueckwaerts.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.arm_circles_rueckwaerts.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Arm Circles groß */
        "howto.arm_circles_gross.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.arm_circles_gross.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Arm Swings */
        "howto.arm_swings.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.arm_swings.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Hip Opener */
        "howto.hip_opener.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.hip_opener.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Shoulder Stretch */
        "howto.shoulder_stretch.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.shoulder_stretch.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Torso Twists */
        "howto.torso_twists.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.torso_twists.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Leichte Nacken- & Schulterkreise */
        "howto.leichte_nacken_und_schulterkreise.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.leichte_nacken_und_schulterkreise.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Kniebeugen */
        "howto.kniebeugen.execution.1" : "Hüfte nach hinten/unten setzen; Knie folgen den Zehen.",
        "howto.kniebeugen.execution.2" : "Über Mittelfuß/Ferse aufrichten; aufrecht bleiben.",

        /* Ausfallschritte */
        "howto.ausfallschritte.execution.1" : "Langen Schritt setzen; absenken bis beide Knie etwa 90° erreichen.",
        "howto.ausfallschritte.execution.2" : "Über die vordere Ferse hochdrücken; Oberkörper aufrecht halten.",

        /* Side Lunges */
        "howto.side_lunges.execution.1" : "Langen Schritt setzen; absenken bis beide Knie etwa 90° erreichen.",
        "howto.side_lunges.execution.2" : "Über die vordere Ferse hochdrücken; Oberkörper aufrecht halten.",

        /* Bulgarian Split Squats (ohne Erhöhung) */
        "howto.bulgarian_split_squats_ohne_erhoehung.execution.1" : "Hüfte nach hinten/unten setzen; Knie folgen den Zehen.",
        "howto.bulgarian_split_squats_ohne_erhoehung.execution.2" : "Über Mittelfuß/Ferse aufrichten; aufrecht bleiben.",

        /* Jump Squats */
        "howto.jump_squats.execution.1" : "Hüfte nach hinten/unten setzen; Knie folgen den Zehen.",
        "howto.jump_squats.execution.2" : "Über Mittelfuß/Ferse aufrichten; aufrecht bleiben.",

        /* Hip Hinge / Good Mornings */
        "howto.hip_hinge_good_mornings.execution.1" : "Mit der Hüfte nach hinten einleiten; Schienbeine relativ senkrecht.",
        "howto.hip_hinge_good_mornings.execution.2" : "Über die Fersen aufrichten; Rücken bleibt lang.",

        /* Good Mornings (langsam) */
        "howto.good_mornings_langsam.execution.1" : "Mit der Hüfte nach hinten einleiten; Schienbeine relativ senkrecht.",
        "howto.good_mornings_langsam.execution.2" : "Über die Fersen aufrichten; Rücken bleibt lang.",

        /* Liegestütze */
        "howto.liegestuetze.execution.1" : "Kontrolliert absenken, Ellenbogen ca. 45°.",
        "howto.liegestuetze.execution.2" : "Den Boden aktiv wegdrücken; Körper in Linie halten.",

        /* Enge Liegestütze (Trizeps) */
        "howto.enge_liegestuetze_trizeps.execution.1" : "Kontrolliert absenken, Ellenbogen ca. 45°.",
        "howto.enge_liegestuetze_trizeps.execution.2" : "Den Boden aktiv wegdrücken; Körper in Linie halten.",

        /* Liegestütze (Tempo 3-1-1) */
        "howto.liegestuetze_tempo_3_1_1.execution.1" : "Kontrolliert absenken, Ellenbogen ca. 45°.",
        "howto.liegestuetze_tempo_3_1_1.execution.2" : "Den Boden aktiv wegdrücken; Körper in Linie halten.",

        /* Liegestütze mit Klatschen */
        "howto.liegestuetze_mit_klatschen.execution.1" : "Kontrolliert absenken, Ellenbogen ca. 45°.",
        "howto.liegestuetze_mit_klatschen.execution.2" : "Den Boden aktiv wegdrücken; Körper in Linie halten.",

        /* Pike Push-ups */
        "howto.pike_push_ups.execution.1" : "Kontrolliert absenken, Ellenbogen ca. 45°.",
        "howto.pike_push_ups.execution.2" : "Den Boden aktiv wegdrücken; Körper in Linie halten.",

        /* Plank mit Schulter-Taps */
        "howto.plank_mit_schulter_taps.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.plank_mit_schulter_taps.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Superman Pulls */
        "howto.superman_pulls.execution.1" : "Über den oberen Rücken anheben; Schulterblätter nach hinten/unten ziehen.",
        "howto.superman_pulls.execution.2" : "Blick zum Boden; Nacken durchgehend neutral.",

        /* Superman Hold */
        "howto.superman_hold.execution.1" : "Über den oberen Rücken anheben; Schulterblätter nach hinten/unten ziehen.",
        "howto.superman_hold.execution.2" : "Blick zum Boden; Nacken durchgehend neutral.",

        /* Prone W-Raises */
        "howto.prone_w_raises.execution.1" : "Über den oberen Rücken anheben; Schulterblätter nach hinten/unten ziehen.",
        "howto.prone_w_raises.execution.2" : "Blick zum Boden; Nacken durchgehend neutral.",

        /* Reverse Snow Angels */
        "howto.reverse_snow_angels.execution.1" : "Über den oberen Rücken anheben; Schulterblätter nach hinten/unten ziehen.",
        "howto.reverse_snow_angels.execution.2" : "Blick zum Boden; Nacken durchgehend neutral.",

        /* Plank */
        "howto.plank.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.plank.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Plank (fortgeschritten) */
        "howto.plank_fortgeschritten.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.plank_fortgeschritten.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Plank mit Beinheben */
        "howto.plank_mit_beinheben.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.plank_mit_beinheben.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Bicycle Crunches */
        "howto.bicycle_crunches.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.bicycle_crunches.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Reverse Crunches */
        "howto.reverse_crunches.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.reverse_crunches.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Crunches */
        "howto.crunches.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.crunches.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Side Plank */
        "howto.side_plank.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.side_plank.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Side Plank mit Hüftheben */
        "howto.side_plank_mit_hueftheben.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.side_plank_mit_hueftheben.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Plank Walkouts */
        "howto.plank_walkouts.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.plank_walkouts.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Hollow Hold */
        "howto.hollow_hold.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.hollow_hold.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Hollow Rock (leicht) */
        "howto.hollow_rock_leicht.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.hollow_rock_leicht.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Toe Touches */
        "howto.toe_touches.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.toe_touches.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Russian Twists */
        "howto.russian_twists.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.russian_twists.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Dead Bug (aktivieren) */
        "howto.dead_bug_aktivieren.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.dead_bug_aktivieren.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Hip Bridges */
        "howto.hip_bridges.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.hip_bridges.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Glute Bridge March */
        "howto.glute_bridge_march.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.glute_bridge_march.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Bird Dog */
        "howto.bird_dog.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.bird_dog.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Cat-Cow */
        "howto.cat_cow.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.cat_cow.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Neck Rolls */
        "howto.neck_rolls.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.neck_rolls.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Hamstring Stretch */
        "howto.hamstring_stretch.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.hamstring_stretch.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Hip Flexor Stretch */
        "howto.hip_flexor_stretch.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.hip_flexor_stretch.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Thoracic Rotation */
        "howto.thoracic_rotation.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.thoracic_rotation.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Child’s Pose */
        "howto.childs_pose.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.childs_pose.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Deep Breathing */
        "howto.deep_breathing.execution.1" : "Entspannte Haltung einnehmen; sanft durch die Nase atmen.",
        "howto.deep_breathing.execution.2" : "Ausatmung lang und ruhig; Schultern entspannt lassen.",

        /* World’s Greatest Stretch (dynamisch) */
        "howto.worlds_greatest_stretch_dynamisch.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.worlds_greatest_stretch_dynamisch.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Glute Stretch */
        "howto.glute_stretch.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.glute_stretch.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Shoulder Opener an der Wand */
        "howto.shoulder_opener_an_der_wand.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.shoulder_opener_an_der_wand.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Ankle Dorsiflexion Mobilisation */
        "howto.ankle_dorsiflexion_mobilisation.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.ankle_dorsiflexion_mobilisation.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Half Standing Forward Fold */
        "howto.half_standing_forward_fold.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.half_standing_forward_fold.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Spinal Waves */
        "howto.spinal_waves.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.spinal_waves.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* 90/90 Hip Rotation */
        "howto.90_90_hip_rotation.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.90_90_hip_rotation.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Pectoral Doorway Stretch */
        "howto.pectoral_doorway_stretch.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.pectoral_doorway_stretch.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Lunging Straight Leg Calf Stretching */
        "howto.lunging_straight_leg_calf_stretching.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.lunging_straight_leg_calf_stretching.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Box Breathing */
        "howto.box_breathing.execution.1" : "Entspannte Haltung einnehmen; sanft durch die Nase atmen.",
        "howto.box_breathing.execution.2" : "Ausatmung lang und ruhig; Schultern entspannt lassen.",

        /* Lateral Hip Opener */
        "howto.lateral_hip_opener.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.lateral_hip_opener.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Lat Stretch an Stange */
        "howto.lat_stretch_an_stange.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.lat_stretch_an_stange.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Quad Stretch */
        "howto.quad_stretch.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.quad_stretch.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Happy Baby */
        "howto.happy_baby.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.happy_baby.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Spinal Twist (liegend) */
        "howto.spinal_twist_liegend.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.spinal_twist_liegend.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Cobra Stretch */
        "howto.cobra_stretch.execution.1" : "Langsam in die Dehnung gehen; Rücken lang lassen.",
        "howto.cobra_stretch.execution.2" : "Sanfte, schmerzfreie Spannung halten; nicht federn.",

        /* Stretching Brust */
        "howto.stretching_brust.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.stretching_brust.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* world geratest stretch */
        "howto.world_geratest_stretch.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.world_geratest_stretch.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* stretching schultern */
        "howto.stretching_schultern.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.stretching_schultern.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* stretching rücken */
        "howto.stretching_ruecken.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.stretching_ruecken.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Schulter taps im plank */
        "howto.schulter_taps_im_plank.execution.1" : "Wirbelsäule lang; Rippen unten, Becken neutral.",
        "howto.schulter_taps_im_plank.execution.2" : "Langsam und kontrolliert bewegen; kein Hohlkreuz.",

        /* Dehnung brust */
        "howto.dehnung_brust.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.dehnung_brust.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* stretching triez's */
        "howto.stretching_triezs.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.stretching_triezs.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* Katzenbuckel/Pferderücken */
        "howto.katzenbuckel_pferderuecken.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.katzenbuckel_pferderuecken.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* stretching Hüfte */
        "howto.stretching_huefte.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.stretching_huefte.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* World's Greatest Stretch */
        "howto.worlds_greatest_stretch.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.worlds_greatest_stretch.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",

        /* stretching Bauch */
        "howto.stretching_bauch.execution.1" : "Fließend mit Ganzkörperspannung bewegen.",
        "howto.stretching_bauch.execution.2" : "Ausrichtung und Kontrolle über die gesamte Range halten.",


        /* Prone W-Raises */
        "howto.prone_w_raises.setup.1" : "Bauchlage oder Stand mit freier Schulterbewegung.",
        "howto.prone_w_raises.coaching_cues.1" : "Schulterblätter nach hinten/unten („in die Hosentaschen“).",
        "howto.prone_w_raises.coaching_cues.2" : "Arme lang, Nacken neutral.",
        "howto.prone_w_raises.atmung.1" : "Ein beim Absenken, aus beim Aktivieren.",
        "howto.prone_w_raises.atmung.2" : "Schulterblätter bewusst führen.",
        "howto.prone_w_raises.haeufige_fehler.1" : "Kopf in den Nacken / LWS überstrecken.",
        "howto.prone_w_raises.haeufige_fehler.2" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.prone_w_raises.haeufige_fehler.3" : "Schultern zu den Ohren ziehen.",
        "howto.prone_w_raises.skalierung_varianten.1" : "Leichter: kürzere Sätze oder kleinere Range.",
        "howto.prone_w_raises.skalierung_varianten.2" : "Schwerer: längere Haltezeit; Tempo 3–1–1.",
        "howto.prone_w_raises.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Bandzug.",

        /* Reverse Snow Angels */
        "howto.reverse_snow_angels.setup.1" : "Bauchlage oder Stand mit freier Schulterbewegung.",
        "howto.reverse_snow_angels.coaching_cues.1" : "Schulterblätter nach hinten/unten („in die Hosentaschen“).",
        "howto.reverse_snow_angels.coaching_cues.2" : "Arme lang, Nacken neutral.",
        "howto.reverse_snow_angels.atmung.1" : "Ein beim Absenken, aus beim Aktivieren.",
        "howto.reverse_snow_angels.atmung.2" : "Schulterblätter bewusst führen.",
        "howto.reverse_snow_angels.haeufige_fehler.1" : "Kopf in den Nacken / LWS überstrecken.",
        "howto.reverse_snow_angels.haeufige_fehler.2" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.reverse_snow_angels.haeufige_fehler.3" : "Schultern zu den Ohren ziehen.",
        "howto.reverse_snow_angels.skalierung_varianten.1" : "Leichter: kürzere Sätze oder kleinere Range.",
        "howto.reverse_snow_angels.skalierung_varianten.2" : "Schwerer: längere Haltezeit; Tempo 3–1–1.",
        "howto.reverse_snow_angels.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Bandzug.",

        /* Plank */
        "howto.plank.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.plank.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.plank.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.plank.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.plank.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.plank.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.plank.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.plank.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.plank.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.plank.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.plank.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        /* Plank (fortgeschritten) */
        "howto.plank_fortgeschritten.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.plank_fortgeschritten.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.plank_fortgeschritten.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.plank_fortgeschritten.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.plank_fortgeschritten.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.plank_fortgeschritten.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.plank_fortgeschritten.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.plank_fortgeschritten.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.plank_fortgeschritten.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.plank_fortgeschritten.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.plank_fortgeschritten.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        /* Plank mit Beinheben */
        "howto.plank_mit_beinheben.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.plank_mit_beinheben.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.plank_mit_beinheben.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.plank_mit_beinheben.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.plank_mit_beinheben.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.plank_mit_beinheben.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.plank_mit_beinheben.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.plank_mit_beinheben.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.plank_mit_beinheben.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.plank_mit_beinheben.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.plank_mit_beinheben.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        /* Bicycle Crunches */
        "howto.bicycle_crunches.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.bicycle_crunches.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.bicycle_crunches.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.bicycle_crunches.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.bicycle_crunches.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.bicycle_crunches.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.bicycle_crunches.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.bicycle_crunches.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.bicycle_crunches.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.bicycle_crunches.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.bicycle_crunches.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        /* Reverse Crunches */
        "howto.reverse_crunches.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.reverse_crunches.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.reverse_crunches.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.reverse_crunches.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.reverse_crunches.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.reverse_crunches.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.reverse_crunches.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.reverse_crunches.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.reverse_crunches.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.reverse_crunches.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.reverse_crunches.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        /* Crunches */
        "howto.crunches.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.crunches.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.crunches.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.crunches.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.crunches.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.crunches.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.crunches.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.crunches.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.crunches.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.crunches.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.crunches.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        /* Side Plank */
        "howto.side_plank.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.side_plank.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.side_plank.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.side_plank.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.side_plank.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.side_plank.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.side_plank.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.side_plank.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.side_plank.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.side_plank.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.side_plank.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        /* Side Plank mit Hüftheben */
        "howto.side_plank_mit_hueftheben.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.side_plank_mit_hueftheben.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.side_plank_mit_hueftheben.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.side_plank_mit_hueftheben.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.side_plank_mit_hueftheben.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.side_plank_mit_hueftheben.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.side_plank_mit_hueftheben.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.side_plank_mit_hueftheben.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.side_plank_mit_hueftheben.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.side_plank_mit_hueftheben.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.side_plank_mit_hueftheben.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        /* Plank Walkouts */
        "howto.plank_walkouts.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.plank_walkouts.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.plank_walkouts.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.plank_walkouts.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.plank_walkouts.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.plank_walkouts.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.plank_walkouts.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.plank_walkouts.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.plank_walkouts.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.plank_walkouts.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.plank_walkouts.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        /* Hollow Hold */
        "howto.hollow_hold.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.hollow_hold.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.hollow_hold.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.hollow_hold.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.hollow_hold.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.hollow_hold.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.hollow_hold.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.hollow_hold.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.hollow_hold.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.hollow_hold.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.hollow_hold.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        /* Hollow Rock (leicht) */
        "howto.hollow_rock_leicht.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.hollow_rock_leicht.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.hollow_rock_leicht.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.hollow_rock_leicht.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.hollow_rock_leicht.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.hollow_rock_leicht.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.hollow_rock_leicht.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.hollow_rock_leicht.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.hollow_rock_leicht.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.hollow_rock_leicht.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.hollow_rock_leicht.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        /* Toe Touches */
        "howto.toe_touches.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.toe_touches.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.toe_touches.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.toe_touches.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.toe_touches.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.toe_touches.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.toe_touches.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.toe_touches.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.toe_touches.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.toe_touches.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.toe_touches.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        /* Russian Twists */
        "howto.russian_twists.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.russian_twists.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.russian_twists.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.russian_twists.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.russian_twists.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.russian_twists.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.russian_twists.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.russian_twists.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.russian_twists.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.russian_twists.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.russian_twists.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        /* Dead Bug (aktivieren) */
        "howto.dead_bug_aktivieren.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.dead_bug_aktivieren.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.dead_bug_aktivieren.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.dead_bug_aktivieren.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.dead_bug_aktivieren.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.dead_bug_aktivieren.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.dead_bug_aktivieren.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.dead_bug_aktivieren.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.dead_bug_aktivieren.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.dead_bug_aktivieren.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.dead_bug_aktivieren.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        /* Hip Bridges */
        "howto.hip_bridges.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.hip_bridges.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.hip_bridges.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.hip_bridges.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.hip_bridges.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.hip_bridges.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.hip_bridges.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.hip_bridges.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.hip_bridges.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.hip_bridges.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.hip_bridges.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Glute Bridge March */
        "howto.glute_bridge_march.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.glute_bridge_march.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.glute_bridge_march.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.glute_bridge_march.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.glute_bridge_march.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.glute_bridge_march.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.glute_bridge_march.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.glute_bridge_march.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.glute_bridge_march.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.glute_bridge_march.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.glute_bridge_march.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Bird Dog */
        "howto.bird_dog.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.bird_dog.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.bird_dog.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.bird_dog.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.bird_dog.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.bird_dog.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.bird_dog.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.bird_dog.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.bird_dog.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.bird_dog.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.bird_dog.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Cat-Cow */
        "howto.cat_cow.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.cat_cow.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.cat_cow.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.cat_cow.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.cat_cow.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.cat_cow.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.cat_cow.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.cat_cow.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.cat_cow.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.cat_cow.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.cat_cow.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        /* Neck Rolls */
        "howto.neck_rolls.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.neck_rolls.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.neck_rolls.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.neck_rolls.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.neck_rolls.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.neck_rolls.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.neck_rolls.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.neck_rolls.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.neck_rolls.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.neck_rolls.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.neck_rolls.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Hamstring Stretch */
        "howto.hamstring_stretch.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.hamstring_stretch.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.hamstring_stretch.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.hamstring_stretch.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.hamstring_stretch.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.hamstring_stretch.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.hamstring_stretch.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.hamstring_stretch.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.hamstring_stretch.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.hamstring_stretch.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.hamstring_stretch.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        /* Hip Flexor Stretch */
        "howto.hip_flexor_stretch.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.hip_flexor_stretch.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.hip_flexor_stretch.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.hip_flexor_stretch.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.hip_flexor_stretch.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.hip_flexor_stretch.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.hip_flexor_stretch.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.hip_flexor_stretch.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.hip_flexor_stretch.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.hip_flexor_stretch.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.hip_flexor_stretch.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        /* Thoracic Rotation */
        "howto.thoracic_rotation.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.thoracic_rotation.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.thoracic_rotation.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.thoracic_rotation.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.thoracic_rotation.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.thoracic_rotation.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.thoracic_rotation.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.thoracic_rotation.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.thoracic_rotation.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.thoracic_rotation.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.thoracic_rotation.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        /* Child’s Pose */
        "howto.childs_pose.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.childs_pose.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.childs_pose.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.childs_pose.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.childs_pose.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.childs_pose.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.childs_pose.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.childs_pose.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.childs_pose.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.childs_pose.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.childs_pose.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        
        "home.training.inProgress.prefix" : "Aktives Training",
          "startMenu.title" : "Neues Training starten",
          "startMenu.strength.title" : "Krafttraining",
          "startMenu.strength.subtitle" : "Sätze, Gewichte & Pausen",
          "startMenu.running.title" : "Joggen",
          "startMenu.running.subtitle" : "Distanz & Dauer tracken",
          "startMenu.manual.title" : "Manuell eintragen",
          "startMenu.manual.subtitle" : "Training nachträglich hinzufügen",
          "startMenu.cancel" : "Abbrechen",
        

        /* Deep Breathing */
        "howto.deep_breathing.setup.1" : "Bequeme, aufrechte oder gestützte Position; Schultern entspannt.",
        "howto.deep_breathing.coaching_cues.1" : "Sanft durch die Nase atmen; lange, ruhige Ausatmung.",
        "howto.deep_breathing.coaching_cues.2" : "Auf Bauch- und Rippenbewegung achten.",
        "howto.deep_breathing.atmung.1" : "Durch die Nase ein; durch den Mund etwas länger aus.",
        "howto.deep_breathing.atmung.2" : "Regelmäßiger Rhythmus – ohne Anstrengung.",
        "howto.deep_breathing.haeufige_fehler.1" : "Atem anhalten oder hecheln.",
        "howto.deep_breathing.haeufige_fehler.2" : "Schultern hochziehen, Nacken verspannen.",
        "howto.deep_breathing.haeufige_fehler.3" : "Reichweite erzwingen statt loslassen.",
        "howto.deep_breathing.skalierung_varianten.1" : "Leichter: Zyklen verkürzen.",
        "howto.deep_breathing.skalierung_varianten.2" : "Schwerer: Zyklen verlängern (z. B. 4–6–6–4).",
        "howto.deep_breathing.skalierung_varianten.3" : "Schwerer: einfachen Fokus ergänzen (Zählen, Body Scan).",

        /* World’s Greatest Stretch (dynamisch) */
        "howto.worlds_greatest_stretch_dynamisch.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.worlds_greatest_stretch_dynamisch.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.worlds_greatest_stretch_dynamisch.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.worlds_greatest_stretch_dynamisch.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.worlds_greatest_stretch_dynamisch.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.worlds_greatest_stretch_dynamisch.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.worlds_greatest_stretch_dynamisch.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.worlds_greatest_stretch_dynamisch.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.worlds_greatest_stretch_dynamisch.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.worlds_greatest_stretch_dynamisch.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.worlds_greatest_stretch_dynamisch.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Glute Stretch */
        "howto.glute_stretch.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.glute_stretch.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.glute_stretch.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.glute_stretch.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.glute_stretch.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.glute_stretch.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.glute_stretch.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.glute_stretch.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.glute_stretch.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.glute_stretch.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.glute_stretch.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        /* Shoulder Opener an der Wand */
        "howto.shoulder_opener_an_der_wand.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.shoulder_opener_an_der_wand.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.shoulder_opener_an_der_wand.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.shoulder_opener_an_der_wand.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.shoulder_opener_an_der_wand.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.shoulder_opener_an_der_wand.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.shoulder_opener_an_der_wand.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.shoulder_opener_an_der_wand.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.shoulder_opener_an_der_wand.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.shoulder_opener_an_der_wand.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.shoulder_opener_an_der_wand.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Ankle Dorsiflexion Mobilisation */
        "howto.ankle_dorsiflexion_mobilisation.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.ankle_dorsiflexion_mobilisation.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.ankle_dorsiflexion_mobilisation.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.ankle_dorsiflexion_mobilisation.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.ankle_dorsiflexion_mobilisation.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.ankle_dorsiflexion_mobilisation.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.ankle_dorsiflexion_mobilisation.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.ankle_dorsiflexion_mobilisation.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.ankle_dorsiflexion_mobilisation.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.ankle_dorsiflexion_mobilisation.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.ankle_dorsiflexion_mobilisation.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        /* Half Standing Forward Fold */
        "howto.half_standing_forward_fold.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.half_standing_forward_fold.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.half_standing_forward_fold.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.half_standing_forward_fold.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.half_standing_forward_fold.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.half_standing_forward_fold.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.half_standing_forward_fold.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.half_standing_forward_fold.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.half_standing_forward_fold.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.half_standing_forward_fold.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.half_standing_forward_fold.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        /* Spinal Waves */
        "howto.spinal_waves.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.spinal_waves.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.spinal_waves.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.spinal_waves.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.spinal_waves.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.spinal_waves.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.spinal_waves.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.spinal_waves.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.spinal_waves.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.spinal_waves.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.spinal_waves.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        
        "home.greeting.hiUser" : "Hallo, %@",   // DE

        
        "common.start": "Start",

        /* 90/90 Hip Rotation */
        "howto.90_90_hip_rotation.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.90_90_hip_rotation.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.90_90_hip_rotation.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.90_90_hip_rotation.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.90_90_hip_rotation.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.90_90_hip_rotation.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.90_90_hip_rotation.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.90_90_hip_rotation.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.90_90_hip_rotation.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.90_90_hip_rotation.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.90_90_hip_rotation.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        /* Pectoral Doorway Stretch */
        "howto.pectoral_doorway_stretch.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.pectoral_doorway_stretch.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.pectoral_doorway_stretch.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.pectoral_doorway_stretch.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.pectoral_doorway_stretch.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.pectoral_doorway_stretch.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.pectoral_doorway_stretch.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.pectoral_doorway_stretch.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.pectoral_doorway_stretch.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.pectoral_doorway_stretch.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.pectoral_doorway_stretch.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        
        /* ===================== de ===================== */

        /* Kein Treffer / Anfrage anbieten */
        "exercises.noResults.title" : "Keine Treffer für „%@“",
        "exercises.noResults.subtitle" : "Möchtest du diese Übung anfragen?",
        "exercises.request.button" : "Neue Übung anfragen",

        /* Request-Sheet */
        "exercises.request.title" : "Neue Übung anfragen",
        "exercises.request.form.exercise" : "Übung",
        "exercises.request.form.namePlaceholder" : "Name der Übung",
        "exercises.request.form.detailsHeader" : "Details (optional)",
        "exercises.request.form.footer" : "Wir nutzen deinen Suchbegriff, damit wir den Kontext verstehen.",

        /* Alerts */
        "exercises.request.alert.success.title" : "Danke!",
        "exercises.request.alert.success.message" : "Deine Anfrage wurde gespeichert.",
        "exercises.request.alert.error.title" : "Fehler beim Senden",

        /* Allgemein (falls noch nicht vorhanden) */
        "exercises.title" : "Übungen",
        "exercises.search" : "Übungen durchsuchen",
        "exercises.addNew" : "Neue Übung hinzufügen",
        "search.clear" : "Suche löschen",
        "common.cancel" : "Abbrechen",
        "common.send" : "Senden",
    



        /* Lunging Straight Leg Calf Stretching */
        "howto.lunging_straight_leg_calf_stretching.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.lunging_straight_leg_calf_stretching.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.lunging_straight_leg_calf_stretching.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.lunging_straight_leg_calf_stretching.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.lunging_straight_leg_calf_stretching.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.lunging_straight_leg_calf_stretching.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.lunging_straight_leg_calf_stretching.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.lunging_straight_leg_calf_stretching.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.lunging_straight_leg_calf_stretching.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.lunging_straight_leg_calf_stretching.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.lunging_straight_leg_calf_stretching.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Box Breathing */
        "howto.box_breathing.setup.1" : "Bequeme, aufrechte oder gestützte Position; Schultern entspannt.",
        "howto.box_breathing.coaching_cues.1" : "Sanft durch die Nase atmen; lange, ruhige Ausatmung.",
        "howto.box_breathing.coaching_cues.2" : "Auf Bauch- und Rippenbewegung achten.",
        "howto.box_breathing.atmung.1" : "Durch die Nase ein; durch den Mund etwas länger aus.",
        "howto.box_breathing.atmung.2" : "Regelmäßiger Rhythmus – ohne Anstrengung.",
        "howto.box_breathing.haeufige_fehler.1" : "Atem anhalten oder hecheln.",
        "howto.box_breathing.haeufige_fehler.2" : "Schultern hochziehen, Nacken verspannen.",
        "howto.box_breathing.haeufige_fehler.3" : "Reichweite erzwingen statt loslassen.",
        "howto.box_breathing.skalierung_varianten.1" : "Leichter: Zyklen verkürzen.",
        "howto.box_breathing.skalierung_varianten.2" : "Schwerer: Zyklen verlängern (z. B. 4–6–6–4).",
        "howto.box_breathing.skalierung_varianten.3" : "Schwerer: einfachen Fokus ergänzen (Zählen, Body Scan).",

        /* Lateral Hip Opener */
        "howto.lateral_hip_opener.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.lateral_hip_opener.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.lateral_hip_opener.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.lateral_hip_opener.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.lateral_hip_opener.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.lateral_hip_opener.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.lateral_hip_opener.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.lateral_hip_opener.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.lateral_hip_opener.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.lateral_hip_opener.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.lateral_hip_opener.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        
        
        "common.sleep" : "Schlaf",
        "common.calories" : "Kalorien",
        "common.water" : "Wasser",
        "common.weight" : "Gewicht",

        "dashboard.lastTraining" : "Letztes Training",
        "dashboard.myDashboard" : "Mein Dashboard",
        "dashboard.additionalStats" : "Weitere Statistiken",
        "dashboard.editTitle" : "Dashboard bearbeiten",


        /* Lat Stretch an Stange */
        "howto.lat_stretch_an_stange.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.lat_stretch_an_stange.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.lat_stretch_an_stange.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.lat_stretch_an_stange.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.lat_stretch_an_stange.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.lat_stretch_an_stange.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.lat_stretch_an_stange.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.lat_stretch_an_stange.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.lat_stretch_an_stange.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.lat_stretch_an_stange.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.lat_stretch_an_stange.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        /* Quad Stretch */
        "howto.quad_stretch.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.quad_stretch.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.quad_stretch.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.quad_stretch.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.quad_stretch.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.quad_stretch.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.quad_stretch.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.quad_stretch.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.quad_stretch.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.quad_stretch.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.quad_stretch.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        "startMenu.comingSoon" : "Bald verfügbar",

        /* Happy Baby */
        "howto.happy_baby.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.happy_baby.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.happy_baby.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.happy_baby.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.happy_baby.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.happy_baby.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.happy_baby.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.happy_baby.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.happy_baby.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.happy_baby.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.happy_baby.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        /* Spinal Twist (liegend) */
        "howto.spinal_twist_liegend.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.spinal_twist_liegend.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.spinal_twist_liegend.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.spinal_twist_liegend.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.spinal_twist_liegend.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.spinal_twist_liegend.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.spinal_twist_liegend.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.spinal_twist_liegend.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.spinal_twist_liegend.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.spinal_twist_liegend.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.spinal_twist_liegend.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        /* Cobra Stretch */
        "howto.cobra_stretch.setup.1" : "Bequeme Ausgangsposition; Rücken lang, Schultern entspannt.",
        "howto.cobra_stretch.coaching_cues.1" : "Mit der Ausatmung in die Dehnung „einschmelzen“.",
        "howto.cobra_stretch.coaching_cues.2" : "Range kontrollieren – kein Federn.",
        "howto.cobra_stretch.atmung.1" : "Lang ausatmen und Spannung weich werden lassen.",
        "howto.cobra_stretch.atmung.2" : "Nie in Schmerz hinein atmen; gleichmäßig bleiben.",
        "howto.cobra_stretch.haeufige_fehler.1" : "Mit Schwung in Endrange federn.",
        "howto.cobra_stretch.haeufige_fehler.2" : "Ausweichbewegungen (Hohlkreuz, Schultern hoch).",
        "howto.cobra_stretch.haeufige_fehler.3" : "Schmerz statt sanfter Spannung suchen.",
        "howto.cobra_stretch.skalierung_varianten.1" : "Leichter: Range oder Haltezeit reduzieren.",
        "howto.cobra_stretch.skalierung_varianten.2" : "Schwerer: Haltezeit verlängern; Winkel fein anpassen.",
        "howto.cobra_stretch.skalierung_varianten.3" : "Schwerer: aktive Endrange oder Contract-Relax.",

        /* Stretching Brust */
        "howto.stretching_brust.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.stretching_brust.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.stretching_brust.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.stretching_brust.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.stretching_brust.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.stretching_brust.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.stretching_brust.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.stretching_brust.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.stretching_brust.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.stretching_brust.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.stretching_brust.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* world geratest stretch */
        "howto.world_geratest_stretch.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.world_geratest_stretch.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.world_geratest_stretch.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.world_geratest_stretch.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.world_geratest_stretch.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.world_geratest_stretch.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.world_geratest_stretch.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.world_geratest_stretch.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.world_geratest_stretch.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.world_geratest_stretch.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.world_geratest_stretch.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        
        // DE
        "calories.title" : "Kalorien",
        "calories.activeEnergy" : "Aktive Energie",
        "calories.activityTrend" : "Aktivitätstrend",
        "calories.noData.title" : "Keine Daten",
        "calories.noData.description" : "Für diesen Zeitraum sind keine Kaloriendaten verfügbar.",
        "calories.dailyHistory" :  "Tägliche Historie",
        "calories.unit" : "Kalorien",

        "unit.kcal" : "kcal",
        "common.range" : "Zeitraum",
        "range.days" : "%d Tage",

        "statistics.total" : "Gesamt",
        "statistics.average" : "Durchschnitt",
        "statistics.bestDay" : "Bester Tag",
        "statistics.days" : "Tage",
        "statistics.date" : "Datum",

        "settings.done" : "Fertig",

        /* stretching schultern */
        "howto.stretching_schultern.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.stretching_schultern.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.stretching_schultern.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.stretching_schultern.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.stretching_schultern.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.stretching_schultern.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.stretching_schultern.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.stretching_schultern.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.stretching_schultern.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.stretching_schultern.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.stretching_schultern.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* stretching rücken */
        "howto.stretching_ruecken.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.stretching_ruecken.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.stretching_ruecken.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.stretching_ruecken.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.stretching_ruecken.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.stretching_ruecken.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.stretching_ruecken.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.stretching_ruecken.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.stretching_ruecken.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.stretching_ruecken.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.stretching_ruecken.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Schulter taps im plank */
        "howto.schulter_taps_im_plank.setup.1" : "Körper in Linie; Rumpf anspannen, Rippen unten.",
        "howto.schulter_taps_im_plank.coaching_cues.1" : "Aus dem Rumpf bewegen, nicht mit Schwung.",
        "howto.schulter_taps_im_plank.coaching_cues.2" : "Nacken lang, LWS neutral.",
        "howto.schulter_taps_im_plank.atmung.1" : "Ruhig ein; ausatmen für stabile Spannung.",
        "howto.schulter_taps_im_plank.atmung.2" : "Kein Pressen – gleichmäßig atmen.",
        "howto.schulter_taps_im_plank.haeufige_fehler.1" : "Hohlkreuz / Neutralität geht verloren.",
        "howto.schulter_taps_im_plank.haeufige_fehler.2" : "Am Kopf ziehen / Schultern hochziehen.",
        "howto.schulter_taps_im_plank.haeufige_fehler.3" : "Hüfte rotiert oder sackt ab.",
        "howto.schulter_taps_im_plank.skalierung_varianten.1" : "Leichter: Hebel/Range verkürzen oder Haltezeit reduzieren.",
        "howto.schulter_taps_im_plank.skalierung_varianten.2" : "Schwerer: Hebel verlängern, einseitig, länger halten.",
        "howto.schulter_taps_im_plank.skalierung_varianten.3" : "Schwerer: leichte Zusatzlast oder Anti-Rotation.",

        
        "weight.details.title": "Gewicht",
        "weight.chart.trend": "Trend",
        "weight.empty.title": "Keine Daten",
        "weight.empty.description": "Für diesen Zeitraum wurden keine Gewichtsdaten gefunden.",
        "weight.stat.average": "Durchschnitt",
        "weight.stat.minimum": "Minimum",
        "weight.stat.maximum": "Maximum",
        "weight.stat.entries": "Einträge",
        "weight.history.title": "Verlauf",

        "range.7days": "7 Tage",
        "range.30days": "30 Tage",
        "range.90days": "90 Tage",

        /* Dehnung brust */
        "howto.dehnung_brust.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.dehnung_brust.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.dehnung_brust.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.dehnung_brust.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.dehnung_brust.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.dehnung_brust.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.dehnung_brust.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.dehnung_brust.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.dehnung_brust.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.dehnung_brust.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.dehnung_brust.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        
        
        "training.discardConfirm" : "Möchtest du das Training wirklich verwerfen?",

        "statistics.activity" : "Aktivität",

        "statistics.activity.subtitle" : "%d Workouts dieses Jahr",

        /* stretching triez's */
        "howto.stretching_triezs.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.stretching_triezs.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.stretching_triezs.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.stretching_triezs.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.stretching_triezs.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.stretching_triezs.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.stretching_triezs.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.stretching_triezs.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.stretching_triezs.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.stretching_triezs.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.stretching_triezs.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* Katzenbuckel/Pferderücken */
        "howto.katzenbuckel_pferderuecken.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.katzenbuckel_pferderuecken.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.katzenbuckel_pferderuecken.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.katzenbuckel_pferderuecken.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.katzenbuckel_pferderuecken.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.katzenbuckel_pferderuecken.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.katzenbuckel_pferderuecken.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.katzenbuckel_pferderuecken.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.katzenbuckel_pferderuecken.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.katzenbuckel_pferderuecken.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.katzenbuckel_pferderuecken.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* stretching Hüfte */
        "howto.stretching_huefte.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.stretching_huefte.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.stretching_huefte.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.stretching_huefte.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.stretching_huefte.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.stretching_huefte.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.stretching_huefte.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.stretching_huefte.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.stretching_huefte.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.stretching_huefte.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.stretching_huefte.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* World's Greatest Stretch */
        "howto.worlds_greatest_stretch.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.worlds_greatest_stretch.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.worlds_greatest_stretch.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.worlds_greatest_stretch.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.worlds_greatest_stretch.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.worlds_greatest_stretch.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.worlds_greatest_stretch.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.worlds_greatest_stretch.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.worlds_greatest_stretch.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.worlds_greatest_stretch.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.worlds_greatest_stretch.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

        /* stretching Bauch */
        "howto.stretching_bauch.setup.1" : "Stabiler Stand und freier Raum; kontrolliert bewegen.",
        "howto.stretching_bauch.coaching_cues.1" : "Gelenke in neutralen Bahnen führen.",
        "howto.stretching_bauch.coaching_cues.2" : "Qualität vor Quantität.",
        "howto.stretching_bauch.atmung.1" : "Gleichmäßig atmen; in der Anstrengung ausatmen.",
        "howto.stretching_bauch.atmung.2" : "Kein Pressen / Luft anhalten.",
        "howto.stretching_bauch.haeufige_fehler.1" : "Mit Schwung statt Kontrolle arbeiten.",
        "howto.stretching_bauch.haeufige_fehler.2" : "Schmerz ignorieren statt Range anzupassen.",
        "howto.stretching_bauch.haeufige_fehler.3" : "Ausrichtung unter Ermüdung verlieren.",
        "howto.stretching_bauch.skalierung_varianten.1" : "Leichter: Range/Hebel reduzieren.",
        "howto.stretching_bauch.skalierung_varianten.2" : "Schwerer: Hebel verlängern oder Tempo verlangsamen.",
        "howto.stretching_bauch.skalierung_varianten.3" : "Schwerer: Zusatzlast, sofern verfügbar.",

      
        "days.unit": "Tage",

        // Templates – Workouts
        "tpl.workouts.3.title": "3 Workouts/Woche",
        "tpl.workouts.3.desc": "Solider Einstieg für Beständigkeit.",
        "tpl.workouts.5.title": "5 Workouts pro Woche",
        "tpl.workouts.5.desc": "Schließe 5 Workouts bis Sonntag ab.",
        "tpl.workouts.7.title": "7 Workouts/Woche",
        "tpl.workouts.7.desc": "Jeden Tag ein Workout absolvieren.",
        "tpl.workouts.10in14.title": "10 Workouts in 14 Tagen",
        "tpl.workouts.10in14.desc": "Intensive Phase für einen Schub.",

        // Templates – Steps
        "tpl.steps.10k.title": "10.000 Schritte/Tag",
        "tpl.steps.10k.desc": "Halte dich täglich aktiv.",
        "tpl.steps.12k.title": "12.000 Schritte/Tag",
        "tpl.steps.12k.desc": "Spürbar mehr Bewegung im Alltag.",
        "tpl.steps.15k.title": "15.000 Schritte/Tag",
        "tpl.steps.15k.desc": "Ambitioniertes Schrittziel.",

        
        "paywall.plan.lifetime.title": "Lifetime (einmalig)",
        "paywall.plan.lifetime.price" : "9,99Є einmalig",    // %@ = displayPriceLifetime


        // Templates – Weekly Volume
        "tpl.volume.5k.title": "5.000 kg/Woche",
        "tpl.volume.5k.desc": "Gesamt bewegtes Gewicht pro Woche.",
        "tpl.volume.10k.title": "10.000 kg/Woche",
        "tpl.volume.10k.desc": "Ambitioniertes Trainingsvolumen.",

        // Templates – Streak
        "tpl.streak.3.title": "3-Tage-Streak",
        "tpl.streak.3.desc": "Trainiere 3 Tage hintereinander.",
        "tpl.streak.5.title": "5-Tage-Streak",
        "tpl.streak.5.desc": "Trainiere 5 Tage hintereinander.",


        "statistics.musclemap.title.thisweek.format" : "%@ · %@",
        "statistics.musclemap.legend.trained" : "trainiert",

        "common.search" : "Suchen",

        
        // Templates – Active Days
        "tpl.days.3.title": "3 aktive Tage/Woche",
        "tpl.days.3.desc": "An 3 verschiedenen Tagen trainieren.",
        "tpl.days.5.title": "5 aktive Tage/Woche",
        "tpl.days.5.desc": "An 5 verschiedenen Tagen trainieren.",

        "howto.neck_rolls.note.1" : "Sehr sanft ausführen; nicht in Endränge oder Schmerz drücken.",

        "howto.childs_pose.note.1" : "Gesäß zu den Fersen, Arme lang; Schultern entspannen.",
        "howto.deep_breathing.note.1" : "Durch die Nase atmen; 360°-Rippenexpansion, langsam und entspannt ausatmen.",
        "howto.half_standing_forward_fold.note.1" : "Locker hängen lassen und schmerzfrei bleiben.",
        "howto.happy_baby.note.1" : "Knie Richtung Achseln, Rücken bleibt am Boden; ruhig atmen.",
        "howto.spinal_twist_liegend.note.1" : "Beide Schultern möglichst am Boden lassen.",
        "howto.cobra_stretch.note.1" : "Ellbogen weich halten; nur schmerzfrei bewegen.",
        
        
        "date.today"     : "Heute",          // DE: "Heute"
        "date.yesterday" : "Gestern",          // DE: "Gestern"
        "date.daysAgo"   : "vor %d Tagen",        // DE: "vor %d Tagen"
        
        // DEUTSCH
        "sleep.average": "Durchschnitt",
        "sleep.info.healthkit": "Verbinde HealthKit, um deinen Schlaf automatisch zu erfassen",
        "sleep.pattern": "Schlafmuster",
        "sleep.noData.title": "Keine Daten",
        "sleep.noData.description": "Sobald Schlafdaten verfügbar sind, werden sie hier angezeigt.",
        "sleep.recommended": "Empfohlen",

        "sleep.stat.average": "Durchschnitt",
        "sleep.stat.bestNight": "Beste Nacht",
        "sleep.stat.shortest": "Kürzeste Nacht",
        "sleep.stat.goalNights": "%d Std.+ Nächte",
        "sleep.recentNights": "Letzte Nächte",

        "sleep.quality.excellent": "Ausgezeichnet",
        "sleep.quality.good": "Gut",
        "sleep.quality.fair": "Okay",
        "sleep.quality.poor": "Schlecht",

        
        "settings.account.delete.message" : "Das löscht dein Profil, Trainingsdaten und das Login-Konto irreversibel.",
        "settings.account.delete.failed" : "Löschen fehlgeschlagen",
        "settings.account.delete.progress" : "Konto wird gelöscht …",
        "profile.photo.remove" : "Profilbild entfernen",


        "home.weeklyGoal.title" : "Wochenziel",
        "home.weeklyGoal.progress" : "/%d Workouts",

        "weight.card.goalPrefix" : "Gewichtsziel:",

        "dashboard.goalSettings.title" : "Ziele",
        "dashboard.goalSettings.weeklyWorkouts" : "Workouts pro Woche",
        "dashboard.goalSettings.weeklyWorkouts.value" : "%d/Woche",
        "dashboard.goalSettings.weight" : "Gewichtsziel",
        "rank.0": "Holz",
        "rank.1": "Bronze",
        "rank.2": "Gold",
        "rank.3": "Platin",
        "rank.4": "Diamant",
        "rank.5": "Champion",
        "rank.6": "Titan",
        "rank.7": "Olymp",

        // Legend / Statistics texts
        "statistics.level.yours": "Dein Level",
        "statistics.compare": "Vergleichen",
        "statistics.compare.hide": "Vergleich ausblenden",
        "statistics.compare.start": "Start",
        "statistics.compare.now": "Jetzt",

        "statistics.legend.title": "Legende",
        "statistics.legend.info": "Die farbigen Bereiche zeigen, welche Muskelgruppen du wie oft trainiert hast.",
        "statistics.legend.close": "Schließen",
        "statistics.rank.start": "Start",
        "statistics.rank.threshold": "ab %d Punkten",

        // Muscle regions
        "muscle.region.chest": "Brust",
        "muscle.region.shoulders": "Schultern",
        "muscle.region.biceps": "Bizeps",
        "muscle.region.triceps": "Trizeps",
        "muscle.region.lats": "Lat",
        "muscle.region.abs": "Bauch",
        "muscle.region.quads": "Quadrizeps",
        "muscle.region.hamstrings": "Beinbeuger",
        "muscle.region.glutes": "Gesäß",
        "muscle.region.calves": "Waden",
        "muscle.region.calvesBack": "Waden (hinten)",
        "muscle.region.forearms": "Unterarme",
        "muscle.region.traps": "Nacken",
        "muscle.region.lowerBack": "Unterer Rücken",

        // Home – next rank card
        "home.nextLevel": "Nächstes Level",
        "home.until": "bis",
        "home.training.singular": "Training",
        "home.training.plural": "Trainings",
        // ➜ Add to LocalizedStrings.de
        "tab.training"  : "Training",
        "tab.exercises" : "Übungen",
        "tab.challenges": "Challenges",
        "tab.history"   : "Verlauf",
        "tab.stats"     : "Statistik",

        // Common
        "common.more" : "Mehr",
        "common.less" : "Weniger",

        // Statistics: Locked messages
        "statistics.locked.duration"        : "Mit Movo Pro siehst du hier deine Trainingsdauer pro Tag.",
        "statistics.locked.workoutsPerWeek" : "Mit Movo Pro siehst du, wie viele Workouts du pro Woche schaffst.",
        "statistics.locked.topExercises"    : "Mit Movo Pro siehst du deine Top-Übungen und ihr Gesamtvolumen.",
        "statistics.locked.exerciseStats"   : "Wähle eine Übung und sieh alle Details mit Movo Pro.",

        // Statistics: Premium Teaser
        "statistics.premium.title"           : "Premium-Statistiken",
        "statistics.premium.subtitle"        : "Beta: Alle Pro-Features sind aktuell kostenlos.",
        "statistics.premium.feature.charts"  : "Erweiterte Diagramme & Trends",
        "statistics.premium.feature.records" : "Bestes Training & Rekorde",
        "statistics.premium.feature.duration": "Dauer, Volumen, Top-Übungen",
        "statistics.premium.feature.widgets" : "Widgets auf dem Homescreen",
        "statistics.premium.cta"             : "Kostenlos freischalten",

        // Paywall / Toolbar
        "paywall.openPremium" : "Premium öffnen",

        // MuscleMapSummary
        "statistics.musclemap.title": "Muskelkarte",
        "sleep.unit.hours" : "Stunden ",
        "sleep.noData.short" : "Keine Daten",
        "statistics.musclemap.current" : "Diese Woche",
        "statistics.musclemap.previous" : "Letzte Woche",
        "statistics.musclemap.last7.prevWeek" : "Letzte 7 Tage (letzte Woche)",
        "statistics.musclemap.thisweek" : "Letzte 7 Tage (diese Woche)",
        
        // Settings - Account
        "settings.account.changePassword": "Passwort ändern",
        "settings.account.resetPassword": "Passwort zurücksetzen",
        "settings.account.delete": "Konto löschen",
        "settings.account.delete.confirm": "Dauerhaft löschen",
        "settings.account.delete.warning": "Diese Aktion kann nicht rückgängig gemacht werden. Alle deine Daten werden dauerhaft gelöscht.",
        "settings.account.currentPassword": "Aktuelles Passwort",
        "settings.account.newPassword": "Neues Passwort",
        "settings.account.confirmPassword": "Passwort bestätigen",
        "settings.account.passwordMismatch": "Passwörter stimmen nicht überein",
        "settings.account.email": "E-Mail",
        "settings.account.resetPassword.info": "Gib deine E-Mail-Adresse ein, um einen Link zum Zurücksetzen deines Passworts zu erhalten.",
        "settings.account.sendResetLink": "Link senden",
        "settings.account.resetPassword.sent": "Ein Link zum Zurücksetzen wurde an deine E-Mail gesendet.",
        
        // Settings - Legal
        "settings.legal.privacy": "Datenschutz",
        "settings.legal.imprint": "Impressum",
        "settings.legal.terms": "AGB",
        "settings.legal.support": "Support",
        
        // Settings - Support
        "settings.support.title": "Support kontaktieren",
        "settings.support.subtitle": "Schreib uns eine E-Mail und wir helfen dir gerne weiter.",
        "settings.support.sendEmail": "E-Mail senden",
        
        // Common
        "common.success": "Erfolg",
        "common.error": "Fehler",
        "common.ok": "OK",
        
        // Profile Stats
        "profile.stats.time": "Zeit",
        "profile.stats.workouts": "Workouts",
        "profile.weekOverview": "Wochenübersicht",
        "profile.levelProgress": "Level-Fortschritt",
        
        
    ]

    static let en: [String: String] = [
        "tab.feed": "Plan", // ADDED
        "tab.body": "Body", // NEW
        "body.muscle_map.title": "Muscle Level", // ADDED
        "body.title": "Body Status",
        "body.metrics.restingHR": "Resting HR",
        "body.metrics.vo2": "VO₂ Max",
        "body.metrics.respRate": "Respiratory Rate",
        "body.metrics.spo2": "Blood Oxygen",
        "body.metrics.wristTemp": "Wrist Temp",
        "body.recovery.title": "Recovery Zone",
        "body.recovery.muscleStatus": "Muscle Status",
        "body.status.recovered": "Recovered",
        "body.status.recovering": "Recovering",
        "body.status.hours": "h",
        
        // BodyView Metrics
        "body.metric.weight": "Weight",
        "body.metric.bmi": "BMI",
        "body.metric.hr": "Resting HR",
        "body.metric.fat": "Body Fat",
        "body.metric.leanMass": "Lean Mass",
        "body.metric.vo2": "VO₂ Max",
        "body.metric.resp": "Resp. Rate",
        "body.metric.spo2": "SpO₂",
        "body.metric.temp": "Wrist Temp",
        "body.metric.fitness": "Fitness Level",
        
        // BodyView Score
        "body.score.excellent": "Excellent",
        "body.score.strong": "Strong",
        "body.score.good": "Good",
        "body.score.recovery_needed": "Recovery Needed",
        "body.score.optimal": "Optimal",
        "body.score.okay": "Okay",
        "body.score.low": "Low",
        
        // BodyView Sleep
        "body.sleep.title": "SLEEP",
        "body.sleep.tip": "Consistency is key. Try to go to bed at the same time every day.",
        
        "premium.active.title": "Movo Premium Active",
        "premium.manage": "Manage",
        "premium.upgrade.title": "Upgrade to Pro",
        "premium.upgrade.desc": "Unlock full potential",
        
        // BodyView Load
        "body.load.high": "High",
        "body.load.medium": "Medium",
        "body.load.low": "Low",
        
         // BodyView Status
        "body.status.underweight": "Underweight",
        "body.status.normal": "Normal Weight",
        "body.status.overweight": "Overweight",
        "body.status.obese": "Obese",
        
        // Common
        "common.today": "Today",
        "common.yesterday": "Yesterday",
        "common.last": "Last",
        "common.first_measurement": "First Measurement",
        
        // MARK: - Enhanced Onboarding Strings
        // BodyView Recovery
        "body.recovery.info": "Tap list for details",
        "body.recovery.noData": "No training data found.",
        "body.recovery.status.recovering": "Recovering",
        "body.recovery.status.good": "Good",
        "body.recovery.status.ready": "Ready",
        "body.recovery.status.peak": "Peak",
        "body.recovery.status.idle": "Train",
        
        "body.recovery.progress": "Recovery",
        "body.recovery.lastTraining": "Last Training",
        "body.recovery.statusLabel": "Status",
        "body.recovery.infoTitle": "Information",
        
        "body.recovery.desc.recovering": "This muscle was recently heavily used. Give it time to recover so it can grow.",
        "body.recovery.desc.good": "Recovery is underway. Light training is possible, but avoid intense load.",
        "body.recovery.desc.ready": "The muscle is almost fully recovered. You can train it again, but listen to your body.",
        "body.recovery.desc.peak": "Ideal time! The muscle is fully recovered and ready for max performance.",
        "body.recovery.desc.idle": "It's been a while. A training stimulus would be optimal now to prevent strength loss.",
        
        // Muscles
        "muscle.chest": "Chest",
        "muscle.back": "Back",
        "muscle.legs": "Legs",
        "muscle.shoulders": "Shoulders",
        "muscle.biceps": "Biceps",
        "muscle.triceps": "Triceps",
        "muscle.abs": "Abs",
        "muscle.calves": "Calves",
        "muscle.forearms": "Forearms",
        "muscle.traps": "Traps",
        "muscle.unknown": "Unknown",
        
        "muscle.glutes": "Glutes",
        "muscle.fullbody": "Full Body",
        "muscle.cardio": "Cardio",
        "muscle.lowerback": "Lower Back",
        "muscle.posteriorchain": "Posterior Chain",
        "muscle.grip": "Grip",
        "muscle.adductors": "Adductors",
        "muscle.quads": "Quads",
        "muscle.hamstrings": "Hamstrings",
        "muscle.lats": "Lats",
        "muscle.obliques": "Obliques",
        "muscle.erector_spinae": "Erector Spinae",
        "muscle.rhomboids": "Rhomboids",
        "muscle.glutes_medius": "Glutes (Medius)",
        "muscle.brachialis": "Brachialis",
        "muscle.heart": "Heart",
        "muscle.deltoids": "Deltoids",
        "muscle.core": "Core",
        "muscle.hip_flexors": "Hip Flexors",
        "muscle.rotator_cuff": "Rotator Cuff",
        "muscle.arms": "Arms",
        
        // Add Metric Sheet
        "addMetric.value": "Value",
        "addMetric.date": "Date",
        "addMetric.newEntry": "New Entry",
        "addMetric.invalidNumber": "Please enter a valid number",
        "addMetric.errorSave": "Saving not supported for this type.",
        "addMetric.add": "Add",
        
        // Movo Score
        "score.title": "MOVO SCORE",
        "score.breakdown": "Breakdown",
        "score.recovery": "Recovery",
        "score.load": "Load",
        "score.sleep": "Sleep",
        "score.activity": "Activity",
        "score.training": "Training",
        
        "score.detail.durationQuality": "Duration & Quality",
        "score.detail.stepsMovement": "Steps & Movement",
        "score.detail.workouts": "Workouts",
        "score.detail.stressRegeneration": "Stress & Regeneration",
        "score.detail.baseline": "Baseline",
        
        "score.detail.slept": "%.1fh slept",
        "score.detail.steps": "%d Steps",
        "score.detail.trainingDone": "Training done",
        "score.detail.noTraining": "No Training",
        "score.loading": "Loading...",
        "score.enterSleep": "Log Sleep",
        
        "score.detail.description": "Your Movo Score is based on your daily activity, sleep, and recovery. Try to fill all rings!",
        "score.detail.navTitle": "Score Details",
        
        // BodyView Edit
        "body.edit.title": "Edit",
        "body.edit.done": "Done",
        "body.edit.description": "Select metrics to display on the dashboard.",
        
        // Metric Details & Info
        "body.detail.verlauf": "History",
        "body.detail.trend": "Trend",
        "body.detail.avg": "Ø 7 Days",
        "body.detail.max": "Max",
        "body.detail.about": "About",
        "body.detail.understood": "Got it",
        "body.detail.measuredAt": "Measured at:",
        "body.detail.noData": "No data in this period",
        "body.detail.trend.stable": "Stable",
        "body.detail.trend.up": "Rising",
        "body.detail.trend.down": "Falling",
        
        "body.detail.info1": "This metric provides insight into your physical condition.",
        "body.detail.info2": "Values are collected from your HealthKit data or manual entries.",
        "body.detail.fitnessCalcTitle": "Fitness Level Calculation:",
        "body.detail.fitnessCalcDesc": "Your fitness level (0-100 pts) is calculated from your daily activity (steps) and completed workouts.",
        
        // Manual Sleep
        "sleep.manual.title": "Log Sleep",
        "sleep.manual.desc": "Log sleep duration for today",
        "sleep.manual.save": "Save",
        "sleep.manual.cancel": "Cancel",
        "sleep.manual.hours": "%.1f hrs",
        
        // Login Screen (EN)
        "login.welcome": "Welcome to",
        "login.tagline": "Training log, steps & challenges\nwithout frills.",
        "login.feature.training": "Training",
        "login.feature.steps": "Steps",
        "login.feature.analysis": "Analysis",
        "login.apple.signin": "Sign in with Apple",
        "login.google.continue": "Continue with Google",
        "login.email.signin": "Sign in with email",
        "login.back": "Back",
        "login.link.account": "Link account",
        "login.signin": "Sign in",
        "login.email.placeholder": "Email",
        "login.password.placeholder": "Password",
        "login.button.login": "Log in",
        "login.create.account": "Create account",
        "login.forgot.password": "Forgot password?",
        "login.error.email.required": "Please enter your email first.",
        "login.error.presenter": "Could not find presentation controller.",
        "login.error.apple.failed": "Apple login failed. Please try again.",
        "login.password.reset.sent": "Password reset email sent.",
        
        // Register Screen (EN)
        "register.link.account": "Link account",
        "register.create.account": "Create account",
        "register.password.min": "Password (min. 6 characters)",
        "register.password.repeat": "Repeat password",
        "register.accept.terms": "I accept the terms of service",
        "register.success.linked": "Account linked. Have fun!",
        "register.success.created": "Account created. Welcome!",
        "register.cancel": "Cancel",
        
        // Streaks
        "streak.title": "Streak",
        "streak.days": "Days",
        "streak.weeks": "Weeks",
        "streak.current": "Current Streak",
        "streak.best": "Best Streak",
        "streak.share": "Share Streak",
        "streak.keepGoing": "Keep it up!",
        
        // Common
        "common.done": "Done",
        "common.save": "Save",
        "common.delete": "Delete",
        "common.back": "Back",
        "common.days": "Days",
        "common.weeks": "Weeks",
        "time.daysAgo": "%d days ago",
        

        // MARK: - Enhanced Onboarding Strings
        
        // Screen 1: Welcome + Name
        "onboarding.welcome": "Welcome to",
        "onboarding.welcome.subtitle": "Let's personalize your fitness journey",
        "onboarding.welcome.message": "Your Personal Fitness Tracker",
        "onboarding.welcome.description": "Achieve your goals with personalized training plans and detailed statistics",
        "onboarding.name.question": "What should we call you?",
        "onboarding.name.placeholder": "Your name",
        "onboarding.letsgo": "Let's Go!",
        
        // Screen 2: Fitness Goals
        "onboarding.goals.title": "What are your fitness goals?",
        "onboarding.goals.subtitle": "Select all that apply",
        "onboarding.goal.loseWeight": "Lose Weight",
        "onboarding.goal.loseWeight.desc": "Reduce body fat and get leaner",
        "onboarding.goal.buildMuscle": "Build Muscle",
        "onboarding.goal.buildMuscle.desc": "Increase muscle mass and definition",
        "onboarding.goal.stayFit": "Stay Fit",
        "onboarding.goal.stayFit.desc": "Maintain health and fitness",
        "onboarding.goal.gainStrength": "Gain Strength",
        "onboarding.goal.gainStrength.desc": "Improve maximum strength and power",
        "onboarding.goal.improveEndurance": "Improve Endurance",
        "onboarding.goal.improveEndurance.desc": "Boost stamina and conditioning",
        
        // Screen 3: Experience Level
        "onboarding.level.title": "What's your experience level?",
        "onboarding.level.subtitle": "Helps us give you better recommendations",
        "onboarding.level.beginner": "Beginner",
        "onboarding.level.beginner.desc": "New to fitness or getting back into it",
        "onboarding.level.intermediate": "Intermediate",
        "onboarding.level.intermediate.desc": "Training regularly for 6+ months",
        "onboarding.level.advanced": "Advanced",
        "onboarding.level.advanced.desc": "Experienced athlete with consistent training",
        
        // Screen 4: Training Frequency
        "onboarding.frequency.title": "Let's commit to achieving your goals!",
        "onboarding.frequency.subtitle": "How many times per week will you train?",
        "onboarding.frequency.perweek": "per week",
        "onboarding.frequency.times": "%dx per week",
        
        // Screen 5: Personal Questions
        "onboarding.personal.title": "A few more details",
        "onboarding.personal.subtitle": "For better recommendations (optional)",
        "onboarding.personal.age": "Age",
        "onboarding.personal.gender": "Gender",
        "onboarding.personal.equipment": "Available Equipment",
        "onboarding.personal.location": "Training Location",
        "onboarding.gender.male": "Male",
        "onboarding.gender.female": "Female",
        "onboarding.gender.other": "Other",
        "onboarding.gender.preferNotToSay": "Prefer not to say",
        "onboarding.equipment.fullGym": "Full Gym",
        "onboarding.equipment.dumbbells": "Dumbbells",
        "onboarding.equipment.barbell": "Barbell",
        "onboarding.equipment.kettlebell": "Kettlebell",
        "onboarding.equipment.resistanceBands": "Resistance Bands",
        "onboarding.equipment.bodyweight": "Bodyweight Only",
        "onboarding.location.gym": "Gym",
        "onboarding.location.home": "Home",
        "onboarding.location.outdoor": "Outdoor",
        
        // Screen 6: Muscle Focus
        "onboarding.focus.title": "Which areas do you want to focus on?",
        "onboarding.focus.subtitle": "Tap on muscle groups",
        "onboarding.focus.fullbody": "Full Body Training",
        "onboarding.focus.selected": "%d muscle groups selected",
        
        // Screen 7: Ranked System Showcase
        "onboarding.ranked.title": "Get Stronger",
        "onboarding.ranked.subtitle": "Track your progress for every muscle group",
        "onboarding.ranked.start": "Start",
        "onboarding.ranked.now": "Now",
        "onboarding.ranked.progress": "12 months progress",
        "onboarding.ranked.feature1": "Individual ranks for each muscle group",
        "onboarding.ranked.feature2": "Track your development over time",
        "onboarding.ranked.feature3": "Unlock badges and levels",
        
        // Screen 8: Apple Watch Showcase
        "onboarding.watch.title": "Train Smarter with Apple Watch",
        "onboarding.watch.subtitle": "Perfect integration for your wrist",
        "onboarding.watch.sets": "Sets",
        "onboarding.watch.kg": "kg",
        "onboarding.watch.time": "Time",
        "onboarding.watch.feature1": "Real-time heart rate tracking",
        "onboarding.watch.feature2": "Live Activities on Dynamic Island",
        "onboarding.watch.feature3": "Seamless sync across devices",
        
        // Screen 9: Templates Showcase
        "onboarding.templates.title": "Create Your First Training Template",
        "onboarding.templates.subtitle": "Save time with pre-made workouts",
        "onboarding.templates.create": "Template Name",
        "onboarding.templates.name": "e.g. Upper Body Day",
        "onboarding.templates.exercises": "Select Exercises",
        "onboarding.templates.selected": "%d exercises selected",
        "onboarding.templates.feature1": "Quick start your favorite workouts",
        "onboarding.templates.feature2": "Create unlimited custom templates",
        "onboarding.templates.feature3": "Share templates with friends",
        
        // Screen 10: Activity Window Showcase
        "onboarding.activity.title": "Discover Your Training Patterns",
        "onboarding.activity.subtitle": "Find out when you train best",
        "onboarding.activity.heatmap": "Activity Heatmap",
        "onboarding.activity.feature1": "Identify your best training times",
        "onboarding.activity.feature2": "Visualize trained muscle groups",
        "onboarding.activity.feature3": "Detailed statistics and insights",
        
        // Screen 11: Social Proof
        "onboarding.social.badge": "7K+ 5★ Reviews",
        "onboarding.social.mission": "Our mission is to help 10 million people achieve their fitness goals",
        "onboarding.social.review1.title": "This app is amazing",
        "onboarding.social.review1.text": "This app is genuinely so underrated. There is no other app that does workout logging this well!",
        "onboarding.social.review2.title": "Best workout tracker",
        "onboarding.social.review2.text": "I've been using Movo for 3 months now. Tried Jefit, Strong and Hevy, but Movo is the clear winner!",
        
        // Screen 12: Hard Paywall
        "onboarding.paywall.title": "Design Your Trial Experience",
        "onboarding.paywall.subtitle": "7 days free, then you decide",
        "onboarding.paywall.timeline.title": "What to expect in your trial week:",
        "onboarding.paywall.timeline.today": "Today – Unlock All Features",
        "onboarding.paywall.timeline.today.desc": "Immediate access to all Pro features",
        "onboarding.paywall.timeline.day5": "Day 5 – Reminder",
        "onboarding.paywall.timeline.day5.desc": "We'll remind you before trial ends",
        "onboarding.paywall.timeline.day7": "Day 7 – Your Decision",
        "onboarding.paywall.timeline.day7.desc": "You're only charged if you don't cancel",
        "onboarding.paywall.recommended": "RECOMMENDED",
        "onboarding.paywall.onetime": "ONE-TIME",
        "onboarding.paywall.peryear": "per year",
        "onboarding.paywall.permonth": "per month",
        "onboarding.paywall.lifetime": "one-time",
        "onboarding.paywall.trial.desc": "7 days free, then %@/year",
        "onboarding.paywall.yearly.desc": "Best value for money",
        "onboarding.paywall.monthly.desc": "Maximum flexibility, cancel anytime",
        "onboarding.paywall.lifetime.desc": "Pay once, use forever",
        "onboarding.paywall.disclaimer": "One-time purchase or subscription. Cancel anytime. Prices may vary.",
        "onboarding.paywall.cta.trial": "Start 7-Day Trial",
        "onboarding.paywall.cta.yearly": "Subscribe Yearly",
        "onboarding.paywall.cta.monthly": "Subscribe Monthly",
        "onboarding.paywall.cta.lifetime": "Buy Lifetime",
        "onboarding.paywall.cancel": "Cancel anytime • No risk",
        
        // Screen 13: Subscription Confirmation
        "onboarding.confirm.title": "Start Your Journey",
        "onboarding.confirm.subtitle": "Confirm your selection",
        "onboarding.confirm.plan": "Selected Plan",
        "onboarding.confirm.feature1": "Unlimited access to all features",
        "onboarding.confirm.feature2": "Advanced statistics & PR tracking",
        "onboarding.confirm.feature3": "Apple Watch integration",
        "onboarding.confirm.feature4": "Widgets & Live Activities",
        "onboarding.confirm.feature5": "Muscle Ranking System",
        "onboarding.confirm.starttrial": "Start 7-Day Trial",
        "onboarding.confirm.subscribe": "Subscribe Now",
        "onboarding.confirm.buy": "Buy Now",
        "onboarding.confirm.secure": "Secure payment via Apple",
        "onboarding.confirm.error": "Purchase failed. Please try again.",
        "onboarding.plan.yearly": "Yearly",
        "onboarding.plan.monthly": "Monthly",
        "onboarding.plan.lifetime": "Lifetime",
        
        // Screen 14: Personal Setup
        "onboarding.setup.title": "Personalize Your Experience",
        "onboarding.setup.subtitle": "Almost done, %@!",
        "onboarding.setup.unit": "Weight Unit",
        "onboarding.setup.weight": "Current Weight",
        "onboarding.setup.height": "Height",
        "onboarding.setup.steps": "Daily Steps Goal",
        
        // Screen 15: Permissions
        "onboarding.permissions.title": "Enable Features",
        "onboarding.permissions.subtitle": "Grant access for the full Movo experience",
        "onboarding.permissions.health": "Apple Health",
        "onboarding.permissions.health.desc": "Sync steps, calories, workouts and more",
        "onboarding.permissions.notifications": "Notifications",
        "onboarding.permissions.notifications.desc": "Get reminders for rest timers and streaks",
        "onboarding.permissions.tap": "Tap 'Continue' to grant permissions",
        
        // Screen 16: Final
        "onboarding.final.title": "You're All Set, %@!",
        "onboarding.final.subtitle": "Welcome to Movo.\\nLet's build something amazing together.",
        "onboarding.final.goals": "Your Goals: %d selected",
        "onboarding.final.frequency": "Training Frequency: %dx per week",
        "onboarding.final.plan.yearly": "Movo Pro (7-Day Trial)",
        "onboarding.final.plan.monthly": "Movo Pro (Monthly)",
        "onboarding.final.plan.lifetime": "Movo Pro (Lifetime)",
        "onboarding.final.motivation": "Let's build something amazing together 💪",
        
        

        "tab.training"  : "Workouts",
        "tab.exercises" : "Exercises",
        "tab.challenges": "Challenges",
        "tab.history"   : "History",
        "tab.stats"     : "Stats",

        // Common
        "common.more" : "More",
        "common.less" : "Less",
        "start.training": "Start Training",

        // Statistics: Locked messages
        "statistics.locked.duration"        : "With Movo Pro you can see your training duration per day here.",
        "statistics.locked.workoutsPerWeek" : "With Movo Pro you can see how many workouts you complete per week.",
        "statistics.locked.topExercises"    : "With Movo Pro you can see your top exercises and total volume.",
        "statistics.locked.exerciseStats"   : "Pick an exercise and see all details with Movo Pro.",

        // Statistics: Premium Teaser
        "statistics.premium.title"           : "Premium stats",
        "statistics.premium.subtitle"        : "Beta: All Pro features are currently free.",
        "statistics.premium.feature.charts"  : "Advanced charts & trends",
        "statistics.premium.feature.records" : "Best session & records",
        "statistics.premium.feature.duration": "Duration, volume, top exercises",
        "statistics.premium.feature.widgets" : "Home screen widgets",
        "statistics.premium.cta"             : "Unlock for free",

        // Paywall / Toolbar
        "paywall.openPremium" : "Open Premium",

        "sleep.noData.short" : "No data",
        "rank.0": "Wood",
        "rank.1": "Bronze",
        "rank.2": "Gold",
        "rank.3": "Platinum",
        "rank.4": "Diamond",
        "rank.5": "Champion",
        "rank.6": "Titan",
        "rank.7": "Olympian",

        // Legend / Statistics texts
        "statistics.level.yours": "Your Level",
        "statistics.compare": "Compare",
        "statistics.compare.hide": "Hide Comparison",
        "statistics.compare.start": "Start",
        "statistics.compare.now": "Now",

        "statistics.legend.title": "Legend",
        "statistics.legend.info": "Colored areas show which muscle groups you trained and how often.",
        "statistics.legend.close": "Close",
        "statistics.rank.start": "Start",
        "statistics.rank.threshold": "from %d points",

        // Muscle regions
        "muscle.region.chest": "Chest",
        "muscle.region.shoulders": "Shoulders",
        "muscle.region.biceps": "Biceps",
        "muscle.region.triceps": "Triceps",
        "muscle.region.lats": "Lats",
        "muscle.region.abs": "Abs",
        "muscle.region.quads": "Quads",
        "muscle.region.hamstrings": "Hamstrings",
        "muscle.region.glutes": "Glutes",
        "muscle.region.calves": "Calves",
        "muscle.region.calvesBack": "Calves (back)",
        "muscle.region.forearms": "Forearms",
        "muscle.region.traps": "Traps",
        "muscle.region.lowerBack": "Lower Back",

        // Home – next rank card
        "home.nextLevel": "Next Level",
        "home.until": "until",
        "home.training.singular": "training",
        "home.training.plural": "trainings",

        // MuscleMapSummary
      
        
        "statistics.musclemap.current" : "This Week",
        "statistics.musclemap.previous" : "Last Week",
        "statistics.musclemap.last7.prevWeek" : "Last 7 days (last week)",


        "dashboard.goalSettings.title" : "Goals",
        "dashboard.goalSettings.weeklyWorkouts" : "Workouts per week",
        "dashboard.goalSettings.weeklyWorkouts.value" : "%d/week",
        "dashboard.goalSettings.weight" : "Weight goal",

        
            // DE: "/ %d Workouts"
     
        "time.mmss" : "%dm %02ds",   // DE: "%dmin %02ds"

        
        // Workout & Flow
        "howto.neck_rolls.note.1" : "Be very gentle; avoid pushing into end range or pain.",
        
        
        "settings.account.delete.message" : "This will permanently remove your profile, training data, and the login account.",
        "settings.account.delete.failed" : "Deletion failed",
        "settings.account.delete.progress" : "Deleting account…",
        "profile.photo.remove" : "Remove profile photo",


        "howto.childs_pose.note.1" : "Hips toward heels, arms long; relax the shoulders.",
        "howto.deep_breathing.note.1" : "Breathe through the nose; 360° rib expansion, slow relaxed exhale.",
        "howto.half_standing_forward_fold.note.1" : "Hang loosely and keep it pain-free.",
        "howto.happy_baby.note.1" : "Knees toward armpits, back stays on the floor; breathe calmly.",
        "howto.spinal_twist_liegend.note.1" : "Keep both shoulders as close to the floor as possible.",
        "howto.cobra_stretch.note.1" : "Keep elbows soft; move only within a pain-free range.",


    

          "howto.generic.setup.1": "Stable stance/surface, sufficient space and light.",
          "howto.generic.setup.2": "Warm up and check your range of motion.",
          "howto.generic.execution.1": "Move with control; avoid using momentum.",
          "howto.generic.execution.2": "Neutral spine; keep joints aligned.",
          "howto.generic.breathing.1": "Inhale calmly; exhale on exertion.",
          "howto.generic.breathing.2": "Don’t hold your breath — keep it steady.",
          "howto.generic.mistakes.1": "Reps too fast / lack of control.",
          "howto.generic.mistakes.2": "Pushing into pain instead of adjusting range.",

          "howto.defaults.push.mistakes.2": "Sagging midline (excessive arch).",
          "howto.defaults.push.progressions.1": "Easier: on knees; hands elevated (box/bench).",
          "howto.defaults.push.progressions.2": "Harder: narrower stance, tempo/paused reps, explosive.",
          "howto.defaults.push.cues.1": "Broad shoulder blades; forearms vertical.",
          "howto.defaults.push.cues.2": "Actively push the floor away.",

        
        "lastTraining.title": "Training history",
        "lastTraining.header": "Last training",
        "lastTraining.none": "No trainings yet",

        "lastTraining.stat.totalSessions": "Total sessions",
        "lastTraining.stat.thisWeek": "This week",
        "lastTraining.stat.currentStreak": "Current streak",
        "lastTraining.stat.currentStreak.value": "%d days",
        "lastTraining.stat.avgPerWeek": "Average per week",
        "lastTraining.stat.avgPerWeek.value": "%.1f / week",

        "lastTraining.recent.title": "Recent sessions",
        "lastTraining.empty.title": "No trainings",
        "lastTraining.empty.description": "Start your first training to track your progress!",

        
        "templates.empty.createButton" : "Create template",
        "templates.favorites.title": "Favorites on Home",
        "templates.favorites.desc": "Pin your most important routines to start them directly here.",
        "templates.favorites.select": "Select Routines",
        
        
        "lastTraining.motivation.30": "Unstoppable champion! 🏆",
        "lastTraining.motivation.14": "You're on fire! 🔥",
        "lastTraining.motivation.7": "One week streak! ⭐",
        "lastTraining.motivation.50": "Consistency pays off! 💪",
        "lastTraining.motivation.20": "Building momentum! 🚀",
        "lastTraining.motivation.default": "Every rep counts! 💯",

        "lastTraining.motivation.sub.streak7": "Keep the streak alive!",
        "lastTraining.motivation.sub.weekGood": "Amazing week!",
        "lastTraining.motivation.sub.default": "You're making progress!",

        "date.today": "Today",
        "date.yesterday": "Yesterday",
        "date.daysAgo": "%d days ago",
        "date.oneWeekAgo": "1 week ago",
        "date.weeksAgo": "%d weeks ago",

        "home.weeklyGoal.title" : "Weekly goal",
        "home.weeklyGoal.progress" : "/%d workouts",

        "weight.card.title" : "Weight, kg",
        "weight.card.goalPrefix" : "Weight Goal:",



        "time.minutes.short": "%d min",
        "time.hoursMinutes.short": "%dh %dm",

        
          "howto.defaults.hinge.breathing.1": "Inhale at the top; exhale through the drive up.",
          "howto.defaults.hinge.breathing.2": "Create abdominal pressure; keep the back long.",
          "howto.defaults.hinge.mistakes.1": "Rounding the back; knees travel too far forward.",
          "howto.defaults.hinge.mistakes.2": "Going too deep → losing neutral alignment.",
          "howto.defaults.hinge.progressions.1": "Easier: smaller range; hands on hips (feedback).",
          "howto.defaults.hinge.progressions.2": "Harder: 3–1–1 tempo; isometric hold at bottom.",
          "howto.defaults.hinge.cues.1": "Hips back; crown of head long forward.",
          "howto.defaults.hinge.cues.2": "Load midfoot/heel.",

          "howto.defaults.squat.breathing.1": "Inhale on descent; exhale as you rise.",
          "howto.defaults.squat.breathing.2": "Optional brief brace before standing up.",
          "howto.defaults.squat.mistakes.1": "Knees collapsing inward; heels lifting.",
          "howto.defaults.squat.mistakes.2": "Reversing too fast at the bottom.",
          "howto.defaults.squat.progressions.1": "Easier: box squat / limit depth.",
          "howto.defaults.squat.progressions.2": "Harder: tempo/paused reps; jump squats.",
          "howto.defaults.squat.cues.1": "Knees track in toe direction.",
          "howto.defaults.squat.cues.2": "Drive through midfoot/heel.",

    

        
          "howto.defaults.lunge.breathing.1": "Inhale on descent; exhale as you stand up.",
          "howto.defaults.lunge.breathing.2": "Keep the core stable; pelvis quiet.",
          "howto.defaults.lunge.mistakes.1": "Front knee caving inward.",
          "howto.defaults.lunge.mistakes.2": "Torso leaning forward too much.",
          "howto.defaults.lunge.progressions.1": "Easier: smaller step; pause at the top.",
          "howto.defaults.lunge.progressions.2": "Harder: tempo/paused; jump variations.",
          "howto.defaults.lunge.cues.1": "Long spine; neutral gaze.",
          "howto.defaults.lunge.cues.2": "Drive back through the front heel.",

          "howto.defaults.strength.breathing.1": "Breathe steadily; exhale on exertion.",
          "howto.defaults.strength.breathing.2": "Brace the core for stability.",
          "howto.defaults.strength.mistakes.1": "Using momentum instead of control.",
          "howto.defaults.strength.mistakes.2": "Ignoring pain instead of adjusting range.",
          "howto.defaults.strength.progressions.1": "Easier: reduce range/lever.",
          "howto.defaults.strength.progressions.2": "Harder: lengthen lever / slow the tempo.",
          "howto.defaults.strength.cues.1": "Smooth motion; neutral joint paths.",
          "howto.defaults.strength.cues.2": "Quality over rep count.",

          "howto.defaults.breathwork.breathing.1": "Nasal inhale; calm, longer exhale through the mouth.",
          "howto.defaults.breathwork.breathing.2": "Keep a steady rhythm; shoulders relaxed.",
          "howto.defaults.breathwork.mistakes.1": "Holding the breath or panting.",
          "howto.defaults.breathwork.mistakes.2": "Shrugging shoulders; neck tension.",
          "howto.defaults.breathwork.progressions.1": "Easier: shorten the cycles.",
          "howto.defaults.breathwork.progressions.2": "Harder: lengthen cycles (e.g., 4–6–6–4).",
          "howto.defaults.breathwork.cues.1": "Gentle, quiet, even.",
          "howto.defaults.breathwork.cues.2": "Focus on belly and rib movement.",

          "howto.title.jump_squats": "Jump Squats",
          "howto.title.kniebeugen": "Squats",
          "howto.title.plank": "Plank",

          "howto.jump_squats.ausfuehrung.1": "Jump up explosively from the squat.",
          "howto.jump_squats.ausfuehrung.2": "Land softly and stay braced.",
        
          
                 "howto.lottie.notFound.body": "Animation “%@” not found.",
                 "howto.note.title": "Note",
                 "howto.note.noSource": "No Lottie source found for “%@”.",
                 "howto.note.addFile": "Add a “%@.lottie” or “%@.json” file to the bundle.",


        "calories.title" : "Calories",
        "calories.activeEnergy" : "Active Energy",
        "calories.activityTrend" : "Activity Trend",
        "calories.noData.title" : "No Data",
        "calories.noData.description" : "No calorie data available for this period.",
        "calories.dailyHistory" : "Daily History",
        "calories.unit" : "Calories",

        "unit.kcal" : "kcal",

        "common.sleep" : "Sleep",
        "common.water" : "Water",
        "common.weight" :"Weight",

        "dashboard.lastTraining": "Last Training",
        "dashboard.myDashboard" : "My Dashboard",
        "dashboard.additionalStats" : "Additional Stats",
        "dashboard.editTitle" : "Edit Dashboard",


        "statistics.bestDay" : "Best Day",
        "statistics.days" : "Days",
  
          
          /* Section titles (falls noch nicht in EN vorhanden) */
    

          "howto.section.ausfuehrung" : "Execution",
          "howto.section.atmung" : "Breathing",
                
          "howto.section.coaching_cues" : "Coaching Cues",
          "howto.section.hinweis" : "Note",
          "howto.section.tempo" : "Tempo",
          "howto.section.power" : "Power",
          "howto.section.pattern" : "Pattern",
          "howto.section.progression" : "Progression",
          "howto.section.safety" : "Safety",

          
        "paywall.title" : "Unlock Statistics",
        "paywall.bullet.best" : "Best session & weekly view",
        "paywall.bullet.total" : "Total weight & volume charts",
        "paywall.bullet.top" : "Top exercises & PR timeline",
        "paywall.bullet.details" : "Detailed stats per exercise",
        "paywall.unlock" : "Unlock (one-time)",
        "paywall.restoring" : "Unlocking…",

        
        

        
        
          /* Execution aliases for all exercises */

          /* Jumping Jacks */
          "howto.jumping_jacks.execution.1" : "Open chest, stay tall; move arms actively.",
          "howto.jumping_jacks.execution.2" : "Land softly on the balls of your feet; keep a steady rhythm.",

          /* High Knees */
          "howto.high_knees.execution.1" : "Open chest, stay tall; move arms actively.",
          "howto.high_knees.execution.2" : "Land softly on the balls of your feet; keep a steady rhythm.",

          /* Butt Kicks */
          "howto.butt_kicks.execution.1" : "Open chest, stay tall; move arms actively.",
          "howto.butt_kicks.execution.2" : "Land softly on the balls of your feet; keep a steady rhythm.",

          /* Burpees (leicht) */
          "howto.burpees_leicht.execution.1" : "Open chest, stay tall; move arms actively.",
          "howto.burpees_leicht.execution.2" : "Land softly on the balls of your feet; keep a steady rhythm.",

          /* Burpees */
          "howto.burpees.execution.1" : "Open chest, stay tall; move arms actively.",
          "howto.burpees.execution.2" : "Land softly on the balls of your feet; keep a steady rhythm.",

          /* Mountain Climbers */
          "howto.mountain_climbers.execution.1" : "Open chest, stay tall; move arms actively.",
          "howto.mountain_climbers.execution.2" : "Land softly on the balls of your feet; keep a steady rhythm.",

        "common.search" : "Search",
        
        "training.discardConfirm" : "Do you really want to discard this workout?",


          /* Arm Circles */
          "howto.arm_circles.execution.1" : "Move smoothly with full-body tension.",
          "howto.arm_circles.execution.2" : "Keep alignment and control throughout the range.",

          /* Arm Circles rückwärts */
          "howto.arm_circles_rueckwaerts.execution.1" : "Move smoothly with full-body tension.",
          "howto.arm_circles_rueckwaerts.execution.2" : "Keep alignment and control throughout the range.",

          /* Arm Circles groß */
          "howto.arm_circles_gross.execution.1" : "Move smoothly with full-body tension.",
          "howto.arm_circles_gross.execution.2" : "Keep alignment and control throughout the range.",

          /* Arm Swings */
          "howto.arm_swings.execution.1" : "Move smoothly with full-body tension.",
          "howto.arm_swings.execution.2" : "Keep alignment and control throughout the range.",

          /* Hip Opener */
          "howto.hip_opener.execution.1" : "Move smoothly with full-body tension.",
          "howto.hip_opener.execution.2" : "Keep alignment and control throughout the range.",

          /* Shoulder Stretch */
          "howto.shoulder_stretch.execution.1" : "Move smoothly with full-body tension.",
          "howto.shoulder_stretch.execution.2" : "Keep alignment and control throughout the range.",

          /* Torso Twists */
          "howto.torso_twists.execution.1" : "Move smoothly with full-body tension.",
          "howto.torso_twists.execution.2" : "Keep alignment and control throughout the range.",

          /* Leichte Nacken- & Schulterkreise */
          "howto.leichte_nacken_und_schulterkreise.execution.1" : "Move smoothly with full-body tension.",
          "howto.leichte_nacken_und_schulterkreise.execution.2" : "Keep alignment and control throughout the range.",

          /* Kniebeugen */
          "howto.kniebeugen.execution.1" : "Sit hips back and down; knees track in line with toes.",
          "howto.kniebeugen.execution.2" : "Stand up by driving through mid-foot/heels; stay tall.",

          /* Ausfallschritte */
          "howto.ausfallschritte.execution.1" : "Take a long step; lower until both knees are about 90°.",
          "howto.ausfallschritte.execution.2" : "Drive up through the front heel; keep the torso tall.",

        "statistics.activity" : "Activity",

          /* Side Lunges */
          "howto.side_lunges.execution.1" : "Take a long step; lower until both knees are about 90°.",
          "howto.side_lunges.execution.2" : "Drive up through the front heel; keep the torso tall.",

          /* Bulgarian Split Squats (ohne Erhöhung) */
          "howto.bulgarian_split_squats_ohne_erhoehung.execution.1" : "Sit hips back and down; knees track in line with toes.",
          "howto.bulgarian_split_squats_ohne_erhoehung.execution.2" : "Stand up by driving through mid-foot/heels; stay tall.",

        "home.training.inProgress.prefix" : "Active workout",
        "exercise.arnold_press_dumbbell": "Arnold Press (Dumbbell)",
        "exercise.bench_press_barbell": "Bench Press (Barbell)",
        "exercise.incline_bench_press_barbell": "Incline Bench Press (Barbell)",
        "exercise.bench_press_dumbbell": "Bench Press (Dumbbell)",
        "exercise.incline_bench_press_dumbbell": "Incline Bench Press (Dumbbell)",
        "exercise.chest_fly_cable": "Chest Fly (Cable)",
        "exercise.chest_press_machine": "Chest Press (Machine)",
        "exercise.push_up": "Push Up",
        "exercise.dip": "Dip",
        "exercise.squat_barbell": "Squat (Barbell)",
        "exercise.front_squat_barbell": "Front Squat (Barbell)",
        "exercise.leg_press": "Leg Press",
        "exercise.leg_extension": "Leg Extension",
        "exercise.leg_curl_lying": "Leg Curl (Lying)",
        "exercise.deadlift_barbell": "Deadlift (Barbell)",
        "exercise.romanian_deadlift_dumbbell": "Romanian Deadlift (Dumbbell)",
        "exercise.bulgarian_split_squat": "Bulgarian Split Squat",
        "exercise.calf_raise_standing": "Calf Raise (Standing)",
        "exercise.pull_up": "Pull Up",
        "exercise.lat_pulldown_cable": "Lat Pulldown (Cable)",
        "exercise.seated_row_cable": "Seated Row (Cable)",
        "exercise.bent_over_row_barbell": "Bent Over Row (Barbell)",
        "exercise.face_pull": "Face Pull",
        "exercise.overhead_press_barbell": "Overhead Press (Barbell)",
        "exercise.shoulder_press_dumbbell": "Shoulder Press (Dumbbell)",
        "exercise.lateral_raise_dumbbell": "Lateral Raise (Dumbbell)",
        "exercise.bicep_curl_barbell": "Bicep Curl (Barbell)",
        "exercise.bicep_curl_dumbbell": "Bicep Curl (Dumbbell)",
        "exercise.hammer_curl": "Hammer Curl",
        "exercise.triceps_pushdown_cable": "Triceps Pushdown (Cable)",
        "exercise.skullcrusher_ez_bar": "Skullcrusher (Ez-Bar)",
        "exercise.plank": "Plank",
        "exercise.crunch": "Crunch",
        "exercise.hanging_leg_raise": "Hanging Leg Raise",
        "exercise.running_treadmill": "Running (Treadmill)",
        "exercise.cycling_indoor": "Cycling (Indoor)",
        "exercise.rowing_machine": "Rowing Machine",
        "exercise.jump_rope": "Jump Rope",
        "exercise.yoga": "Yoga",
        "exercise.stretching": "Stretching",
        "exercise.hip_thrust_barbell": "Hip Thrust (Barbell)",
        
        "exercise.close_grip_bench": "Close-Grip Bench Press",
        "exercise.side_plank": "Side Plank",
        "exercise.good_morning": "Good Morning",
        "exercise.farmers_walk": "Farmer's Walk",

        "exercise.ab_crunch_machine": "Ab Crunch Machine",
        "exercise.ab_crunch_machine.instr": "Sit in machine, crunch forward using abdominals.",

        
        "weight.details.title": "Weight details",
        "weight.chart.trend": "Trend",
        "weight.empty.title": "No data",
        "weight.empty.description": "No weight data found for this period.",
        "weight.stat.average": "Average",
        "weight.stat.minimum": "Minimum",
        "weight.stat.maximum": "Maximum",
        "weight.stat.entries": "Entries",
        "weight.history.title": "History",

        "range.7days": "7 days",
        "range.30days": "30 days",
        "range.90days": "90 days",

          /* Jump Squats */
          "howto.jump_squats.execution.1" : "Sit hips back and down; knees track in line with toes.",
          "howto.jump_squats.execution.2" : "Stand up by driving through mid-foot/heels; stay tall.",

          /* Hip Hinge / Good Mornings */
          "howto.hip_hinge_good_mornings.execution.1" : "Initiate by pushing the hips back; shins fairly vertical.",
          "howto.hip_hinge_good_mornings.execution.2" : "Stand up by driving through the heels; spine stays long.",

          /* Good Mornings (langsam) */
          "howto.good_mornings_langsam.execution.1" : "Initiate by pushing the hips back; shins fairly vertical.",
          "howto.good_mornings_langsam.execution.2" : "Stand up by driving through the heels; spine stays long.",

          /* Liegestütze */
          "howto.liegestuetze.execution.1" : "Lower with control to about 45° elbows.",
          "howto.liegestuetze.execution.2" : "Press the floor away; keep body in a straight line.",

          /* Enge Liegestütze (Trizeps) */
          "howto.enge_liegestuetze_trizeps.execution.1" : "Lower with control to about 45° elbows.",
          "howto.enge_liegestuetze_trizeps.execution.2" : "Press the floor away; keep body in a straight line.",

          /* Liegestütze (Tempo 3-1-1) */
          "howto.liegestuetze_tempo_3_1_1.execution.1" : "Lower with control to about 45° elbows.",
          "howto.liegestuetze_tempo_3_1_1.execution.2" : "Press the floor away; keep body in a straight line.",

          /* Liegestütze mit Klatschen */
          "howto.liegestuetze_mit_klatschen.execution.1" : "Lower with control to about 45° elbows.",
          "howto.liegestuetze_mit_klatschen.execution.2" : "Press the floor away; keep body in a straight line.",

          /* Pike Push-ups */
          "howto.pike_push_ups.execution.1" : "Lower with control to about 45° elbows.",
          "howto.pike_push_ups.execution.2" : "Press the floor away; keep body in a straight line.",

          /* Plank mit Schulter-Taps */
          "howto.plank_mit_schulter_taps.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.plank_mit_schulter_taps.execution.2" : "Move slow and controlled; avoid arching the lower back.",

        
        "paywall.plan.lifetime.price" : " 9,99Є one-time",

          /* Superman Pulls */
          "howto.superman_pulls.execution.1" : "Lift through the upper back; draw shoulder blades down and back.",
          "howto.superman_pulls.execution.2" : "Keep the gaze down; neck neutral throughout.",

          /* Superman Hold */
          "howto.superman_hold.execution.1" : "Lift through the upper back; draw shoulder blades down and back.",
          "howto.superman_hold.execution.2" : "Keep the gaze down; neck neutral throughout.",

          /* Prone W-Raises */
          "howto.prone_w_raises.execution.1" : "Lift through the upper back; draw shoulder blades down and back.",
          "howto.prone_w_raises.execution.2" : "Keep the gaze down; neck neutral throughout.",

          /* Reverse Snow Angels */
          "howto.reverse_snow_angels.execution.1" : "Lift through the upper back; draw shoulder blades down and back.",
          "howto.reverse_snow_angels.execution.2" : "Keep the gaze down; neck neutral throughout.",

          /* Plank */
          "howto.plank.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.plank.execution.2" : "Move slow and controlled; avoid arching the lower back.",

          /* Plank (fortgeschritten) */
          "howto.plank_fortgeschritten.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.plank_fortgeschritten.execution.2" : "Move slow and controlled; avoid arching the lower back.",

          /* Plank mit Beinheben */
          "howto.plank_mit_beinheben.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.plank_mit_beinheben.execution.2" : "Move slow and controlled; avoid arching the lower back.",

          /* Bicycle Crunches */
          "howto.bicycle_crunches.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.bicycle_crunches.execution.2" : "Move slow and controlled; avoid arching the lower back.",

          /* Reverse Crunches */
          "howto.reverse_crunches.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.reverse_crunches.execution.2" : "Move slow and controlled; avoid arching the lower back.",

        
        
        /* ===================== en ===================== */

        /* No results / offer request */
        "exercises.noResults.title" : "No results for “%@”",
        "exercises.noResults.subtitle" : "Would you like to request this exercise?",
        "exercises.request.button" : "Request new exercise",

        /* Request sheet */
        "exercises.request.title" : "Request new exercise",
        "exercises.request.form.exercise" : "Exercise",
        "exercises.request.form.namePlaceholder" : "Exercise name",
        "exercises.request.form.detailsHeader" : "Details (optional)",
        "exercises.request.form.footer" : "We use your search term to understand the context.",

        /* Alerts */
        "exercises.request.alert.success.title" : "Thanks!",
        "exercises.request.alert.success.message" : "Your request has been saved.",
        "exercises.request.alert.error.title" : "Error sending request",

        /* General (if not present yet) */
       
        "search.clear" : "Clear search",
     
        "common.send" : "Send",

          /* Crunches */
          "howto.crunches.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.crunches.execution.2" : "Move slow and controlled; avoid arching the lower back.",

          /* Side Plank */
          "howto.side_plank.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.side_plank.execution.2" : "Move slow and controlled; avoid arching the lower back.",

          /* Side Plank mit Hüftheben */
          "howto.side_plank_mit_hueftheben.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.side_plank_mit_hueftheben.execution.2" : "Move slow and controlled; avoid arching the lower back.",

          /* Plank Walkouts */
          "howto.plank_walkouts.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.plank_walkouts.execution.2" : "Move slow and controlled; avoid arching the lower back.",

          /* Hollow Hold */
          "howto.hollow_hold.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.hollow_hold.execution.2" : "Move slow and controlled; avoid arching the lower back.",

          /* Hollow Rock (leicht) */
          "howto.hollow_rock_leicht.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.hollow_rock_leicht.execution.2" : "Move slow and controlled; avoid arching the lower back.",

        "startMenu.comingSoon" : "Coming soon",

        
        "statistics.activity.subtitle" : "%d workouts this year",

          /* Toe Touches */
          "howto.toe_touches.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.toe_touches.execution.2" : "Move slow and controlled; avoid arching the lower back.",

          /* Russian Twists */
          "howto.russian_twists.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.russian_twists.execution.2" : "Move slow and controlled; avoid arching the lower back.",

          /* Dead Bug (aktivieren) */
          "howto.dead_bug_aktivieren.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.dead_bug_aktivieren.execution.2" : "Move slow and controlled; avoid arching the lower back.",

          /* Hip Bridges */
          "howto.hip_bridges.execution.1" : "Move smoothly with full-body tension.",
          "howto.hip_bridges.execution.2" : "Keep alignment and control throughout the range.",

          /* Glute Bridge March */
          "howto.glute_bridge_march.execution.1" : "Move smoothly with full-body tension.",
          "howto.glute_bridge_march.execution.2" : "Keep alignment and control throughout the range.",

          /* Bird Dog */
          "howto.bird_dog.execution.1" : "Move smoothly with full-body tension.",
          "howto.bird_dog.execution.2" : "Keep alignment and control throughout the range.",

          /* Cat-Cow */
          "howto.cat_cow.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.cat_cow.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Neck Rolls */
          "howto.neck_rolls.execution.1" : "Move smoothly with full-body tension.",
          "howto.neck_rolls.execution.2" : "Keep alignment and control throughout the range.",

          /* Hamstring Stretch */
          "howto.hamstring_stretch.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.hamstring_stretch.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Hip Flexor Stretch */
          "howto.hip_flexor_stretch.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.hip_flexor_stretch.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Thoracic Rotation */
          "howto.thoracic_rotation.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.thoracic_rotation.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Child’s Pose */
          "howto.childs_pose.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.childs_pose.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Deep Breathing */
          "howto.deep_breathing.execution.1" : "Settle into a relaxed posture; breathe softly through the nose.",
          "howto.deep_breathing.execution.2" : "Let the exhale be long and quiet; keep shoulders relaxed.",

          /* World’s Greatest Stretch (dynamisch) */
          "howto.worlds_greatest_stretch_dynamisch.execution.1" : "Move smoothly with full-body tension.",
          "howto.worlds_greatest_stretch_dynamisch.execution.2" : "Keep alignment and control throughout the range.",

          /* Glute Stretch */
          "howto.glute_stretch.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.glute_stretch.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Shoulder Opener an der Wand */
          "howto.shoulder_opener_an_der_wand.execution.1" : "Move smoothly with full-body tension.",
          "howto.shoulder_opener_an_der_wand.execution.2" : "Keep alignment and control throughout the range.",

          /* Ankle Dorsiflexion Mobilisation */
          "howto.ankle_dorsiflexion_mobilisation.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.ankle_dorsiflexion_mobilisation.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Half Standing Forward Fold */
          "howto.half_standing_forward_fold.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.half_standing_forward_fold.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Spinal Waves */
          "howto.spinal_waves.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.spinal_waves.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* 90/90 Hip Rotation */
          "howto.90_90_hip_rotation.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.90_90_hip_rotation.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Pectoral Doorway Stretch */
          "howto.pectoral_doorway_stretch.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.pectoral_doorway_stretch.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Lunging Straight Leg Calf Stretching */
          "howto.lunging_straight_leg_calf_stretching.execution.1" : "Move smoothly with full-body tension.",
          "howto.lunging_straight_leg_calf_stretching.execution.2" : "Keep alignment and control throughout the range.",

          /* Box Breathing */
          "howto.box_breathing.execution.1" : "Settle into a relaxed posture; breathe softly through the nose.",
          "howto.box_breathing.execution.2" : "Let the exhale be long and quiet; keep shoulders relaxed.",

          /* Lateral Hip Opener */
          "howto.lateral_hip_opener.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.lateral_hip_opener.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Lat Stretch an Stange */
          "howto.lat_stretch_an_stange.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.lat_stretch_an_stange.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Quad Stretch */
          "howto.quad_stretch.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.quad_stretch.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Happy Baby */
          "howto.happy_baby.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.happy_baby.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Spinal Twist (liegend) */
          "howto.spinal_twist_liegend.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.spinal_twist_liegend.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Cobra Stretch */
          "howto.cobra_stretch.execution.1" : "Enter the stretch slowly; keep the spine long.",
          "howto.cobra_stretch.execution.2" : "Hold gentle, pain-free tension; no bouncing.",

          /* Stretching Brust */
          "howto.stretching_brust.execution.1" : "Move smoothly with full-body tension.",
          "howto.stretching_brust.execution.2" : "Keep alignment and control throughout the range.",

          /* world geratest stretch */
          "howto.world_geratest_stretch.execution.1" : "Move smoothly with full-body tension.",
          "howto.world_geratest_stretch.execution.2" : "Keep alignment and control throughout the range.",

          /* stretching schultern */
          "howto.stretching_schultern.execution.1" : "Move smoothly with full-body tension.",
          "howto.stretching_schultern.execution.2" : "Keep alignment and control throughout the range.",

        
        // ENGLISH
        "sleep.unit.hours": "hours",
        "sleep.average": "Average",
        "sleep.info.healthkit": "Connect HealthKit for automatic sleep tracking",
        "sleep.pattern": "Sleep Pattern",
        "sleep.noData.title": "No Data",
        "sleep.noData.description": "Sleep data will appear here when available.",
        "sleep.recommended": "Recommended",

        "sleep.stat.average": "Average",
        "sleep.stat.bestNight": "Best Night",
        "sleep.stat.shortest": "Shortest",
        "sleep.stat.goalNights": "%dh+ nights",
        "sleep.recentNights": "Recent Nights",

        "sleep.quality.excellent": "Excellent",
        "sleep.quality.good": "Good",
        "sleep.quality.fair": "Fair",
        "sleep.quality.poor": "Poor",

        
          /* stretching rücken */
          "howto.stretching_ruecken.execution.1" : "Move smoothly with full-body tension.",
          "howto.stretching_ruecken.execution.2" : "Keep alignment and control throughout the range.",

          /* Schulter taps im plank */
          "howto.schulter_taps_im_plank.execution.1" : "Keep a long spine; ribs down, pelvis neutral.",
          "howto.schulter_taps_im_plank.execution.2" : "Move slow and controlled; avoid arching the lower back.",

          /* Dehnung brust */
          "howto.dehnung_brust.execution.1" : "Move smoothly with full-body tension.",
          "howto.dehnung_brust.execution.2" : "Keep alignment and control throughout the range.",

          /* stretching triez's */
          "howto.stretching_triezs.execution.1" : "Move smoothly with full-body tension.",
          "howto.stretching_triezs.execution.2" : "Keep alignment and control throughout the range.",

          /* Katzenbuckel/Pferderücken */
          "howto.katzenbuckel_pferderuecken.execution.1" : "Move smoothly with full-body tension.",
          "howto.katzenbuckel_pferderuecken.execution.2" : "Keep alignment and control throughout the range.",

          /* stretching Hüfte */
          "howto.stretching_huefte.execution.1" : "Move smoothly with full-body tension.",
          "howto.stretching_huefte.execution.2" : "Keep alignment and control throughout the range.",

          /* World's Greatest Stretch */
          "howto.worlds_greatest_stretch.execution.1" : "Move smoothly with full-body tension.",
          "howto.worlds_greatest_stretch.execution.2" : "Keep alignment and control throughout the range.",

          /* stretching Bauch */
          "howto.stretching_bauch.execution.1" : "Move smoothly with full-body tension.",
          "howto.stretching_bauch.execution.2" : "Keep alignment and control throughout the range.",

          /* === Exercises === */

          /* Jumping Jacks */
          "howto.jumping_jacks.setup.1" : "Athletic stance with clear space around you.",
          "howto.jumping_jacks.coaching_cues.1" : "Land softly; keep rhythm steady.",
          "howto.jumping_jacks.coaching_cues.2" : "Arms help drive cadence and posture.",
          "howto.jumping_jacks.atmung.1" : "Breathe calmly and rhythmically.",
          "howto.jumping_jacks.atmung.2" : "Exhale on landing to keep tension soft.",
          "howto.jumping_jacks.haeufige_fehler.1" : "Landing hard on the heels.",
          "howto.jumping_jacks.haeufige_fehler.2" : "Torso pitching forward; forgetting arm motion.",
          "howto.jumping_jacks.haeufige_fehler.3" : "Holding your breath at higher pace.",
          "howto.jumping_jacks.skalierung_varianten.1" : "Easier: shorter intervals (20–30s) or lower jump/tempo.",
          "howto.jumping_jacks.skalierung_varianten.2" : "Harder: longer intervals (45–60s) or faster pace.",
          "howto.jumping_jacks.skalierung_varianten.3" : "Harder: add tempo changes or light load if safe.",

        
    

        
          /* High Knees */
          "howto.high_knees.setup.1" : "Athletic stance with clear space around you.",
          "howto.high_knees.coaching_cues.1" : "Land softly; keep rhythm steady.",
          "howto.high_knees.coaching_cues.2" : "Arms help drive cadence and posture.",
          "howto.high_knees.atmung.1" : "Breathe calmly and rhythmically.",
          "howto.high_knees.atmung.2" : "Exhale on landing to keep tension soft.",
          "howto.high_knees.haeufige_fehler.1" : "Landing hard on the heels.",
          "howto.high_knees.haeufige_fehler.2" : "Torso pitching forward; forgetting arm motion.",
          "howto.high_knees.haeufige_fehler.3" : "Holding your breath at higher pace.",
          "howto.high_knees.skalierung_varianten.1" : "Easier: shorter intervals (20–30s) or lower jump/tempo.",
          "howto.high_knees.skalierung_varianten.2" : "Harder: longer intervals (45–60s) or faster pace.",
          "howto.high_knees.skalierung_varianten.3" : "Harder: add tempo changes or light load if safe.",

          
        
          "howto.section.haeufige_fehler"      : "Common Mistakes",
          "howto.section.skalierung_varianten" : "Scaling / Variations",
        
          /* Butt Kicks */
          "howto.butt_kicks.setup.1" : "Athletic stance with clear space around you.",
          "howto.butt_kicks.coaching_cues.1" : "Land softly; keep rhythm steady.",
          "howto.butt_kicks.coaching_cues.2" : "Arms help drive cadence and posture.",
          "howto.butt_kicks.atmung.1" : "Breathe calmly and rhythmically.",
          "howto.butt_kicks.atmung.2" : "Exhale on landing to keep tension soft.",
          "howto.butt_kicks.haeufige_fehler.1" : "Landing hard on the heels.",
          "howto.butt_kicks.haeufige_fehler.2" : "Torso pitching forward; forgetting arm motion.",
          "howto.butt_kicks.haeufige_fehler.3" : "Holding your breath at higher pace.",
          "howto.butt_kicks.skalierung_varianten.1" : "Easier: shorter intervals (20–30s) or lower jump/tempo.",
          "howto.butt_kicks.skalierung_varianten.2" : "Harder: longer intervals (45–60s) or faster pace.",
          "howto.butt_kicks.skalierung_varianten.3" : "Harder: add tempo changes or light load if safe.",

          /* Burpees (leicht) */
          "howto.burpees_leicht.setup.1" : "Athletic stance with clear space around you.",
          "howto.burpees_leicht.coaching_cues.1" : "Land softly; keep rhythm steady.",
          "howto.burpees_leicht.coaching_cues.2" : "Arms help drive cadence and posture.",
          "howto.burpees_leicht.atmung.1" : "Breathe calmly and rhythmically.",
          "howto.burpees_leicht.atmung.2" : "Exhale on landing to keep tension soft.",
          "howto.burpees_leicht.haeufige_fehler.1" : "Landing hard on the heels.",
          "howto.burpees_leicht.haeufige_fehler.2" : "Torso pitching forward; forgetting arm motion.",
          "howto.burpees_leicht.haeufige_fehler.3" : "Holding your breath at higher pace.",
          "howto.burpees_leicht.skalierung_varianten.1" : "Easier: shorter intervals (20–30s) or lower jump/tempo.",
          "howto.burpees_leicht.skalierung_varianten.2" : "Harder: longer intervals (45–60s) or faster pace.",
          "howto.burpees_leicht.skalierung_varianten.3" : "Harder: add tempo changes or light load if safe.",

          /* Burpees */
          "howto.burpees.setup.1" : "Athletic stance with clear space around you.",
          "howto.burpees.coaching_cues.1" : "Land softly; keep rhythm steady.",
          "howto.burpees.coaching_cues.2" : "Arms help drive cadence and posture.",
          "howto.burpees.atmung.1" : "Breathe calmly and rhythmically.",
          "howto.burpees.atmung.2" : "Exhale on landing to keep tension soft.",
          "howto.burpees.haeufige_fehler.1" : "Landing hard on the heels.",
          "howto.burpees.haeufige_fehler.2" : "Torso pitching forward; forgetting arm motion.",
          "howto.burpees.haeufige_fehler.3" : "Holding your breath at higher pace.",
          "howto.burpees.skalierung_varianten.1" : "Easier: shorter intervals (20–30s) or lower jump/tempo.",
          "howto.burpees.skalierung_varianten.2" : "Harder: longer intervals (45–60s) or faster pace.",
          "howto.burpees.skalierung_varianten.3" : "Harder: add tempo changes or light load if safe.",

          /* Mountain Climbers */
          "howto.mountain_climbers.setup.1" : "Athletic stance with clear space around you.",
          "howto.mountain_climbers.coaching_cues.1" : "Land softly; keep rhythm steady.",
          "howto.mountain_climbers.coaching_cues.2" : "Arms help drive cadence and posture.",
          "howto.mountain_climbers.atmung.1" : "Breathe calmly and rhythmically.",
          "howto.mountain_climbers.atmung.2" : "Exhale on landing to keep tension soft.",
          "howto.mountain_climbers.haeufige_fehler.1" : "Landing hard on the heels.",
          "howto.mountain_climbers.haeufige_fehler.2" : "Torso pitching forward; forgetting arm motion.",
          "howto.mountain_climbers.haeufige_fehler.3" : "Holding your breath at higher pace.",
          "howto.mountain_climbers.skalierung_varianten.1" : "Easier: shorter intervals (20–30s) or lower jump/tempo.",
          "howto.mountain_climbers.skalierung_varianten.2" : "Harder: longer intervals (45–60s) or faster pace.",
          "howto.mountain_climbers.skalierung_varianten.3" : "Harder: add tempo changes or light load if safe.",

          /* Arm Circles */
          "howto.arm_circles.setup.1" : "Stable stance and clear space; move with control.",
          "howto.arm_circles.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.arm_circles.coaching_cues.2" : "Quality before quantity.",
          "howto.arm_circles.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.arm_circles.atmung.2" : "Avoid breath-holding.",
          "howto.arm_circles.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.arm_circles.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.arm_circles.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.arm_circles.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.arm_circles.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.arm_circles.skalierung_varianten.3" : "Harder: add load if available.",

          /* Arm Circles rückwärts */
          "howto.arm_circles_rueckwaerts.setup.1" : "Stable stance and clear space; move with control.",
          "howto.arm_circles_rueckwaerts.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.arm_circles_rueckwaerts.coaching_cues.2" : "Quality before quantity.",
          "howto.arm_circles_rueckwaerts.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.arm_circles_rueckwaerts.atmung.2" : "Avoid breath-holding.",
          "howto.arm_circles_rueckwaerts.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.arm_circles_rueckwaerts.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.arm_circles_rueckwaerts.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.arm_circles_rueckwaerts.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.arm_circles_rueckwaerts.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.arm_circles_rueckwaerts.skalierung_varianten.3" : "Harder: add load if available.",

          /* Arm Circles groß */
          "howto.arm_circles_gross.setup.1" : "Stable stance and clear space; move with control.",
          "howto.arm_circles_gross.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.arm_circles_gross.coaching_cues.2" : "Quality before quantity.",
          "howto.arm_circles_gross.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.arm_circles_gross.atmung.2" : "Avoid breath-holding.",
          "howto.arm_circles_gross.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.arm_circles_gross.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.arm_circles_gross.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.arm_circles_gross.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.arm_circles_gross.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.arm_circles_gross.skalierung_varianten.3" : "Harder: add load if available.",

          /* Arm Swings */
          "howto.arm_swings.setup.1" : "Stable stance and clear space; move with control.",
          "howto.arm_swings.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.arm_swings.coaching_cues.2" : "Quality before quantity.",
          "howto.arm_swings.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.arm_swings.atmung.2" : "Avoid breath-holding.",
          "howto.arm_swings.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.arm_swings.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.arm_swings.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.arm_swings.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.arm_swings.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.arm_swings.skalierung_varianten.3" : "Harder: add load if available.",

          /* Hip Opener */
          "howto.hip_opener.setup.1" : "Stable stance and clear space; move with control.",
          "howto.hip_opener.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.hip_opener.coaching_cues.2" : "Quality before quantity.",
          "howto.hip_opener.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.hip_opener.atmung.2" : "Avoid breath-holding.",
          "howto.hip_opener.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.hip_opener.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.hip_opener.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.hip_opener.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.hip_opener.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.hip_opener.skalierung_varianten.3" : "Harder: add load if available.",

          /* Shoulder Stretch */
          "howto.shoulder_stretch.setup.1" : "Stable stance and clear space; move with control.",
          "howto.shoulder_stretch.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.shoulder_stretch.coaching_cues.2" : "Quality before quantity.",
          "howto.shoulder_stretch.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.shoulder_stretch.atmung.2" : "Avoid breath-holding.",
          "howto.shoulder_stretch.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.shoulder_stretch.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.shoulder_stretch.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.shoulder_stretch.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.shoulder_stretch.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.shoulder_stretch.skalierung_varianten.3" : "Harder: add load if available.",

          /* Torso Twists */
          "howto.torso_twists.setup.1" : "Stable stance and clear space; move with control.",
          "howto.torso_twists.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.torso_twists.coaching_cues.2" : "Quality before quantity.",
          "howto.torso_twists.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.torso_twists.atmung.2" : "Avoid breath-holding.",
          "howto.torso_twists.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.torso_twists.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.torso_twists.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.torso_twists.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.torso_twists.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.torso_twists.skalierung_varianten.3" : "Harder: add load if available.",

          /* Leichte Nacken- & Schulterkreise */
          "howto.leichte_nacken_und_schulterkreise.setup.1" : "Stable stance and clear space; move with control.",
          "howto.leichte_nacken_und_schulterkreise.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.leichte_nacken_und_schulterkreise.coaching_cues.2" : "Quality before quantity.",
          "howto.leichte_nacken_und_schulterkreise.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.leichte_nacken_und_schulterkreise.atmung.2" : "Avoid breath-holding.",
          "howto.leichte_nacken_und_schulterkreise.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.leichte_nacken_und_schulterkreise.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.leichte_nacken_und_schulterkreise.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.leichte_nacken_und_schulterkreise.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.leichte_nacken_und_schulterkreise.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.leichte_nacken_und_schulterkreise.skalierung_varianten.3" : "Harder: add load if available.",

          /* Kniebeugen */
          "howto.kniebeugen.setup.1" : "Feet shoulder-width; toes slightly out; chest proud.",
          "howto.kniebeugen.coaching_cues.1" : "Knees track in toe line.",
          "howto.kniebeugen.coaching_cues.2" : "Drive through mid-foot/heels, stay tall.",
          "howto.kniebeugen.atmung.1" : "Inhale down, exhale up.",
          "howto.kniebeugen.atmung.2" : "Optional short brace before driving up.",
          "howto.kniebeugen.haeufige_fehler.1" : "Knees collapsing inward; heels lifting.",
          "howto.kniebeugen.haeufige_fehler.2" : "Torso folding forward excessively.",
          "howto.kniebeugen.haeufige_fehler.3" : "Rushing the bottom turnaround.",
          "howto.kniebeugen.skalierung_varianten.1" : "Easier: box squat / limit depth to comfort.",
          "howto.kniebeugen.skalierung_varianten.2" : "Harder: tempo or paused reps.",
          "howto.kniebeugen.skalierung_varianten.3" : "Harder: jump squats or add load if available.",

          /* Ausfallschritte */
          "howto.ausfallschritte.setup.1" : "Long step stance; torso tall, hips square.",
          "howto.ausfallschritte.coaching_cues.1" : "Front knee tracks over toes.",
          "howto.ausfallschritte.coaching_cues.2" : "Drive back up through the front heel.",
          "howto.ausfallschritte.atmung.1" : "Inhale down, exhale up.",
          "howto.ausfallschritte.atmung.2" : "Keep core stable and pelvis level.",
          "howto.ausfallschritte.haeufige_fehler.1" : "Front knee collapsing inward.",
          "howto.ausfallschritte.haeufige_fehler.2" : "Torso leaning too far forward.",
          "howto.ausfallschritte.haeufige_fehler.3" : "Steps too short and tight.",
          "howto.ausfallschritte.skalierung_varianten.1" : "Easier: shorten the step or add a brief top pause.",
          "howto.ausfallschritte.skalierung_varianten.2" : "Harder: tempo/paused reps.",
          "howto.ausfallschritte.skalierung_varianten.3" : "Harder: jumping lunges (if tolerated).",

          /* Side Lunges */
          "howto.side_lunges.setup.1" : "Long step stance; torso tall, hips square.",
          "howto.side_lunges.coaching_cues.1" : "Front knee tracks over toes.",
          "howto.side_lunges.coaching_cues.2" : "Drive back up through the front heel.",
          "howto.side_lunges.atmung.1" : "Inhale down, exhale up.",
          "howto.side_lunges.atmung.2" : "Keep core stable and pelvis level.",
          "howto.side_lunges.haeufige_fehler.1" : "Front knee collapsing inward.",
          "howto.side_lunges.haeufige_fehler.2" : "Torso leaning too far forward.",
          "howto.side_lunges.haeufige_fehler.3" : "Steps too short and tight.",
          "howto.side_lunges.skalierung_varianten.1" : "Easier: shorten the step or add a brief top pause.",
          "howto.side_lunges.skalierung_varianten.2" : "Harder: tempo/paused reps.",
          "howto.side_lunges.skalierung_varianten.3" : "Harder: jumping lunges (if tolerated).",

          /* Bulgarian Split Squats (ohne Erhöhung) */
          "howto.bulgarian_split_squats_ohne_erhoehung.setup.1" : "Feet shoulder-width; toes slightly out; chest proud.",
          "howto.bulgarian_split_squats_ohne_erhoehung.coaching_cues.1" : "Knees track in toe line.",
          "howto.bulgarian_split_squats_ohne_erhoehung.coaching_cues.2" : "Drive through mid-foot/heels, stay tall.",
          "howto.bulgarian_split_squats_ohne_erhoehung.atmung.1" : "Inhale down, exhale up.",
          "howto.bulgarian_split_squats_ohne_erhoehung.atmung.2" : "Optional short brace before driving up.",
          "howto.bulgarian_split_squats_ohne_erhoehung.haeufige_fehler.1" : "Knees collapsing inward; heels lifting.",
          "howto.bulgarian_split_squats_ohne_erhoehung.haeufige_fehler.2" : "Torso folding forward excessively.",
          "howto.bulgarian_split_squats_ohne_erhoehung.haeufige_fehler.3" : "Rushing the bottom turnaround.",
          "howto.bulgarian_split_squats_ohne_erhoehung.skalierung_varianten.1" : "Easier: box squat / limit depth to comfort.",
          "howto.bulgarian_split_squats_ohne_erhoehung.skalierung_varianten.2" : "Harder: tempo or paused reps.",
          "howto.bulgarian_split_squats_ohne_erhoehung.skalierung_varianten.3" : "Harder: jump squats or add load if available.",

        
        "cloud.button.syncNow"        : "Sync with Cloud",
        "cloud.button.syncing"       : "Syncing...",
        "cloud.lastSync.prefix"       : "As of;",
          /* Jump Squats */
          "howto.jump_squats.setup.1" : "Feet shoulder-width; toes slightly out; chest proud.",
          "howto.jump_squats.coaching_cues.1" : "Knees track in toe line.",
          "howto.jump_squats.coaching_cues.2" : "Drive through mid-foot/heels, stay tall.",
          "howto.jump_squats.atmung.1" : "Inhale down, exhale up.",
          "howto.jump_squats.atmung.2" : "Optional short brace before driving up.",
          "howto.jump_squats.haeufige_fehler.1" : "Knees collapsing inward; heels lifting.",
          "howto.jump_squats.haeufige_fehler.2" : "Torso folding forward excessively.",
          "howto.jump_squats.haeufige_fehler.3" : "Rushing the bottom turnaround.",
          "howto.jump_squats.skalierung_varianten.1" : "Easier: box squat / limit depth to comfort.",
          "howto.jump_squats.skalierung_varianten.2" : "Harder: tempo or paused reps.",
          "howto.jump_squats.skalierung_varianten.3" : "Harder: jump squats or add load if available.",

          /* Hip Hinge / Good Mornings */
          "howto.hip_hinge_good_mornings.setup.1" : "Feet hip-width; push hips back, keep spine long.",
          "howto.hip_hinge_good_mornings.coaching_cues.1" : "Hinge at the hips, not the knees.",
          "howto.hip_hinge_good_mornings.coaching_cues.2" : "Keep weight over mid-foot/heels.",
          "howto.hip_hinge_good_mornings.atmung.1" : "Inhale at the top; exhale as you extend with tension.",
          "howto.hip_hinge_good_mornings.atmung.2" : "Build abdominal pressure; keep back long.",
          "howto.hip_hinge_good_mornings.haeufige_fehler.1" : "Rounding the back; knees shifting too far forward.",
          "howto.hip_hinge_good_mornings.haeufige_fehler.2" : "Going too low and losing neutral.",
          "howto.hip_hinge_good_mornings.haeufige_fehler.3" : "Neck craning up.",
          "howto.hip_hinge_good_mornings.skalierung_varianten.1" : "Easier: reduce range; hands on hips for feedback.",
          "howto.hip_hinge_good_mornings.skalierung_varianten.2" : "Harder: tempo 3–1–1 or isometric hold at bottom.",
          "howto.hip_hinge_good_mornings.skalierung_varianten.3" : "Harder: add load if available.",

          /* Good Mornings (langsam) */
          "howto.good_mornings_langsam.setup.1" : "Feet hip-width; push hips back, keep spine long.",
          "howto.good_mornings_langsam.coaching_cues.1" : "Hinge at the hips, not the knees.",
          "howto.good_mornings_langsam.coaching_cues.2" : "Keep weight over mid-foot/heels.",
          "howto.good_mornings_langsam.atmung.1" : "Inhale at the top; exhale as you extend with tension.",
          "howto.good_mornings_langsam.atmung.2" : "Build abdominal pressure; keep back long.",
          "howto.good_mornings_langsam.haeufige_fehler.1" : "Rounding the back; knees shifting too far forward.",
          "howto.good_mornings_langsam.haeufige_fehler.2" : "Going too low and losing neutral.",
          "howto.good_mornings_langsam.haeufige_fehler.3" : "Neck craning up.",
          "howto.good_mornings_langsam.skalierung_varianten.1" : "Easier: reduce range; hands on hips for feedback.",
          "howto.good_mornings_langsam.skalierung_varianten.2" : "Harder: tempo 3–1–1 or isometric hold at bottom.",
          "howto.good_mornings_langsam.skalierung_varianten.3" : "Harder: add load if available.",

    
        "cloud.title" : "Movo Cloud",
        "cloud.subtitle" : "Movo does NOT sync automatically. You save & sync manually whenever you want.",
        "cloud.row.subtitle" : "Manual save & sync",
        "cloud.status.ready" : "Ready to sync",
        "cloud.status.syncing" : "Syncing…",
        "cloud.syncNow" : "Sync now",
        "cloud.explainer" : "Tap “Sync now” to back up workouts and settings to the cloud or transfer them to other devices.",

          /* Liegestütze */
          "howto.liegestuetze.setup.1" : "Hands under or slightly outside shoulders; body in line.",
          "howto.liegestuetze.coaching_cues.1" : "Elbows ~45°, forearms vertical.",
          "howto.liegestuetze.coaching_cues.2" : "Push the floor away; keep ribs down.",
          "howto.liegestuetze.atmung.1" : "Inhale on the way down, exhale as you press.",
          "howto.liegestuetze.atmung.2" : "Brace the core; avoid flaring.",
          "howto.liegestuetze.haeufige_fehler.1" : "Elbows flaring too wide.",
          "howto.liegestuetze.haeufige_fehler.2" : "Sagging through the midsection (arched lower back).",
          "howto.liegestuetze.haeufige_fehler.3" : "Head jutting forward or losing neck alignment.",
          "howto.liegestuetze.skalierung_varianten.1" : "Easier: knees down or hands elevated.",
          "howto.liegestuetze.skalierung_varianten.2" : "Harder: tempo/paused reps; narrower stance.",
          "howto.liegestuetze.skalierung_varianten.3" : "Harder: explosive/clapping or deficit push-ups.",

          /* Enge Liegestütze (Trizeps) */
          "howto.enge_liegestuetze_trizeps.setup.1" : "Hands under or slightly outside shoulders; body in line.",
          "howto.enge_liegestuetze_trizeps.coaching_cues.1" : "Elbows ~45°, forearms vertical.",
          "howto.enge_liegestuetze_trizeps.coaching_cues.2" : "Push the floor away; keep ribs down.",
          "howto.enge_liegestuetze_trizeps.atmung.1" : "Inhale on the way down, exhale as you press.",
          "howto.enge_liegestuetze_trizeps.atmung.2" : "Brace the core; avoid flaring.",
          "howto.enge_liegestuetze_trizeps.haeufige_fehler.1" : "Elbows flaring too wide.",
          "howto.enge_liegestuetze_trizeps.haeufige_fehler.2" : "Sagging through the midsection (arched lower back).",
          "howto.enge_liegestuetze_trizeps.haeufige_fehler.3" : "Head jutting forward or losing neck alignment.",
          "howto.enge_liegestuetze_trizeps.skalierung_varianten.1" : "Easier: knees down or hands elevated.",
          "howto.enge_liegestuetze_trizeps.skalierung_varianten.2" : "Harder: tempo/paused reps; narrower stance.",
          "howto.enge_liegestuetze_trizeps.skalierung_varianten.3" : "Harder: explosive/clapping or deficit push-ups.",

          /* Liegestütze (Tempo 3-1-1) */
          "howto.liegestuetze_tempo_3_1_1.setup.1" : "Hands under or slightly outside shoulders; body in line.",
          "howto.liegestuetze_tempo_3_1_1.coaching_cues.1" : "Elbows ~45°, forearms vertical.",
          "howto.liegestuetze_tempo_3_1_1.coaching_cues.2" : "Push the floor away; keep ribs down.",
          "howto.liegestuetze_tempo_3_1_1.atmung.1" : "Inhale on the way down, exhale as you press.",
          "howto.liegestuetze_tempo_3_1_1.atmung.2" : "Brace the core; avoid flaring.",
          "howto.liegestuetze_tempo_3_1_1.haeufige_fehler.1" : "Elbows flaring too wide.",
          "howto.liegestuetze_tempo_3_1_1.haeufige_fehler.2" : "Sagging through the midsection (arched lower back).",
          "howto.liegestuetze_tempo_3_1_1.haeufige_fehler.3" : "Head jutting forward or losing neck alignment.",
          "howto.liegestuetze_tempo_3_1_1.skalierung_varianten.1" : "Easier: knees down or hands elevated.",
          "howto.liegestuetze_tempo_3_1_1.skalierung_varianten.2" : "Harder: tempo/paused reps; narrower stance.",
          "howto.liegestuetze_tempo_3_1_1.skalierung_varianten.3" : "Harder: explosive/clapping or deficit push-ups.",

          /* Liegestütze mit Klatschen */
          "howto.liegestuetze_mit_klatschen.setup.1" : "Hands under or slightly outside shoulders; body in line.",
          "howto.liegestuetze_mit_klatschen.coaching_cues.1" : "Elbows ~45°, forearms vertical.",
          "howto.liegestuetze_mit_klatschen.coaching_cues.2" : "Push the floor away; keep ribs down.",
          "howto.liegestuetze_mit_klatschen.atmung.1" : "Inhale on the way down, exhale as you press.",
          "howto.liegestuetze_mit_klatschen.atmung.2" : "Brace the core; avoid flaring.",
          "howto.liegestuetze_mit_klatschen.haeufige_fehler.1" : "Elbows flaring too wide.",
          "howto.liegestuetze_mit_klatschen.haeufige_fehler.2" : "Sagging through the midsection (arched lower back).",
          "howto.liegestuetze_mit_klatschen.haeufige_fehler.3" : "Head jutting forward or losing neck alignment.",
          "howto.liegestuetze_mit_klatschen.skalierung_varianten.1" : "Easier: knees down or hands elevated.",
          "howto.liegestuetze_mit_klatschen.skalierung_varianten.2" : "Harder: tempo/paused reps; narrower stance.",
          "howto.liegestuetze_mit_klatschen.skalierung_varianten.3" : "Harder: explosive/clapping or deficit push-ups.",

          /* Pike Push-ups */
          "howto.pike_push_ups.setup.1" : "Hands under or slightly outside shoulders; body in line.",
          "howto.pike_push_ups.coaching_cues.1" : "Elbows ~45°, forearms vertical.",
          "howto.pike_push_ups.coaching_cues.2" : "Push the floor away; keep ribs down.",
          "howto.pike_push_ups.atmung.1" : "Inhale on the way down, exhale as you press.",
          "howto.pike_push_ups.atmung.2" : "Brace the core; avoid flaring.",
          "howto.pike_push_ups.haeufige_fehler.1" : "Elbows flaring too wide.",
          "howto.pike_push_ups.haeufige_fehler.2" : "Sagging through the midsection (arched lower back).",
          "howto.pike_push_ups.haeufige_fehler.3" : "Head jutting forward or losing neck alignment.",
          "howto.pike_push_ups.skalierung_varianten.1" : "Easier: knees down or hands elevated.",
          "howto.pike_push_ups.skalierung_varianten.2" : "Harder: tempo/paused reps; narrower stance.",
          "howto.pike_push_ups.skalierung_varianten.3" : "Harder: explosive/clapping or deficit push-ups.",

          /* Plank mit Schulter-Taps */
          "howto.plank_mit_schulter_taps.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.plank_mit_schulter_taps.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.plank_mit_schulter_taps.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.plank_mit_schulter_taps.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.plank_mit_schulter_taps.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.plank_mit_schulter_taps.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.plank_mit_schulter_taps.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.plank_mit_schulter_taps.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.plank_mit_schulter_taps.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.plank_mit_schulter_taps.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.plank_mit_schulter_taps.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

          /* Superman Pulls */
          "howto.superman_pulls.setup.1" : "Set up prone or standing with room to move the shoulders freely.",
          "howto.superman_pulls.coaching_cues.1" : "Draw shoulder blades down and back (into 'back pockets').",
          "howto.superman_pulls.coaching_cues.2" : "Keep arms long and neck neutral.",
          "howto.superman_pulls.atmung.1" : "Inhale on lowering, exhale as you activate.",
          "howto.superman_pulls.atmung.2" : "Move the shoulder blades deliberately.",
          "howto.superman_pulls.haeufige_fehler.1" : "Throwing the head back / overextending the lower back.",
          "howto.superman_pulls.haeufige_fehler.2" : "Using momentum instead of control.",
          "howto.superman_pulls.haeufige_fehler.3" : "Shrugging into the ears.",
          "howto.superman_pulls.skalierung_varianten.1" : "Easier: shorter sets or smaller range.",
          "howto.superman_pulls.skalierung_varianten.2" : "Harder: longer holds; tempo 3–1–1.",
          "howto.superman_pulls.skalierung_varianten.3" : "Harder: add light load or band tension.",

          /* Superman Hold */
          "howto.superman_hold.setup.1" : "Set up prone or standing with room to move the shoulders freely.",
          "howto.superman_hold.coaching_cues.1" : "Draw shoulder blades down and back (into 'back pockets').",
          "howto.superman_hold.coaching_cues.2" : "Keep arms long and neck neutral.",
          "howto.superman_hold.atmung.1" : "Inhale on lowering, exhale as you activate.",
          "howto.superman_hold.atmung.2" : "Move the shoulder blades deliberately.",
          "howto.superman_hold.haeufige_fehler.1" : "Throwing the head back / overextending the lower back.",
          "howto.superman_hold.haeufige_fehler.2" : "Using momentum instead of control.",
          "howto.superman_hold.haeufige_fehler.3" : "Shrugging into the ears.",
          "howto.superman_hold.skalierung_varianten.1" : "Easier: shorter sets or smaller range.",
          "howto.superman_hold.skalierung_varianten.2" : "Harder: longer holds; tempo 3–1–1.",
          "howto.superman_hold.skalierung_varianten.3" : "Harder: add light load or band tension.",

          /* Prone W-Raises */
          "howto.prone_w_raises.setup.1" : "Set up prone or standing with room to move the shoulders freely.",
          "howto.prone_w_raises.coaching_cues.1" : "Draw shoulder blades down and back (into 'back pockets').",
          "howto.prone_w_raises.coaching_cues.2" : "Keep arms long and neck neutral.",
          "howto.prone_w_raises.atmung.1" : "Inhale on lowering, exhale as you activate.",
          "howto.prone_w_raises.atmung.2" : "Move the shoulder blades deliberately.",
          "howto.prone_w_raises.haeufige_fehler.1" : "Throwing the head back / overextending the lower back.",
          "howto.prone_w_raises.haeufige_fehler.2" : "Using momentum instead of control.",
          "howto.prone_w_raises.haeufige_fehler.3" : "Shrugging into the ears.",
          "howto.prone_w_raises.skalierung_varianten.1" : "Easier: shorter sets or smaller range.",
          "howto.prone_w_raises.skalierung_varianten.2" : "Harder: longer holds; tempo 3–1–1.",
          "howto.prone_w_raises.skalierung_varianten.3" : "Harder: add light load or band tension.",

          /* Reverse Snow Angels */
          "howto.reverse_snow_angels.setup.1" : "Set up prone or standing with room to move the shoulders freely.",
          "howto.reverse_snow_angels.coaching_cues.1" : "Draw shoulder blades down and back (into 'back pockets').",
          "howto.reverse_snow_angels.coaching_cues.2" : "Keep arms long and neck neutral.",
          "howto.reverse_snow_angels.atmung.1" : "Inhale on lowering, exhale as you activate.",
          "howto.reverse_snow_angels.atmung.2" : "Move the shoulder blades deliberately.",
          "howto.reverse_snow_angels.haeufige_fehler.1" : "Throwing the head back / overextending the lower back.",
          "howto.reverse_snow_angels.haeufige_fehler.2" : "Using momentum instead of control.",
          "howto.reverse_snow_angels.haeufige_fehler.3" : "Shrugging into the ears.",
          "howto.reverse_snow_angels.skalierung_varianten.1" : "Easier: shorter sets or smaller range.",
          "howto.reverse_snow_angels.skalierung_varianten.2" : "Harder: longer holds; tempo 3–1–1.",
          "howto.reverse_snow_angels.skalierung_varianten.3" : "Harder: add light load or band tension.",

          /* Plank */
          "howto.plank.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.plank.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.plank.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.plank.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.plank.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.plank.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.plank.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.plank.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.plank.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.plank.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.plank.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

          /* Plank (fortgeschritten) */
          "howto.plank_fortgeschritten.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.plank_fortgeschritten.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.plank_fortgeschritten.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.plank_fortgeschritten.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.plank_fortgeschritten.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.plank_fortgeschritten.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.plank_fortgeschritten.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.plank_fortgeschritten.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.plank_fortgeschritten.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.plank_fortgeschritten.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.plank_fortgeschritten.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

          /* Plank mit Beinheben */
          "howto.plank_mit_beinheben.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.plank_mit_beinheben.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.plank_mit_beinheben.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.plank_mit_beinheben.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.plank_mit_beinheben.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.plank_mit_beinheben.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.plank_mit_beinheben.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.plank_mit_beinheben.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.plank_mit_beinheben.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.plank_mit_beinheben.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.plank_mit_beinheben.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

          /* Bicycle Crunches */
          "howto.bicycle_crunches.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.bicycle_crunches.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.bicycle_crunches.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.bicycle_crunches.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.bicycle_crunches.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.bicycle_crunches.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.bicycle_crunches.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.bicycle_crunches.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.bicycle_crunches.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.bicycle_crunches.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.bicycle_crunches.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

          /* Reverse Crunches */
          "howto.reverse_crunches.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.reverse_crunches.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.reverse_crunches.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.reverse_crunches.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.reverse_crunches.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.reverse_crunches.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.reverse_crunches.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.reverse_crunches.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.reverse_crunches.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.reverse_crunches.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.reverse_crunches.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

        "home.greeting.hiUser" : "Hello, %@",   // DE

        
        
        "water.title" : "Water Intake",
        "water.unit" : "Water",
        "unit.ml" : "ml",

        "water.progressOfGoal" : "%d%% of %d ml goal",
        "water.hydrationTrend" : "Hydration Trend",
        "water.noData.title" : "No Data",
        "water.noData.description" : "Start tracking your water intake!",

        "water.goalsHit.title" : "Goals Hit",
        "water.goalsHit.value" : "%d of %d days",

        "water.dailyGoal" : "Daily Goal",
        "water.goal.target" : "Target",
        "water.quickAdd" : "+%d ml",
        "water.undo.step" : "Undo (-%d ml)",

        "statistics.total" : "Total",
        "statistics.average" : "Average",
        "statistics.today" : "Today",

        
        "common.range" : "Range",
        "range.days" : "%d days",


        
          /* Crunches */
          "howto.crunches.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.crunches.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.crunches.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.crunches.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.crunches.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.crunches.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.crunches.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.crunches.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.crunches.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.crunches.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.crunches.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

          /* Side Plank */
          "howto.side_plank.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.side_plank.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.side_plank.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.side_plank.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.side_plank.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.side_plank.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.side_plank.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.side_plank.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.side_plank.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.side_plank.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.side_plank.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

          /* Side Plank mit Hüftheben */
          "howto.side_plank_mit_hueftheben.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.side_plank_mit_hueftheben.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.side_plank_mit_hueftheben.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.side_plank_mit_hueftheben.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.side_plank_mit_hueftheben.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.side_plank_mit_hueftheben.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.side_plank_mit_hueftheben.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.side_plank_mit_hueftheben.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.side_plank_mit_hueftheben.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.side_plank_mit_hueftheben.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.side_plank_mit_hueftheben.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

          /* Plank Walkouts */
          "howto.plank_walkouts.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.plank_walkouts.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.plank_walkouts.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.plank_walkouts.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.plank_walkouts.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.plank_walkouts.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.plank_walkouts.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.plank_walkouts.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.plank_walkouts.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.plank_walkouts.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.plank_walkouts.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

          /* Hollow Hold */
          "howto.hollow_hold.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.hollow_hold.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.hollow_hold.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.hollow_hold.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.hollow_hold.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.hollow_hold.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.hollow_hold.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.hollow_hold.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.hollow_hold.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.hollow_hold.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.hollow_hold.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

          /* Hollow Rock (leicht) */
          "howto.hollow_rock_leicht.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.hollow_rock_leicht.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.hollow_rock_leicht.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.hollow_rock_leicht.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.hollow_rock_leicht.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.hollow_rock_leicht.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.hollow_rock_leicht.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.hollow_rock_leicht.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.hollow_rock_leicht.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.hollow_rock_leicht.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.hollow_rock_leicht.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

          /* Toe Touches */
          "howto.toe_touches.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.toe_touches.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.toe_touches.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.toe_touches.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.toe_touches.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.toe_touches.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.toe_touches.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.toe_touches.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.toe_touches.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.toe_touches.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.toe_touches.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

          /* Russian Twists */
          "howto.russian_twists.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.russian_twists.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.russian_twists.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.russian_twists.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.russian_twists.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.russian_twists.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.russian_twists.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.russian_twists.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.russian_twists.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.russian_twists.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.russian_twists.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

          /* Dead Bug (aktivieren) */
          "howto.dead_bug_aktivieren.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.dead_bug_aktivieren.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.dead_bug_aktivieren.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.dead_bug_aktivieren.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.dead_bug_aktivieren.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.dead_bug_aktivieren.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.dead_bug_aktivieren.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.dead_bug_aktivieren.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.dead_bug_aktivieren.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.dead_bug_aktivieren.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.dead_bug_aktivieren.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

          /* Hip Bridges */
          "howto.hip_bridges.setup.1" : "Stable stance and clear space; move with control.",
          "howto.hip_bridges.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.hip_bridges.coaching_cues.2" : "Quality before quantity.",
          "howto.hip_bridges.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.hip_bridges.atmung.2" : "Avoid breath-holding.",
          "howto.hip_bridges.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.hip_bridges.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.hip_bridges.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.hip_bridges.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.hip_bridges.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.hip_bridges.skalierung_varianten.3" : "Harder: add load if available.",

          /* Glute Bridge March */
          "howto.glute_bridge_march.setup.1" : "Stable stance and clear space; move with control.",
          "howto.glute_bridge_march.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.glute_bridge_march.coaching_cues.2" : "Quality before quantity.",
          "howto.glute_bridge_march.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.glute_bridge_march.atmung.2" : "Avoid breath-holding.",
          "howto.glute_bridge_march.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.glute_bridge_march.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.glute_bridge_march.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.glute_bridge_march.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.glute_bridge_march.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.glute_bridge_march.skalierung_varianten.3" : "Harder: add load if available.",

          /* Bird Dog */
          "howto.bird_dog.setup.1" : "Stable stance and clear space; move with control.",
          "howto.bird_dog.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.bird_dog.coaching_cues.2" : "Quality before quantity.",
          "howto.bird_dog.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.bird_dog.atmung.2" : "Avoid breath-holding.",
          "howto.bird_dog.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.bird_dog.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.bird_dog.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.bird_dog.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.bird_dog.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.bird_dog.skalierung_varianten.3" : "Harder: add load if available.",

          /* Cat-Cow */
          "howto.cat_cow.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.cat_cow.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.cat_cow.coaching_cues.2" : "Control range—no bouncing.",
          "howto.cat_cow.atmung.1" : "Exhale slowly and soften tension.",
          "howto.cat_cow.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.cat_cow.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.cat_cow.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.cat_cow.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.cat_cow.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.cat_cow.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.cat_cow.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Neck Rolls */
          "howto.neck_rolls.setup.1" : "Stable stance and clear space; move with control.",
          "howto.neck_rolls.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.neck_rolls.coaching_cues.2" : "Quality before quantity.",
          "howto.neck_rolls.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.neck_rolls.atmung.2" : "Avoid breath-holding.",
          "howto.neck_rolls.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.neck_rolls.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.neck_rolls.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.neck_rolls.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.neck_rolls.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.neck_rolls.skalierung_varianten.3" : "Harder: add load if available.",

          /* Hamstring Stretch */
          "howto.hamstring_stretch.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.hamstring_stretch.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.hamstring_stretch.coaching_cues.2" : "Control range—no bouncing.",
          "howto.hamstring_stretch.atmung.1" : "Exhale slowly and soften tension.",
          "howto.hamstring_stretch.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.hamstring_stretch.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.hamstring_stretch.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.hamstring_stretch.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.hamstring_stretch.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.hamstring_stretch.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.hamstring_stretch.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Hip Flexor Stretch */
          "howto.hip_flexor_stretch.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.hip_flexor_stretch.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.hip_flexor_stretch.coaching_cues.2" : "Control range—no bouncing.",
          "howto.hip_flexor_stretch.atmung.1" : "Exhale slowly and soften tension.",
          "howto.hip_flexor_stretch.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.hip_flexor_stretch.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.hip_flexor_stretch.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.hip_flexor_stretch.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.hip_flexor_stretch.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.hip_flexor_stretch.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.hip_flexor_stretch.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Thoracic Rotation */
          "howto.thoracic_rotation.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.thoracic_rotation.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.thoracic_rotation.coaching_cues.2" : "Control range—no bouncing.",
          "howto.thoracic_rotation.atmung.1" : "Exhale slowly and soften tension.",
          "howto.thoracic_rotation.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.thoracic_rotation.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.thoracic_rotation.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.thoracic_rotation.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.thoracic_rotation.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.thoracic_rotation.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.thoracic_rotation.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Child’s Pose */
          "howto.childs_pose.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.childs_pose.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.childs_pose.coaching_cues.2" : "Control range—no bouncing.",
          "howto.childs_pose.atmung.1" : "Exhale slowly and soften tension.",
          "howto.childs_pose.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.childs_pose.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.childs_pose.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.childs_pose.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.childs_pose.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.childs_pose.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.childs_pose.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Deep Breathing */
          "howto.deep_breathing.setup.1" : "Comfortable, upright or supported position; shoulders relaxed.",
          "howto.deep_breathing.coaching_cues.1" : "Breathe softly through the nose; long, quiet exhale.",
          "howto.deep_breathing.coaching_cues.2" : "Keep attention on belly and rib movement.",
          "howto.deep_breathing.atmung.1" : "Inhale through the nose; exhale slightly longer through the mouth.",
          "howto.deep_breathing.atmung.2" : "Keep a regular rhythm—no straining.",
          "howto.deep_breathing.haeufige_fehler.1" : "Holding the breath or panting.",
          "howto.deep_breathing.haeufige_fehler.2" : "Shrugging shoulders and tensing the neck.",
          "howto.deep_breathing.haeufige_fehler.3" : "Forcing range instead of relaxing.",
          "howto.deep_breathing.skalierung_varianten.1" : "Easier: shorten the cycle time.",
          "howto.deep_breathing.skalierung_varianten.2" : "Harder: lengthen cycles (e.g., 4–6–6–4).",
          "howto.deep_breathing.skalierung_varianten.3" : "Harder: add simple focus (counting, body scan).",

          /* World’s Greatest Stretch (dynamisch) */
          "howto.worlds_greatest_stretch_dynamisch.setup.1" : "Stable stance and clear space; move with control.",
          "howto.worlds_greatest_stretch_dynamisch.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.worlds_greatest_stretch_dynamisch.coaching_cues.2" : "Quality before quantity.",
          "howto.worlds_greatest_stretch_dynamisch.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.worlds_greatest_stretch_dynamisch.atmung.2" : "Avoid breath-holding.",
          "howto.worlds_greatest_stretch_dynamisch.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.worlds_greatest_stretch_dynamisch.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.worlds_greatest_stretch_dynamisch.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.worlds_greatest_stretch_dynamisch.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.worlds_greatest_stretch_dynamisch.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.worlds_greatest_stretch_dynamisch.skalierung_varianten.3" : "Harder: add load if available.",

          /* Glute Stretch */
          "howto.glute_stretch.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.glute_stretch.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.glute_stretch.coaching_cues.2" : "Control range—no bouncing.",
          "howto.glute_stretch.atmung.1" : "Exhale slowly and soften tension.",
          "howto.glute_stretch.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.glute_stretch.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.glute_stretch.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.glute_stretch.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.glute_stretch.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.glute_stretch.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.glute_stretch.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Shoulder Opener an der Wand */
          "howto.shoulder_opener_an_der_wand.setup.1" : "Stable stance and clear space; move with control.",
          "howto.shoulder_opener_an_der_wand.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.shoulder_opener_an_der_wand.coaching_cues.2" : "Quality before quantity.",
          "howto.shoulder_opener_an_der_wand.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.shoulder_opener_an_der_wand.atmung.2" : "Avoid breath-holding.",
          "howto.shoulder_opener_an_der_wand.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.shoulder_opener_an_der_wand.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.shoulder_opener_an_der_wand.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.shoulder_opener_an_der_wand.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.shoulder_opener_an_der_wand.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.shoulder_opener_an_der_wand.skalierung_varianten.3" : "Harder: add load if available.",

          /* Ankle Dorsiflexion Mobilisation */
          "howto.ankle_dorsiflexion_mobilisation.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.ankle_dorsiflexion_mobilisation.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.ankle_dorsiflexion_mobilisation.coaching_cues.2" : "Control range—no bouncing.",
          "howto.ankle_dorsiflexion_mobilisation.atmung.1" : "Exhale slowly and soften tension.",
          "howto.ankle_dorsiflexion_mobilisation.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.ankle_dorsiflexion_mobilisation.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.ankle_dorsiflexion_mobilisation.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.ankle_dorsiflexion_mobilisation.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.ankle_dorsiflexion_mobilisation.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.ankle_dorsiflexion_mobilisation.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.ankle_dorsiflexion_mobilisation.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Half Standing Forward Fold */
          "howto.half_standing_forward_fold.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.half_standing_forward_fold.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.half_standing_forward_fold.coaching_cues.2" : "Control range—no bouncing.",
          "howto.half_standing_forward_fold.atmung.1" : "Exhale slowly and soften tension.",
          "howto.half_standing_forward_fold.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.half_standing_forward_fold.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.half_standing_forward_fold.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.half_standing_forward_fold.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.half_standing_forward_fold.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.half_standing_forward_fold.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.half_standing_forward_fold.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Spinal Waves */
          "howto.spinal_waves.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.spinal_waves.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.spinal_waves.coaching_cues.2" : "Control range—no bouncing.",
          "howto.spinal_waves.atmung.1" : "Exhale slowly and soften tension.",
          "howto.spinal_waves.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.spinal_waves.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.spinal_waves.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.spinal_waves.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.spinal_waves.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.spinal_waves.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.spinal_waves.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* 90/90 Hip Rotation */
          "howto.90_90_hip_rotation.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.90_90_hip_rotation.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.90_90_hip_rotation.coaching_cues.2" : "Control range—no bouncing.",
          "howto.90_90_hip_rotation.atmung.1" : "Exhale slowly and soften tension.",
          "howto.90_90_hip_rotation.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.90_90_hip_rotation.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.90_90_hip_rotation.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.90_90_hip_rotation.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.90_90_hip_rotation.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.90_90_hip_rotation.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.90_90_hip_rotation.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Pectoral Doorway Stretch */
          "howto.pectoral_doorway_stretch.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.pectoral_doorway_stretch.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.pectoral_doorway_stretch.coaching_cues.2" : "Control range—no bouncing.",
          "howto.pectoral_doorway_stretch.atmung.1" : "Exhale slowly and soften tension.",
          "howto.pectoral_doorway_stretch.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.pectoral_doorway_stretch.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.pectoral_doorway_stretch.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.pectoral_doorway_stretch.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.pectoral_doorway_stretch.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.pectoral_doorway_stretch.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.pectoral_doorway_stretch.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Lunging Straight Leg Calf Stretching */
          "howto.lunging_straight_leg_calf_stretching.setup.1" : "Stable stance and clear space; move with control.",
          "howto.lunging_straight_leg_calf_stretching.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.lunging_straight_leg_calf_stretching.coaching_cues.2" : "Quality before quantity.",
          "howto.lunging_straight_leg_calf_stretching.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.lunging_straight_leg_calf_stretching.atmung.2" : "Avoid breath-holding.",
          "howto.lunging_straight_leg_calf_stretching.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.lunging_straight_leg_calf_stretching.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.lunging_straight_leg_calf_stretching.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.lunging_straight_leg_calf_stretching.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.lunging_straight_leg_calf_stretching.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.lunging_straight_leg_calf_stretching.skalierung_varianten.3" : "Harder: add load if available.",

          /* Box Breathing */
          "howto.box_breathing.setup.1" : "Comfortable, upright or supported position; shoulders relaxed.",
          "howto.box_breathing.coaching_cues.1" : "Breathe softly through the nose; long, quiet exhale.",
          "howto.box_breathing.coaching_cues.2" : "Keep attention on belly and rib movement.",
          "howto.box_breathing.atmung.1" : "Inhale through the nose; exhale slightly longer through the mouth.",
          "howto.box_breathing.atmung.2" : "Keep a regular rhythm—no straining.",
          "howto.box_breathing.haeufige_fehler.1" : "Holding the breath or panting.",
          "howto.box_breathing.haeufige_fehler.2" : "Shrugging shoulders and tensing the neck.",
          "howto.box_breathing.haeufige_fehler.3" : "Forcing range instead of relaxing.",
          "howto.box_breathing.skalierung_varianten.1" : "Easier: shorten the cycle time.",
          "howto.box_breathing.skalierung_varianten.2" : "Harder: lengthen cycles (e.g., 4–6–6–4).",
          "howto.box_breathing.skalierung_varianten.3" : "Harder: add simple focus (counting, body scan).",

          /* Lateral Hip Opener */
          "howto.lateral_hip_opener.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.lateral_hip_opener.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.lateral_hip_opener.coaching_cues.2" : "Control range—no bouncing.",
          "howto.lateral_hip_opener.atmung.1" : "Exhale slowly and soften tension.",
          "howto.lateral_hip_opener.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.lateral_hip_opener.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.lateral_hip_opener.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.lateral_hip_opener.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.lateral_hip_opener.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.lateral_hip_opener.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.lateral_hip_opener.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Lat Stretch an Stange */
          "howto.lat_stretch_an_stange.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.lat_stretch_an_stange.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.lat_stretch_an_stange.coaching_cues.2" : "Control range—no bouncing.",
          "howto.lat_stretch_an_stange.atmung.1" : "Exhale slowly and soften tension.",
          "howto.lat_stretch_an_stange.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.lat_stretch_an_stange.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.lat_stretch_an_stange.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.lat_stretch_an_stange.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.lat_stretch_an_stange.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.lat_stretch_an_stange.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.lat_stretch_an_stange.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Quad Stretch */
          "howto.quad_stretch.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.quad_stretch.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.quad_stretch.coaching_cues.2" : "Control range—no bouncing.",
          "howto.quad_stretch.atmung.1" : "Exhale slowly and soften tension.",
          "howto.quad_stretch.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.quad_stretch.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.quad_stretch.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.quad_stretch.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.quad_stretch.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.quad_stretch.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.quad_stretch.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Happy Baby */
          "howto.happy_baby.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.happy_baby.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.happy_baby.coaching_cues.2" : "Control range—no bouncing.",
          "howto.happy_baby.atmung.1" : "Exhale slowly and soften tension.",
          "howto.happy_baby.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.happy_baby.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.happy_baby.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.happy_baby.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.happy_baby.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.happy_baby.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.happy_baby.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Spinal Twist (liegend) */
          "howto.spinal_twist_liegend.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.spinal_twist_liegend.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.spinal_twist_liegend.coaching_cues.2" : "Control range—no bouncing.",
          "howto.spinal_twist_liegend.atmung.1" : "Exhale slowly and soften tension.",
          "howto.spinal_twist_liegend.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.spinal_twist_liegend.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.spinal_twist_liegend.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.spinal_twist_liegend.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.spinal_twist_liegend.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.spinal_twist_liegend.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.spinal_twist_liegend.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Cobra Stretch */
          "howto.cobra_stretch.setup.1" : "Start in a comfortable position; spine long, shoulders relaxed.",
          "howto.cobra_stretch.coaching_cues.1" : "Melt into the stretch as you exhale.",
          "howto.cobra_stretch.coaching_cues.2" : "Control range—no bouncing.",
          "howto.cobra_stretch.atmung.1" : "Exhale slowly and soften tension.",
          "howto.cobra_stretch.atmung.2" : "Never breathe into pain; stay smooth.",
          "howto.cobra_stretch.haeufige_fehler.1" : "Bouncing into end range.",
          "howto.cobra_stretch.haeufige_fehler.2" : "Compensations (arching back, shrugging).",
          "howto.cobra_stretch.haeufige_fehler.3" : "Chasing pain instead of gentle tension.",
          "howto.cobra_stretch.skalierung_varianten.1" : "Easier: reduce range or hold time.",
          "howto.cobra_stretch.skalierung_varianten.2" : "Harder: increase hold time; fine-tune angle.",
          "howto.cobra_stretch.skalierung_varianten.3" : "Harder: active end-range or contract-relax.",

          /* Stretching Brust */
          "howto.stretching_brust.setup.1" : "Stable stance and clear space; move with control.",
          "howto.stretching_brust.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.stretching_brust.coaching_cues.2" : "Quality before quantity.",
          "howto.stretching_brust.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.stretching_brust.atmung.2" : "Avoid breath-holding.",
          "howto.stretching_brust.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.stretching_brust.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.stretching_brust.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.stretching_brust.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.stretching_brust.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.stretching_brust.skalierung_varianten.3" : "Harder: add load if available.",

          /* world geratest stretch */
          "howto.world_geratest_stretch.setup.1" : "Stable stance and clear space; move with control.",
          "howto.world_geratest_stretch.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.world_geratest_stretch.coaching_cues.2" : "Quality before quantity.",
          "howto.world_geratest_stretch.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.world_geratest_stretch.atmung.2" : "Avoid breath-holding.",
          "howto.world_geratest_stretch.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.world_geratest_stretch.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.world_geratest_stretch.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.world_geratest_stretch.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.world_geratest_stretch.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.world_geratest_stretch.skalierung_varianten.3" : "Harder: add load if available.",

          /* stretching schultern */
          "howto.stretching_schultern.setup.1" : "Stable stance and clear space; move with control.",
          "howto.stretching_schultern.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.stretching_schultern.coaching_cues.2" : "Quality before quantity.",
          "howto.stretching_schultern.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.stretching_schultern.atmung.2" : "Avoid breath-holding.",
          "howto.stretching_schultern.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.stretching_schultern.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.stretching_schultern.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.stretching_schultern.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.stretching_schultern.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.stretching_schultern.skalierung_varianten.3" : "Harder: add load if available.",

          /* stretching rücken */
          "howto.stretching_ruecken.setup.1" : "Stable stance and clear space; move with control.",
          "howto.stretching_ruecken.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.stretching_ruecken.coaching_cues.2" : "Quality before quantity.",
          "howto.stretching_ruecken.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.stretching_ruecken.atmung.2" : "Avoid breath-holding.",
          "howto.stretching_ruecken.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.stretching_ruecken.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.stretching_ruecken.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.stretching_ruecken.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.stretching_ruecken.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.stretching_ruecken.skalierung_varianten.3" : "Harder: add load if available.",

          /* Schulter taps im plank */
          "howto.schulter_taps_im_plank.setup.1" : "Body in a straight line; brace the trunk, keep ribs down.",
          "howto.schulter_taps_im_plank.coaching_cues.1" : "Move from the trunk, not with momentum.",
          "howto.schulter_taps_im_plank.coaching_cues.2" : "Keep the neck long and the lower back neutral.",
          "howto.schulter_taps_im_plank.atmung.1" : "Inhale calmly; exhale to maintain brace.",
          "howto.schulter_taps_im_plank.atmung.2" : "Avoid breath-holding—breathe evenly.",
          "howto.schulter_taps_im_plank.haeufige_fehler.1" : "Arching the lower back (losing neutral).",
          "howto.schulter_taps_im_plank.haeufige_fehler.2" : "Pulling on the head/neck or shrugging shoulders.",
          "howto.schulter_taps_im_plank.haeufige_fehler.3" : "Hips rotating or sagging.",
          "howto.schulter_taps_im_plank.skalierung_varianten.1" : "Easier: shorten lever or reduce range/hold time.",
          "howto.schulter_taps_im_plank.skalierung_varianten.2" : "Harder: lengthen lever, unilateral work, longer holds.",
          "howto.schulter_taps_im_plank.skalierung_varianten.3" : "Harder: add light load or anti-rotation challenge.",

          /* Dehnung brust */
          "howto.dehnung_brust.setup.1" : "Stable stance and clear space; move with control.",
          "howto.dehnung_brust.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.dehnung_brust.coaching_cues.2" : "Quality before quantity.",
          "howto.dehnung_brust.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.dehnung_brust.atmung.2" : "Avoid breath-holding.",
          "howto.dehnung_brust.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.dehnung_brust.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.dehnung_brust.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.dehnung_brust.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.dehnung_brust.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.dehnung_brust.skalierung_varianten.3" : "Harder: add load if available.",

          /* stretching triez's */
          "howto.stretching_triezs.setup.1" : "Stable stance and clear space; move with control.",
          "howto.stretching_triezs.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.stretching_triezs.coaching_cues.2" : "Quality before quantity.",
          "howto.stretching_triezs.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.stretching_triezs.atmung.2" : "Avoid breath-holding.",
          "howto.stretching_triezs.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.stretching_triezs.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.stretching_triezs.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.stretching_triezs.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.stretching_triezs.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.stretching_triezs.skalierung_varianten.3" : "Harder: add load if available.",

          /* Katzenbuckel/Pferderücken */
          "howto.katzenbuckel_pferderuecken.setup.1" : "Stable stance and clear space; move with control.",
          "howto.katzenbuckel_pferderuecken.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.katzenbuckel_pferderuecken.coaching_cues.2" : "Quality before quantity.",
          "howto.katzenbuckel_pferderuecken.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.katzenbuckel_pferderuecken.atmung.2" : "Avoid breath-holding.",
          "howto.katzenbuckel_pferderuecken.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.katzenbuckel_pferderuecken.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.katzenbuckel_pferderuecken.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.katzenbuckel_pferderuecken.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.katzenbuckel_pferderuecken.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.katzenbuckel_pferderuecken.skalierung_varianten.3" : "Harder: add load if available.",

          /* stretching Hüfte */
          "howto.stretching_huefte.setup.1" : "Stable stance and clear space; move with control.",
          "howto.stretching_huefte.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.stretching_huefte.coaching_cues.2" : "Quality before quantity.",
          "howto.stretching_huefte.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.stretching_huefte.atmung.2" : "Avoid breath-holding.",
          "howto.stretching_huefte.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.stretching_huefte.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.stretching_huefte.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.stretching_huefte.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.stretching_huefte.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.stretching_huefte.skalierung_varianten.3" : "Harder: add load if available.",

          /* World's Greatest Stretch */
          "howto.worlds_greatest_stretch.setup.1" : "Stable stance and clear space; move with control.",
          "howto.worlds_greatest_stretch.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.worlds_greatest_stretch.coaching_cues.2" : "Quality before quantity.",
          "howto.worlds_greatest_stretch.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.worlds_greatest_stretch.atmung.2" : "Avoid breath-holding.",
          "howto.worlds_greatest_stretch.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.worlds_greatest_stretch.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.worlds_greatest_stretch.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.worlds_greatest_stretch.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.worlds_greatest_stretch.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.worlds_greatest_stretch.skalierung_varianten.3" : "Harder: add load if available.",

          /* stretching Bauch */
          "howto.stretching_bauch.setup.1" : "Stable stance and clear space; move with control.",
          "howto.stretching_bauch.coaching_cues.1" : "Keep joints in neutral paths.",
          "howto.stretching_bauch.coaching_cues.2" : "Quality before quantity.",
          "howto.stretching_bauch.atmung.1" : "Breathe steadily; exhale on effort.",
          "howto.stretching_bauch.atmung.2" : "Avoid breath-holding.",
          "howto.stretching_bauch.haeufige_fehler.1" : "Using momentum instead of control.",
          "howto.stretching_bauch.haeufige_fehler.2" : "Ignoring pain instead of adjusting range.",
          "howto.stretching_bauch.haeufige_fehler.3" : "Losing alignment under fatigue.",
          "howto.stretching_bauch.skalierung_varianten.1" : "Easier: reduce range/lever.",
          "howto.stretching_bauch.skalierung_varianten.2" : "Harder: lengthen lever or slow tempo.",
          "howto.stretching_bauch.skalierung_varianten.3" : "Harder: add load if available.",

          
          
        // Time qualifiers
        "time.perDay": "per day",
        "time.perWeek": "per week",

        // Streak
        "challenge.streak.title.format": "%d-day streak",
        "challenge.streak.desc.format": "Train %d days in a row.",

        // Active days per week
        "challenge.sessions.perWeek.format": "%d active days/week",

        "exercise.instructions.arnold_press_dumbbell": "Start with the dumbbells in front of the chest; rotate the palms forward as you press up.",
        "exercise.instructions.back_extension_weight": "Hold an extra weight in front of the chest while doing back extensions.",
        "exercise.instructions.none": "No instructions available",

        "exercise.instructions.bench_dip": "Support yourself behind you on a bench, lower the body and press back up.",
        "exercise.instructions.bench_press_barbell": "Lie on the bench, grip the barbell shoulder-width and press it up.",
        "exercise.instructions.bench_press_dumbbell": "Lie on the bench, hold dumbbells and press them up evenly.",
        "exercise.instructions.bench_press_smith_machine": "Perform the bench press movement in the Smith machine.",
        "exercise.instructions.bench_press_close_grip_barbell": "Grip the barbell narrow, lower it to the chest and press up.",
        "exercise.instructions.bench_press_wide_grip_barbell": "Grip the barbell wide, lower it under control and press up.",
        "exercise.instructions.bent_over_one_arm_row_dumbbell": "Brace with one hand and row the dumbbell toward the torso with the other.",
        "exercise.instructions.bent_over_row_barbell": "Hinge forward and pull the barbell toward the waist.",
        "exercise.instructions.bent_over_row_dumbbell": "With the torso hinged, row two dumbbells to the hips simultaneously.",
        "exercise.instructions.bent_over_row_underhand_barbell": "Use an underhand grip and pull the barbell to the lower abdomen.",
        "exercise.instructions.bicep_curl_barbell": "Hold the barbell shoulder-width and curl under control.",
        "exercise.instructions.bicep_curl_cable": "Pull the cable handle to the chest with elbows flexed.",
        "exercise.instructions.bicep_curl_dumbbell": "Hold dumbbells at your sides and curl up under control.",
        "exercise.instructions.bicep_curl_machine": "Perform controlled curls on the machine.",
        "exercise.instructions.biceps_curl_scottbank": "Rest the arms on the preacher bench and curl with controlled motion.",
        "exercise.instructions.box_squat_barbell": "Lower onto a box with a barbell and stand up explosively.",
        "exercise.instructions.bulgarian_split_squat": "Place one foot back on a bench and perform single-leg squats.",
        "exercise.instructions.cable_crossover": "Bring both cable handles together in front at chest height.",
        "exercise.instructions.cable_crunch": "Pull the rope attachment down while flexing the torso.",
        "exercise.instructions.cable_kickback": "Extend the leg backward against cable resistance.",
        "exercise.instructions.cable_pull_through": "Hinge forward and pull the cable through the legs forward.",
        "exercise.instructions.cable_twist": "Pull the cable across the body to the opposite side.",
        "exercise.instructions.calf_press_on_leg_press": "Press the weight up with the toes.",
        "exercise.instructions.calf_press_on_seated_leg_press": "Do calf raises on the seated leg press.",
        "exercise.instructions.chest_dip": "Lower yourself on the dip bars and press back up.",
        "exercise.instructions.chest_fly_dumbbell": "Move the dumbbells out to the sides and back together.",
        "exercise.instructions.chest_fly_kabel_oben": "Pull the cables from above together in an arc.",
        "exercise.instructions.chest_fly_kabel_von_unten": "Pull the cables from low to high together.",
        "exercise.instructions.chest_press_machine": "Press the machine handles straight forward.",
        "exercise.instructions.clean_barbell": "Pull the barbell explosively from the floor to the shoulders.",
        "exercise.instructions.clean_and_jerk_barbell": "Perform a clean, then jerk the bar overhead.",
        "exercise.instructions.concentration_curl_dumbbell": "Do concentration curls with the elbow braced on the thigh.",
        "exercise.instructions.crunch_machine": "Do crunches with added resistance on the machine.",
        "exercise.instructions.deadlift_barbell": "Lift the barbell from the floor with a straight back.",
        "exercise.instructions.deadlift_dumbbell": "Do deadlifts with dumbbells next to the legs.",
        "exercise.instructions.deadlift_smith_machine": "Do deadlifts in the Smith machine.",
        "exercise.instructions.decline_bench_press_barbell": "Lie on a decline bench and press the barbell up.",
        "exercise.instructions.decline_bench_press_dumbbell": "Do the same movement with dumbbells on a decline bench.",
        "exercise.instructions.decline_bench_press_smith_machine": "Perform the exercise in the Smith machine on a decline bench.",
        "exercise.instructions.deficit_deadlift_barbell": "Stand on a platform and deadlift for a larger range of motion.",
        "exercise.instructions.dumbbell_row": "Row the dumbbell to the waist with the torso hinged.",
        "exercise.instructions.dumbbell_shoulder_press": "Press the dumbbells overhead.",
        "exercise.instructions.ez_bar_curl": "Curl with the EZ bar under control.",
        "exercise.instructions.face_pull_cable": "Pull the rope to face height toward your face.",
        "exercise.instructions.floor_press_barbell": "Lie on the floor and press the barbell up.",
        "exercise.instructions.front_raise_plate": "Raise a weight plate in front to shoulder height.",
        "exercise.instructions.front_squat_barbell": "Rack the bar on the front shoulders and squat.",
        "exercise.instructions.glute_kickback_machine": "Press the leg back using the machine.",
        "exercise.instructions.goblet_squat_kettlebell": "Hold the kettlebell at the chest and squat.",
        "exercise.instructions.good_morning_barbell": "Hinge the torso forward with a barbell on the shoulders.",
        "exercise.instructions.hack_squat_machine": "Perform squats in the hack squat machine.",
        "exercise.instructions.hack_squat_barbell": "Hold the barbell behind the body and squat.",
        "exercise.instructions.hammer_curl_band": "Curl with a neutral grip against band resistance.",
        "exercise.instructions.hammer_curl_cable": "Curl with a neutral grip on the cable machine.",
        "exercise.instructions.hammer_curl_dumbbell": "Curl with a neutral grip using dumbbells.",
        "exercise.instructions.hang_clean_barbell": "Pull the bar explosively from the hang to the shoulder.",
        "exercise.instructions.hang_snatch_barbell": "Pull the bar from the hang overhead explosively.",
        "exercise.instructions.high_pull_barbell": "Pull the barbell explosively up to the chest.",
        "exercise.instructions.incline_bench_press_barbell": "Press the barbell up on an incline bench.",
        "exercise.instructions.incline_bench_press_cable": "Do incline pressing on the cable machine.",
        "exercise.instructions.incline_bench_press_dumbbell": "Press the dumbbells up on an incline.",
        "exercise.instructions.incline_bench_press_smith_machine": "Press the Smith machine bar up on an incline.",
        "exercise.instructions.incline_chest_fly_dumbbell": "Do incline flyes with dumbbells.",
        "exercise.instructions.incline_chest_press_machine": "Press the machine handles forward from an incline bench.",
        "exercise.instructions.incline_curl_dumbbell": "Do incline dumbbell curls.",
        "exercise.instructions.incline_row_dumbbell": "Row with dumbbells on an incline bench.",
        "exercise.instructions.inverted_row_bodyweight": "Pull your chest up to a bar underneath you.",
        "exercise.instructions.iso_lateral_chest_press_machine": "Press the handles forward unilaterally with the chest.",
        "exercise.instructions.iso_lateral_row_machine": "Row the handles unilaterally toward the torso.",
        "exercise.instructions.jump_shrug_barbell": "Do a slight jump and shrug the shoulders explosively with the barbell.",
        "exercise.instructions.jump_squat": "Perform an explosive squat finishing with a jump.",
        "exercise.instructions.kettlebell_swing": "Swing the kettlebell forward with straight arms.",
        "exercise.instructions.kettlebell_turkish_get_up": "Stand up to a stable overhead position with a kettlebell.",
        "exercise.instructions.klappmesser_crunch": "Touch hands and feet together in the air.",
        "exercise.instructions.knee_raise_captain_s_chair": "Raise the knees toward the chest in the captain’s chair.",
        "exercise.instructions.lat_pulldown_cable": "Pull the bar to the upper sternum.",
        "exercise.instructions.lat_pulldown_machine": "Pull the machine handles down under control.",
        "exercise.instructions.lat_pulldown_single_arm": "Pull down one side at a time using cable or handle.",
        "exercise.instructions.lat_pulldown_underhand_band": "Pull the resistance band down with an underhand grip.",
        "exercise.instructions.lat_pulldown_underhand_cable": "Pull the bar to the sternum with an underhand grip.",
        "exercise.instructions.lat_pulldown_wide_grip_cable": "Pull the bar down with a wide grip.",
        "exercise.instructions.lateral_raise_band": "Raise the arms to the sides using a resistance band.",
        "exercise.instructions.lateral_raise_dumbbell": "Raise dumbbells to the sides to shoulder height.",
        "exercise.instructions.lateral_raise_machine": "Raise the arms to the sides on the machine.",
        "exercise.instructions.leg_extension_machine": "Extend the legs on the leg extension machine.",
        "exercise.instructions.leg_press": "Press the weight away with the legs.",
        "exercise.instructions.lunge_barbell": "Do lunges with a barbell.",
        "exercise.instructions.lunge_bodyweight": "Do bodyweight lunges.",
        "exercise.instructions.lunge_dumbbell": "Do lunges with dumbbells.",
        "exercise.instructions.lying_leg_curl_machine": "Curl the legs on the lying leg curl machine.",
        "exercise.instructions.overhead_press_barbell": "Press the barbell overhead.",
        "exercise.instructions.overhead_press_cable": "Press the cable weight overhead.",
        "exercise.instructions.overhead_press_dumbbell": "Press the dumbbells overhead.",
        "exercise.instructions.overhead_press_smith_machine": "Press the Smith machine bar overhead.",
        "exercise.instructions.overhead_squat_barbell": "Perform a squat with a barbell held overhead.",
        "exercise.instructions.pec_deck_machine": "Perform flyes on the machine.",
        "exercise.instructions.pendlay_row_barbell": "Row the barbell from the floor with an explosive pull.",
        "exercise.instructions.pistol_squat": "Perform a controlled single-leg squat.",
        "exercise.instructions.power_clean_barbell": "Pull the barbell quickly to the shoulder (power clean).",
        "exercise.instructions.preacher_curl_barbell": "Do preacher curls with a barbell.",
        "exercise.instructions.preacher_curl_machine": "Do preacher curls on the machine.",
        "exercise.instructions.pull_up": "Pull yourself up on a bar with an overhand grip.",
        "exercise.instructions.pull_up_assisted": "Do assisted pull-ups on a bar.",
        "exercise.instructions.pull_up_band": "Do band-assisted pull-ups.",
        "exercise.instructions.pullover": "Lower the weight behind the head and bring it back up.",
        "exercise.instructions.pullover_dumbbell": "Perform the movement overhead with a dumbbell.",
        "exercise.instructions.pullover_machine": "Perform the pullover on the machine under control.",
        "exercise.instructions.push_press": "Drive the bar overhead with a dip and press.",
        "exercise.instructions.push_up": "Press the body up from the floor.",
        "exercise.instructions.push_up_band": "Do push-ups with an added resistance band.",
        "exercise.instructions.push_up_knees": "Do push-ups on the knees.",
        "exercise.instructions.rack_pull_barbell": "Lift the barbell from the rack in a partial deadlift (rack pull).",
        "exercise.instructions.reverse_crunch": "Pull the knees to the chest and lift the hips slightly.",
        "exercise.instructions.reverse_curl_band": "Curl with the backs of the hands up against a resistance band (reverse curl).",
        "exercise.instructions.reverse_curl_barbell": "Do reverse curls with a barbell.",
        "exercise.instructions.reverse_curl_dumbbell": "Do reverse curls with dumbbells.",
        "exercise.instructions.reverse_fly_cable": "Pull the cable arms back to the sides (reverse fly).",
        "exercise.instructions.reverse_fly_dumbbell": "Do reverse flyes with dumbbells to the sides.",
        "exercise.instructions.reverse_fly_machine": "Pull the machine handles back to the sides.",
        "exercise.instructions.romanian_deadlift_dumbbell": "Lower the dumbbells with straight legs under control.",
        "exercise.instructions.rowing_machine": "Pull the handle to the torso under control and return it.",
        "exercise.instructions.running_treadmill": "Run on the treadmill at an even pace.",
        "exercise.instructions.russian_twist": "Rotate the torso side to side in a seated position.",
        "exercise.instructions.seated_calf_raise_machine": "Raise the heels with resistance on the seated calf machine.",
        "exercise.instructions.seated_calf_raise_plate_loaded": "Do the calf raise with weight plates loaded.",
        "exercise.instructions.seated_leg_curl_machine": "Curl the legs on the seated leg curl machine.",
        "exercise.instructions.seated_leg_press_machine": "Press the weight with the legs from a seated position.",
        "exercise.instructions.seated_overhead_press_barbell": "Press the barbell overhead while seated.",
        "exercise.instructions.seated_overhead_press_dumbbell": "Press the dumbbells overhead while seated.",
        "exercise.instructions.seated_palms_up_wrist_curl_dumbbell": "Roll the dumbbells in with palms up (wrist curl).",
        "exercise.instructions.seated_row_cable": "Row the cable to the torso while seated.",
        "exercise.instructions.seated_row_machine": "Row the machine handles to the chest.",
        "exercise.instructions.seated_wide_grip_row_cable": "Row the cable to the chest with a wide grip.",
        "exercise.instructions.shoulder_press_machine": "Press the handles overhead.",
        "exercise.instructions.shoulder_press_plate_loaded": "Press overhead on a plate-loaded machine.",
        "exercise.instructions.shoulder_press_dumbbells": "Press dumbbells overhead.",
        "exercise.instructions.shrug_barbell": "Shrug the shoulders up with a barbell.",
        "exercise.instructions.shrug_dumbbells": "Shrug the shoulders up with dumbbells.",
        "exercise.instructions.shrug_machine": "Shrug up using the machine handles.",
        "exercise.instructions.shrug_smith_machine": "Do shrugs in the Smith machine.",
        "exercise.instructions.side_bend_cable": "Bend to the side with a cable.",
        "exercise.instructions.side_bend_dumbbell": "Bend to the side with a dumbbell.",
        "exercise.instructions.sit_up": "Roll the torso up toward the knees.",
        "exercise.instructions.skullcrusher_barbell": "Lower the barbell toward the forehead and extend the arms.",
        "exercise.instructions.skullcrusher_dumbbell": "Do the same movement with dumbbells.",
        "exercise.instructions.snatch_barbell": "Pull the barbell explosively overhead (snatch).",
        "exercise.instructions.spider_curls": "Do spider curls lying face down on a bench.",
        "exercise.instructions.split_jerk_barbell": "Jerk the weight overhead with a split stance.",
        "exercise.instructions.squat_band": "Do squats with a resistance band.",
        "exercise.instructions.squat_barbell": "Do back squats with a barbell.",
        "exercise.instructions.squat_bodyweight": "Do bodyweight squats.",
        "exercise.instructions.squat_dumbbell": "Hold dumbbells and squat.",
        "exercise.instructions.squat_machine": "Do squats in a guided machine.",
        "exercise.instructions.squat_smith_machine": "Do squats in the Smith machine.",
        "exercise.instructions.squat_row_band": "Combine a squat with a band row.",
        "exercise.instructions.standing_calf_raise_barbell": "Raise the heels with a barbell on the shoulders.",
        "exercise.instructions.standing_calf_raise_bodyweight": "Raise the heels without extra weight.",
        "exercise.instructions.standing_calf_raise_dumbbell": "Raise the heels holding dumbbells.",
        "exercise.instructions.standing_calf_raise_machine": "Do standing calf raises on the machine.",
        "exercise.instructions.standing_calf_raise_smith_machine": "Do the standing calf raise in the Smith machine.",
        "exercise.instructions.step_up": "Step onto a platform with one leg and bring the other up.",
        "exercise.instructions.stiff_leg_deadlift_barbell": "Lower the barbell with straight legs under control.",
        "exercise.instructions.stiff_leg_deadlift_dumbbell": "Lower the dumbbells with straight legs under control.",
        "exercise.instructions.stiff_leg_deadlift_band": "Hinge the torso against the resistance of a band.",
        "exercise.instructions.strict_military_press_barbell": "Strict press the barbell overhead while standing.",
        "exercise.instructions.sumo_deadlift_barbell": "Lift the weight with a wide (sumo) stance.",
        "exercise.instructions.sumo_deadlift_high_pull_barbell": "Combine a sumo deadlift with a high pull to the chest.",
        "exercise.instructions.superman": "Raise arms and legs simultaneously while lying prone.",
        "exercise.instructions.supine_press": "Press the weight up while lying on your back.",
        "exercise.instructions.sz_curl": "Do curls with an EZ bar.",
        "exercise.instructions.t_bar_row": "Row the weight toward the torso with a neutral grip.",
        "exercise.instructions.thruster_barbell": "Combine a front squat with an overhead press.",
        "exercise.instructions.thruster_kettlebell": "Do the squat-to-press combination with a kettlebell.",
        "exercise.instructions.toes_to_bar": "While hanging, raise the feet to the bar.",
        "exercise.instructions.torso_rotation_machine": "Rotate the torso against the machine’s resistance.",
        "exercise.instructions.trap_bar_deadlift": "Lift the weight from the floor with a trap bar.",
        "exercise.instructions.tricep_pushdown_single_handed": "Press the single cable handle down one side at a time.",
        "exercise.instructions.triceps_dip": "Press the body up using the arms.",
        "exercise.instructions.triceps_dip_assisted": "Do assisted dips on the machine.",
        "exercise.instructions.triceps_extension_barbell": "Extend the arms overhead with a barbell.",
        "exercise.instructions.triceps_extension_cable": "Extend the arms with the cable machine.",
        "exercise.instructions.triceps_extension_dumbbell": "Extend the arms with one or two dumbbells.",
        "exercise.instructions.triceps_extension_machine": "Perform the movement on the machine.",
        "exercise.instructions.triceps_extension": "Perform any triceps extension variation.",
        "exercise.instructions.upright_row_barbell": "Pull the barbell up close to the body (upright row).",
        "exercise.instructions.upright_row_cable": "Pull the cable up close to the body (upright row).",
        "exercise.instructions.upright_row_dumbbell": "Pull dumbbells up close to the body (upright row).",
        "exercise.instructions.v_up": "Touch hands and feet together in the air.",
        "exercise.instructions.wrist_roller": "Roll a weight up using the wrists (wrist roller).",
        "exercise.instructions.zercher_squat_barbell": "Hold the barbell in the elbow creases and squat.",

        "round.of": "Round %d of %d",
        "exercise.tapForDetails": "Tap for details",
        "round.number": "Round %d/%d",
        "round.next": "Next Round %d",
        "next.round.exercise": "Round %d – Next: %@",
        "skip.rest": "Skip rest",
        "training.pauseTimer" : "Rest timer",
        "live.running"  : "🏋️ Workout running",
        "live.sets"     : "Sets",
        "live.duration" : "Duration",
        "live.weight"   : "Weight",
        "training.done" : "Done",
        
        
        
        // HowTo Defaults – Cardio
        "howto.defaults.cardio.breathing.1": "Breathe calmly and rhythmically; don’t hold your breath.",
        "howto.defaults.cardio.breathing.2": "On the exhale, land softly and keep tension.",
        "howto.defaults.cardio.mistakes.1": "Landing too hard / heels slamming down.",
        "howto.defaults.cardio.mistakes.2": "Torso tipping too far forward; forgetting to use the arms.",
        "howto.defaults.cardio.progressions.1": "Easier: shorter intervals (20–30s), lower jump height.",
        "howto.defaults.cardio.progressions.2": "Harder: longer intervals (45–60s), increase pace.",
        "howto.defaults.cardio.cues.1": "Land softly; knees track the toes.",
        "howto.defaults.cardio.cues.2": "Actively swing the arms (set the rhythm).",

        // Core
        "howto.defaults.core.breathing.1": "Breathe in calmly; on the exhale pull ribs down & brace the core.",
        "howto.defaults.core.breathing.2": "No straining—keep the breath even.",
        "howto.defaults.core.mistakes.1": "Overarching / low back lifts off.",
        "howto.defaults.core.mistakes.2": "Pulling on the head (in crunch variations).",
        "howto.defaults.core.progressions.1": "Easier: shorten range/levers, reduce hold time.",
        "howto.defaults.core.progressions.2": "Harder: lengthen levers, unilateral options, longer hold.",
        "howto.defaults.core.cues.1": "Ribs toward hips, neck long.",
        "howto.defaults.core.cues.2": "Move from the trunk, not with momentum.",

        // Stretch
        "howto.defaults.stretch.breathing.1": "Exhale long and ‘melt’ into the stretch.",
        "howto.defaults.stretch.breathing.2": "Don’t breathe into pain; keep the range controlled.",
        "howto.defaults.stretch.mistakes.1": "Bouncing; forcing into end ranges.",
        "howto.defaults.stretch.mistakes.2": "Compensation (arched low back, shoulders shrugging).",
        "howto.defaults.stretch.progressions.1": "Easier: smaller range, shorter holds.",
        "howto.defaults.stretch.progressions.2": "Harder: longer holds, slightly more intense angle.",
        "howto.defaults.stretch.cues.1": "Spine long, neck relaxed.",
        "howto.defaults.stretch.cues.2": "Pelvis position controls stretch intensity.",

        // Upper Back
        "howto.defaults.upperBack.breathing.1": "Inhale lowering, exhale on activation/lift.",
        "howto.defaults.upperBack.breathing.2": "Move shoulder blades deliberately (pro-/retraction).",
        "howto.defaults.upperBack.mistakes.1": "Throwing the head back; overextending the low back.",
        "howto.defaults.upperBack.mistakes.2": "Using momentum instead of control.",
        "howto.defaults.upperBack.progressions.1": "Easier: smaller range, shorter sets.",
        "howto.defaults.upperBack.progressions.2": "Harder: longer holds, tempo 3–1–1.",
        "howto.defaults.upperBack.cues.1": "Shoulder blades ‘into the back pockets’.",
        "howto.defaults.upperBack.cues.2": "Arms long, neck neutral.",

        // Push
        "howto.defaults.push.breathing.1": "Inhale down, exhale as you press up.",
        "howto.defaults.push.breathing.2": "Brace the core; keep ribs down.",
        "howto.defaults.push.mistakes.1": "Elbows flared too wide (>60°).",
        

        
        // ---- Exercise Detail (NEW) ----
        "exercise.muscleGroups": "Muscle group(s)",
        "exercise.instructions": "Instructions",
        "exercise.lastTraining": "Last training",
        "exercise.volume.30d": "Volume (30d)",
        "exercise.recentSets": "Recent sets",
        "exercise.chart.empty": "No data for the chart yet",
        "exercise.noData.sets": "No training data yet",
        "exercise.set.item": "Set %d: %d reps",
        "exercise.badge.10trainings": "10× workouts",
        "exercise.badge.newMax": "New PR",

        // Notes
        "notes.title": "Notes",
        "notes.new": "New note",
        "notes.empty": "No notes yet — add the first one.",
        "notes.placeholder": "Enter note …",
        "notes.emptySingle": "Empty note",



        // (Optional alias)
        "skip.reset": "Skip rest",
        "training.restOverTitle" : "Rest is over",
        "training.restOverBody"  : "Time to continue!",
        "workout.start": "🚀 Start workout",
        "common.viewAll": "View all",
        "common.calories": "Calories",
        "common.edit": "Edit",              // ⬅️ new
        "exercise.number": "Exercise %d",
        "training.stretch.title": "Stretch & Mobility",
        "training.stretch.subtitle": "Flexibility & Recovery",
        "training.stretch.duration": "10–15 min",
        "training.stretch.level": "All levels",

        "training.meditation.title": "Meditation & Focus",
        "training.meditation.subtitle": "Mindfulness & Breathing",
        "training.meditation.duration": "8–12 min",
        "training.meditation.level": "All levels",

        "training.core.title": "Core Crusher",
        "training.core.subtitle": "Abs & Midline",
        "training.core.duration": "12–15 min",
        "training.core.level": "All levels",

        "next.exercise": "Next: %@",
        "exercise.skip": "Skip exercise",
        "pause": "Pause",
        "resume": "Resume",
        "add.time": "+15s",
        "finish": "🎉 Finish",
        "workout.complete": "Workout complete",
        "week.complete": "Week done 🎉",
        "feedback.placeholder": "Your feedback...",
        "save": "Save & Finish",
        "saved": "Saved 🙌",

        // Weeks & Sets
        "week.number": "Week %d",
        "sets.completed": "%d/%d Sets completed",

        // Challenges
        "challenge.workouts.title": "5 Workouts per week",
        "challenge.workouts.desc": "Complete 5 workouts by Sunday",
        "challenge.steps.title": "10,000 steps per day",
        "challenge.steps.desc": "Stay active every day",
        "challenges.title": "Challenges",

    
          "paywall.h1": "Workouts. Simple. Every Day.",
            "paywall.h2": "We’re in Beta — all Pro features are currently free.",
            "paywall.bullet.plan": "Personalized plans & recommendations",
            "paywall.bullet.stats": "Advanced stats & PR history",
            "paywall.bullet.motivation": "Motivation with goals & badges",

            "paywall.timeline.title": "What to expect during your trial:",
            "paywall.timeline.today.title": "Today — Unlock everything",
            "paywall.timeline.today.text": "Instant access to all Pro features.",
            "paywall.timeline.reminder.title": "In 5 days — Reminder",
            "paywall.timeline.reminder.text": "We’ll remind you before it ends.",
            "paywall.timeline.end.title": "In 7 days — Trial ends",
            "paywall.timeline.end.text": "You’ll only be charged if you don’t cancel.",

            "paywall.plan.yearly.title": "Yearly Plan",
            "paywall.plan.yearly.tag": "7-day free trial",
            "paywall.plan.yearly.price": "29,99€/year",
            "paywall.plan.yearly.foot": "only 2,49€/mo",
            "paywall.plan.monthly.title": "Monthly",
            "paywall.plan.monthly.price": "2,99/month",
            "paywall.plan.beta.title": "Beta Access",
            "paywall.plan.beta.tag": "Unlock all Pro features for free",
            "paywall.plan.beta.price": "$0.00",
            "paywall.plan.badge.best": "BEST VALUE",
            "paywall.plan.badge.beta": "BETA",

            "paywall.disclaimer": "One-time in-app purchase or subscription. Cancel anytime. Prices may vary.",
            "paywall.cta": "Start my free trial",
            "paywall.cta.beta": "Unlock for free",
            "paywall.restore": "Restore purchases",
            "paywall.terms": "Terms",
            "paywall.privacy": "Privacy",

            "premium.locked": "Premium Stats",
            "premium.unlock": "Unlock for free",

        // General
        "week": "Week",
        "reset.progress": "Reset progress",
        "weight": "Weight",
        "reps": "Reps",
        "equipment": "Equipment",
        "warmup": "Warm-up",
        "cooldown": "Cool-down",
        "training.units": "Training Units",
        "duration": "Duration",
        "calories": "Calories",
        "focus": "Focus",
        "start": "Start",
        "level": "Level",
        "days": "days",

        // Templates
        "templates.title": "Training Templates",
        "templates.empty.title": "No templates yet",
        "templates.empty.subtitle": "Tap the ➕ to create your first template.",
        "templates.empty.button": "Create new template",
        "templates.section.default": "Default Templates",
        "templates.section.custom": "My Templates",
        "templates.edit": "Edit",
        "templates.share": "Share",
        "templates.delete": "Delete",
        "templates.exercisesCount": "%d exercises",
        "templates.pin": "Pin to Home",
        "templates.unpin": "Unpin from Home",
        
        // Onboarding Phase 2 (English)
        "onboarding.easyLogging.title": "Start a Workout",
        "onboarding.easyLogging.subtitle": "Choose a template to begin.",
        "onboarding.trackIt.title": "Track it",
        "onboarding.trackIt.subtitle": "Log sets. Focus on lifting.",
        "onboarding.finished.title": "Review & Finish",
        "onboarding.finished.subtitle": "Your journey continues.",
        
        // Template Names (English)
        "Push": "Push",
        "Pull": "Pull",
        "Legs": "Legs",
        "Upper Body": "Upper Body",
        "Lower Body": "Lower Body",
        "Full Body A": "Full Body A",
        "Full Body B": "Full Body B",
        "Cardio & Core": "Cardio & Core",
        "Arms": "Arms",
        
        "training.addExercise.new": "Add new exercise \"%@\"",
        "rest": "Rest",
        
        // Onboarding Phase 2 - Statistics & Permissions
        "onboarding.statistics.title": "Visualize Your Growth",
        "onboarding.statistics.subtitle": "Deep insights into your training habits and muscle recovery.",
        "onboarding.statistics.activityStreak": "Activity Streak",
        "onboarding.notifications.title": "Stay Consistent",
        "onboarding.notifications.subtitle": "Get reminders to workout and track your progress.",
        "onboarding.health.title": "Sync with Health",
        "onboarding.health.subtitle": "Import your workouts and biometrics automatically.",
        
        // Onboarding - Social Feed
        "onboarding.social.title": "Join the Community",
        "onboarding.social.subtitle": "Connect with friends and share your journey.",
        "onboarding.social.you": "You",
        "onboarding.social.post1": "completed a workout",
        "onboarding.social.post2": "reached Level 10",
        "onboarding.social.post3": "started Movo",
        "onboarding.social.post4": "hit a PR",
        "onboarding.social.post5": "finished a challenge",
        "onboarding.social.time1": "2h ago",
        "onboarding.social.time2": "4h ago",
        "onboarding.social.time3": "Just now",
        "onboarding.social.time4": "5h ago",
        "onboarding.social.time5": "1d ago",
        
        // Onboarding - Reviews
        "onboarding.reviews.title": "Support a Solo Developer",
        "onboarding.reviews.subtitle": "Hi! Your feedback helps us make Movo better every day.",
        
        // Rest Timer
        "rest.pause": "Pause",
        "rest.minutes": "Minutes",
        "rest.seconds": "Seconds",
        "rest.start": "Start",
        "rest.resume": "Resume",
        "rest.reset": "Reset",
        "rest.cancel": "Cancel",
        "rest.done": "Done",
        
        // Home - Resume Training
        "home.resume.title": "Resume training?",
        "home.resume.discard": "Discard",
        "home.resume.continue": "Continue",
        
        // QR Code View
        "template.qr.scan": "Scan this code with your camera",
        "template.qr.step1": "Open the Camera app",
        "template.qr.step2": "Point your camera at the QR code",
        "template.qr.step3": "Tap 'Open in Movo'",
        "template.qr.share": "Share QR Code",
        "template.qr.sharetext": "Training Template",
        "template.qr.scaninstruction": "Scan this QR code with your camera to import the template in Movo.",
        "exercise": "Exercise",
        "exercises": "Exercises",
        
        "common.goal": "Goal",
        "common.category": "Category",
        "common.start": "Start",


        "statistics.empty.range": "No data in range.",
        "statistics.no.data": "No data available",
        "statistics.volume.per.day": "Volume per day",
        "statistics.pr.timeline": "PR timeline (est. 1RM)",
        "statistics.sets.distribution": "Sets distribution (reps)",
        "statistics.weight.distribution.format": "Weight distribution (%@)",
        "statistics.top.days.volume": "Top days (volume)",
        "statistics.sessions": "Sessions",
        "statistics.volume": "Volume",
        "statistics.avg.reps": "Avg reps",
        "statistics.best.set": "Best set",
        "statistics.est1rm": "Est. 1RM",

        // Home
        "home.title": "Your Training",
        "home.statsTitle": "Your Activity",
        "home.startTraining": "Start Training",
        "home.currentTraining": "Current Training",
        "home.defaultTrainingTitle": "Your Training",
        "home.today": "Today",
     
        
        // ➜ Add to LocalizedStrings.en
        "howto.header.subtitle"    : "Short & clear — technique, breathing, mistakes, and variations.",
        "howto.lottie.missing"     : "\"%@\" (.lottie/.json) not found.",
        "howto.lottie.advice"      : "Add “%@.lottie” or “%@.json” to the bundle, or provide a web URL.",

        "howto.section.setup"      : "Setup",
        "howto.section.execution"  : "Execution",
        "howto.section.breathing"  : "Breathing",
        "howto.section.mistakes"   : "Common mistakes",
        "howto.section.progressions": "Progressions/Variations",
        "howto.section.cues"       : "Coaching cues",
        "howto.section.note"       : "Note",

        "home.since": "Since",
        "home.continue": "Continue Training",
        "home.recentTrainings": "Recent Trainings",
        "home.recentTrainingsPlaceholder": "Your past training sessions will appear here.",
        "home.viewDetails": "View details",

        // Menu
        "menu.profile": "Show Profile",
        "menu.settings": "Settings",
        "menu.login": "Login",
        "menu.logout": "Logout",
        "training.discardMessage" : "Discard this workout? Your changes will be lost.",

        // Dashboard
        "dashboard.title": "Challenges",
        "dashboard.trainingUnits": "Training Units",

        // Week
        "week.title": "Week",
        "week.duration": "Duration",
        "week.calories": "Calories",
        "week.focus": "Focus",
        "week.equipment": "Equipment",
        "week.warmup": "Warm-up",
        "week.exercises": "Exercises",
        "week.cooldown": "Cool-down",
        "week.start": "Start",

        // Notifications
        "notifications.challengesTitle": "Your Challenges",
        "notifications.challengesBody": "Did you reach all your goals today? Check the app!",
        "notifications.workoutDone": "Workout done!",
        "notifications.workoutDoneBody": "Great! You finished a workout today 💪",
        "notifications.stepsDone": "Step goal reached!",
        "notifications.stepsDoneBody": "Awesome! You reached your step goal today 🚶‍♂️",

        
        
        

        "template.new": "New Template",
        "template.edit": "Edit Template",
        "template.section": "Template",
        "template.name.placeholder": "Enter name",
        "template.exercises": "Select Exercises",
        "template.search.placeholder": "Search exercise...",
        "template.cancel": "Cancel",
        "template.save": "Save Template",
        "template.save.changes": "Save Changes",

        // Settings
        "settings.title": "Settings",
        "settings.appearance": "Appearance",
        "settings.mode": "Mode",
        "settings.color": "Accent Color",
        "settings.general": "General",
        "settings.notifications": "Notifications",
        "settings.language": "Language",
        "settings.account": "Account",
        "settings.logout": "Logout",
        "settings.about": "About",
        "settings.version": "Version",
        "settings.done": "Done",
        "settings.units.metric": "Metric",
        "settings.units.imperial": "Imperial",
        "settings.goals.trainingDays": "Training days",
        "settings.goals.daysPerWeek": "%dx/week",

        // Training
        "training.title.placeholder": "Enter title …",
        "training.searchExercise": "Search exercise",
        "training.addExerciseNav": "Add Exercise",
        "training.cancel": "Cancel",
        "training.save": "Save",
        "training.completeAll": "Complete all",
        "training.resetAll": "Reset all",
        "training.addExercise": "Add exercise",
        "training.addSet": "Add set",
        "training.kg": "kg",
        "training.reps": "reps",
        "training.training": "Training",

        // Exercises
        "exercises.title": "Exercises",
        "exercises.search": "Search exercise...",
        "exercises.addNew": "Add new exercise",

        // Exercise Management
        "exerciseManagement.title": "Manage Exercises",
        "exerciseManagement.newExercise": "New Exercise",
        "exerciseManagement.add": "Add",

        // New Exercise
        "newExercise.title": "New Exercise",
        "newExercise.placeholder": "Enter new exercise",
        "newExercise.add": "Add",
        "newExercise.cancel": "Cancel",

        // Profile
        "profile.title": "Profile",
        "profile.close": "Close",
        "profile.guest": "Guest",
        "profile.level": "Level %d",
        "profile.xpProgress": "%d / %d XP until Level %d",
        "profile.xp": "XP",
        "profile.coins": "Coins",
        "profile.streak": "🔥 %d-Day Streak",
        "profile.streakHint": "Keep going to earn new badges!",
        "profile.badges": "Badges",

        
        // Paywall & Premium (EN)



        // Profile – Body metrics (new)
        "profile.metrics.title": "Body metrics",
        "profile.metrics.edit": "Edit body metrics",
        "profile.metrics.importHealth": "Import from Apple Health",
        "profile.metrics.weightKg": "Weight (kg)",
        "profile.metrics.heightCm": "Height (cm)",
        "profile.metrics.bodyFatPct": "Body fat (%)",
        "profile.metrics.restingHR": "Resting HR (bpm)",
        "profile.metrics.bmi": "BMI",
        "profile.metrics.healthImport.title": "Health Import",
        "profile.metrics.health.unavailable": "Health not available.",
        "profile.metrics.health.authFailed": "Health access failed",

        // Units
        "steps.today": "Today's steps",     // ⬅️ new for StepCounterView

        // Programmes
        "training.shred.title": "Shred & Sculpt",
        "training.shred.subtitle": "Strength & Fat Burn",
        "training.shred.duration": "6 Weeks",
        "training.shred.level": "Advanced",
        "training.fullbody.title": "Full Body Blast",
        "training.fullbody.subtitle": "Full Body Power",
        "training.fullbody.duration": "6 Weeks",
        "training.fullbody.level": "Intermediate",

        // History
        "history.title": "Training History",
        "history.search.placeholder": "Search training or date",
        "history.sort.help": "Sort (new/old)",
        "history.exercises": "exercises",
        "history.sets": "sets",

        // Details
        "details.title": "Details",
        "details.exercises": "Exercises",
        "details.sets": "Sets",
        "details.duration": "Duration",
        "details.weight": "Weight",
        "details.set": "Set",
        "details.reps": "Reps",
        
        // ---- Additions EN ----

        // Challenges
        "challenges.hint.longpress": "Long-press for details & options",

        // History
        "history.empty": "No workouts yet — start your first one!",


        // Statistics
        "statistics.title": "Statistics",
        "statistics.period": "Period",
        "statistics.period.week": "Week",
        "statistics.period.month": "Month",
        "statistics.period.year": "Year",
        "statistics.period.all": "All",
        "statistics.progress": "Progress",
        "statistics.date": "Date",
        "statistics.minutes": "Minutes",
        "statistics.trainings": "Workouts",
        "statistics.time": "Time",
        "statistics.total.weight": "Total Weight",
        "statistics.unlock.title": "Unlock Statistics",
        "statistics.unlock.subtitle": "Unlock detailed statistics with a one-time purchase of €14.99.",
        "statistics.unlock.button": "Buy once for €14.99",
        "statistics.max.weight": "Max Weight",
        "statistics.avg.weight": "Avg Weight",
        "statistics.weight.progress": "Weight Progress",
        "statistics.workouts.per.week": "Workouts per week",
        "statistics.top.exercises": "Top exercises (volume)",
        "statistics.exercise.stats": "Exercise statistics",
        "statistics.exercise.select": "Select exercise",
        "statistics.exercise": "Exercise",
        "statistics.best.training": "Best session",
        "statistics.exercise.none": "No exercises found for this period.",
        "statistics.duration.chart": "Duration per day",
        "home.templates": "Training Templates",
        
        "home.streak.title": "STREAK",
        "home.streak.days": "DAYS",
        "home.steps.title": "STEPS",
        
        "streak.unlocked.title": "You unlocked a streak!",
        "streak.weeks.label": "Week Streak",
        "streak.hint": "Log workouts to continue your streak!",
        "common.continue": "Continue",
        "profile.streakHeader": "Streak",


        "settings.cloudSync" : "Movo Cloud Sync",
        "settings.design.title" : "Design & Appearance",
        "settings.design.subtitle" : "Color scheme, cards, buttons, typography",
        "settings.units" : "Units",
        "settings.legal" : "Legal",

        "settings.legal.imprint.title" : "Imprint & Terms",
        "settings.legal.imprint.subtitle" : "Legal information",
        "settings.legal.privacy.title" : "Privacy",
        "settings.legal.privacy.subtitle" : "GDPR-compliant privacy policy",
        "settings.legal.consent.title" : "Manage consents",
        "settings.legal.consent.subtitle" : "Analytics, ads, crash reports",

        "settings.aboutApp.title" : "About the app",
        "settings.aboutApp.subtitle" : "What it does for you",
     
        "alert.logout.message" : "Do you really want to log out?",

        "statistics.musclemap.title" : "Trained areas",
        "statistics.musclemap.thisweek" : "This week",
        "statistics.musclemap.title.thisweek.format" : "%@ · %@",
        "statistics.musclemap.legend.trained" : "trained",

        
        
        "cloud.status.guest" : "Local mode (guest)",
        "cloud.status.active" : "Movo Cloud active",
        "cloud.subtitle.guest" : "Sign in to sync your data with the cloud.",
        "cloud.subtitle.active.last" : "Signed in: %@ • UID: %@ • Last sync: %@",
        "cloud.subtitle.active.waiting" : "Signed in: %@ • UID: %@ • Waiting for first sync …",
        "cloud.subtitle.noEmail" : "no email",

        "metrics.trainings" : "Workouts",
        "metrics.templates" : "Templates",
        "metrics.challenges" : "Challenges",
        "metrics.units" : "Units",

        "imprint.header.title" : "Legal",
        "imprint.header.subtitle" : "Imprint and Terms & Conditions.",
        "imprint.tab.impressum" : "Imprint",
        "imprint.tab.agb" : "Terms",
        "imprint.navTitle" : "Imprint & Terms",
        "imprint.contact" : "Contact",

        "privacy.header.title" : "Privacy",
        "privacy.header.subtitle" : "Transparency about data, purposes and rights (GDPR).",
        "privacy.title" : "Privacy policy",
        "privacy.quick" : "Quick access",
        "privacy.manageConsents" : "Manage consents",
        "privacy.contact" : "Privacy contact",

        "consent.title" : "Consents",
        "consent.subtitle" : "You decide how we use data for analytics & ads.",
        "consent.notice" : "You can withdraw your consents at any time with effect for the future. Without consent we only use strictly necessary processing.",
        "consent.analytics.title" : "Analytics (e.g. usage stats)",
        "consent.analytics.subtitle" : "Helps us improve the app. No personalized ads.",
        "consent.ads.title" : "Advertising (personalized ads)",
        "consent.ads.subtitle" : "May require sharing data with third parties.",
        "consent.crash.title" : "Crash reports",
        "consent.crash.subtitle" : "Diagnostics & stability (e.g. Crashlytics).",
        "consent.personal.title" : "Personalization",
        "consent.personal.subtitle" : "Tailored content & recommendations.",
        "consent.rejectAll" : "Reject all",
        "consent.acceptAll" : "Accept all",
        "consent.lastUpdated" : "Last updated: %@",
        
        // ➜ Ergänze in LocalizedStrings.en:
        "profile.edit"                : "Edit profile",
        "profile.edit.title"          : "Edit profile",
        "profile.photo.change"        : "Change profile picture",
        "profile.info.title"          : "Profile information",
        "profile.displayName"         : "Display name",
        "profile.username"            : "Username",
        "profile.aboutMe"             : "About me",
        "profile.info.note.title"     : "Note",
        "profile.info.note.text"      : "Your display name is public. The username is unique.",
        "profile.streak.title"        : "Streak",
        "iap.restore.started"         : "Restore started — hook up IAP manager later.",
        "settings.logout.confirm"     : "Do you really want to log out?",


        "about.title" : "About the app",
        "about.subtitle" : "Here’s what you get with %@",
        "about.card.benefits" : "What the app brings you",
        "about.benefit.plan.title" : "A weekly plan you can stick to",
        "about.benefit.plan.text" : "Clear structure from warm-up to cool-down. Your progress is saved automatically – step by step.",
        "about.benefit.challenges.title" : "Challenges & badges that motivate",
        "about.benefit.challenges.text" : "Tangible goals like workouts/week, steps, weekly volume & streaks. Bronze, silver, gold – and a ring that shows how close you are.",
        "about.benefit.rewards.title" : "Reward system with pull",
        "about.benefit.rewards.text" : "XP, coins and streaks after every workout. Visible level-ups make it easy to keep going.",
        "about.benefit.steps.title" : "Everyday movement counts automatically",
        "about.benefit.steps.text" : "Steps from Apple Health are imported. Weekly totals & goal status are visible right in the widget.",
        "about.benefit.achievements.title" : "Achievements you can see",
        "about.benefit.achievements.text" : "Pushes like “Workout done” and “Step goal reached”. Counters & rings make small wins feel big.",
        "about.benefit.templates.title" : "Your own templates in minutes",
        "about.benefit.templates.text" : "Name your routine, pick exercises, save – done. Personal training without fuss.",
        "about.support.title" : "Support",
        "about.support.email" : "Support via email",
        "badge.firstWorkout": "First Workout",
        "badge.streak7": "7-Day Streak",
        "badge.coinCollector": "Coin Collector",
        "badge.level5": "Reached Level 5",
        "gamification.title": "Your Progress",
        "gamification.badges.empty": "No badges unlocked yet",
        "steps.title": "Steps",
        "steps.kpi.today": "Today",
        "steps.kpi.avgPerDay": "Avg/day",
        "steps.kpi.best": "Best",
        "steps.kpi.goalDays": "Goal days",
        "steps.goal.title": "Goal",
        "steps.dailyGoal": "Daily goal",
        "steps.noDataRange": "No step data in range",
        "steps.noData": "No data",
        "steps.list.title": "Days",
        "steps.menu.csvShare": "Share CSV",
        "steps.menu.csvMake": "Generate CSV",
        "steps.menu.openHealth": "Open in Health",
        "common.ios16.required": "Requires iOS 16",
        "challenge.swap.title": "Swap challenge",
                "current": "current",
                "templates.search.placeholder": "Search templates…",
                "keep.progress": "Keep progress",
                "filter.currentTypeOnly": "Only current type",

                // Section titles
                "challenge.type.workouts": "Workouts",
                "challenge.type.steps": "Steps",
                "challenge.type.weeklyVolume": "Weekly volume",
                "challenge.type.streak": "Streak",
                "challenge.type.weeklySessions": "Active days",

                // Units
                "workouts.unit": "Workouts",
                "steps.unit": "Steps",
                "days.unit": "days",

        
        "paywall.cta.yearly.trial" : "Start 7-day free trial",
        "paywall.cta.yearly.subscribe" : "Subscribe yearly",
        "paywall.cta.monthly.subscribe" : "Subscribe monthly",
        "paywall.cta.lifetime.buy" : "Buy lifetime",
        "paywall.cta.beta.start" : "Start beta access",
                // Templates – Workouts
                "tpl.workouts.3.title": "3 workouts/week",
                "tpl.workouts.3.desc": "Solid starting point for consistency.",
                "tpl.workouts.5.title": "5 workouts per week",
                "tpl.workouts.5.desc": "Complete 5 workouts by Sunday.",
                "tpl.workouts.7.title": "7 workouts/week",
                "tpl.workouts.7.desc": "One workout every day.",
                "tpl.workouts.10in14.title": "10 workouts in 14 days",
                "tpl.workouts.10in14.desc": "Intense phase for a boost.",

                // Templates – Steps
                "tpl.steps.10k.title": "10,000 steps per day",
                "tpl.steps.10k.desc": "Stay active every day.",
                "tpl.steps.12k.title": "12,000 steps per day",
                "tpl.steps.12k.desc": "Noticeably more daily movement.",
                "tpl.steps.15k.title": "15,000 steps per day",
                "tpl.steps.15k.desc": "Ambitious step goal.",

                // Templates – Weekly Volume
                "tpl.volume.5k.title": "5,000 kg/week",
                "tpl.volume.5k.desc": "Total weight moved per week.",
                "tpl.volume.10k.title": "10,000 kg/week",
                "tpl.volume.10k.desc": "Ambitious training volume.",

        
        "paywall.plan.lifetime.title" : "Lifetime (one-time)",

                // Templates – Streak
                "tpl.streak.3.title": "3-day streak",
                "tpl.streak.3.desc": "Train 3 days in a row.",
                "tpl.streak.5.title": "5-day streak",
                "tpl.streak.5.desc": "Train 5 days in a row.",

        
          "startMenu.title" : "Start new workout",
          "startMenu.strength.title" : "Strength training",
          "startMenu.strength.subtitle" : "Sets, weights & rest",
          "startMenu.running.title" : "Running",
          "startMenu.running.subtitle" : "Track distance & duration",
          "startMenu.manual.title" : "Enter manually",
          "startMenu.manual.subtitle" : "Add a past training",
        "startMenu.cancel" : "Cancel",
        

                // Templates – Active Days
                "tpl.days.3.title": "3 active days/week",
                "tpl.days.3.desc": "Train on 3 different days.",
                "tpl.days.5.title": "5 active days/week",
                "tpl.days.5.desc": "Train on 5 different days.",
        
        // Settings - Account
        "settings.account.changePassword": "Change password",
        "settings.account.resetPassword": "Reset password",
        "settings.account.delete": "Delete account",
        "settings.account.delete.confirm": "Delete permanently",
        "settings.account.delete.warning": "This action cannot be undone. All your data will be permanently deleted.",
        "settings.account.currentPassword": "Current password",
        "settings.account.newPassword": "New password",
        "settings.account.confirmPassword": "Confirm password",
        "settings.account.passwordMismatch": "Passwords do not match",
        "settings.account.email": "Email",
        "settings.account.resetPassword.info": "Enter your email address to receive a password reset link.",
        "settings.account.sendResetLink": "Send link",
        "settings.account.resetPassword.sent": "A reset link has been sent to your email.",
        
        // Settings - Legal
        "settings.legal.privacy": "Privacy Policy",
        "settings.legal.imprint": "Imprint",
        "settings.legal.terms": "Terms of Use",
        "settings.legal.support": "Support",
        
        // Settings - Support
        "settings.support.title": "Contact Support",
        "settings.support.subtitle": "Send us an email and we'll be happy to help.",
        "settings.support.sendEmail": "Send email",
        
        // Common
        "common.success": "Success",
        "common.error": "Error",
        "common.ok": "OK",
        "common.close": "Close",
        "Friends": "Friends",
        "Requests": "Requests",
        "Search": "Search",
        "Incoming": "Incoming",
        "Outgoing": "Sent",
        "Suggested": "Suggested",
        "profile.friends.add": "Add friends",
        "friends.empty.title": "No friends yet",
        "friends.empty.message": "Add friends via search.",
        
        // Profile Stats
        "profile.stats.time": "Time",
        "profile.stats.workouts": "Workouts",
        "profile.weekOverview": "Week Overview",
        "profile.levelProgress": "Level Progress",
        
        "common.cancel": "Cancel"

    ]
}
