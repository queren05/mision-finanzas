import Foundation
import SwiftUI

/// Una puntuación de 0 a 100 con su frase.
struct Score: Identifiable {
    enum Kind: String { case recovery, sleep, effort }
    var kind: Kind
    var value: Int
    var sentence: String
    var id: Kind { kind }

    var title: String {
        switch kind {
        case .recovery: "Recuperación"
        case .sleep: "Sueño"
        case .effort: "Esfuerzo"
        }
    }

    var color: Color {
        switch kind {
        case .recovery: Palette.recovery
        case .sleep: Palette.sleep
        case .effort: Palette.effort
        }
    }

    var symbol: String {
        switch kind {
        case .recovery: "heart.circle.fill"
        case .sleep: "moon.stars.fill"
        case .effort: "flame.circle.fill"
        }
    }
}

/// Las tres puntuaciones del día, el resumen y el color de fondo.
struct DayReport {
    var recovery: Score?
    var sleep: Score?
    var effort: Score?
    var summary: String
    var mood: Mood
    /// El consejo del día (la frase de recomendación del resumen).
    var advice: String?

    var scores: [Score] { [recovery, sleep, effort].compactMap { $0 } }
}

@MainActor
enum ScoreEngine {
    /// De «desviaciones» a 0…1: lo normal da 0,6; dos desviaciones a favor, 1.
    private static func part(_ z: Double) -> Double { min(1, max(0, 0.6 + 0.2 * z)) }

    // MARK: Sueño

    static func sleep(_ night: SleepNight, store: HealthStore) -> (Int, [String: Double]) {
        let base = store.baseline(.sleep, before: night.day)
        let need = max(7 * 3600, min(9 * 3600, base?.median ?? 7.5 * 3600))
        // Cada hora que falta resta la mitad de esta parte.
        let duration = min(1, max(0, 1 - (need - night.asleep) / 7200))
        let efficiency = min(1, max(0, (night.efficiency - 0.75) / 0.2))
        let restorative = night.hasStages ? min(1, (night.time(.deep) + night.time(.rem)) / max(1, night.asleep) / 0.4) : 0.8
        let regularity = 1 - min(1, abs(bedtimeShift(night, store: store)) / 90)
        let total = 0.55 * duration + 0.15 * efficiency + 0.15 * restorative + 0.15 * regularity
        return (Int((total * 100).rounded()), ["duracion": duration, "eficiencia": efficiency, "reparador": restorative, "regularidad": regularity])
    }

    /// Minutos que te acostaste antes (negativo) o después (positivo) de tu hora habitual.
    static func bedtimeShift(_ night: SleepNight, store: HealthStore) -> Double {
        let previous = store.recentNights(15).filter { $0.day < night.day }
        guard previous.count >= 3 else { return 0 }
        let usual = previous.map { minutesFromMidnight($0.start) }.sorted()[previous.count / 2]
        return minutesFromMidnight(night.start) - usual
    }

    /// Minutos desde la medianoche, con la tarde en negativo (23:30 = -30).
    static func minutesFromMidnight(_ d: Date) -> Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        let m = Double((c.hour ?? 0) * 60 + (c.minute ?? 0))
        return m > 15 * 60 ? m - 24 * 60 : m
    }

    static func clock(fromMinutes m: Double) -> String {
        var x = Int(m.rounded())
        if x < 0 { x += 24 * 60 }
        return "\(x / 60):\(String(format: "%02d", x % 60))"
    }

    // MARK: Informe del día

    static func report(_ store: HealthStore) -> DayReport {
        store.remember("report") { computeReport(store) }
    }

    /// El informe de cualquier día (hoy, el de siempre).
    static func report(_ store: HealthStore, day: Date) -> DayReport {
        let d = store.dayStart(day)
        if d >= store.today { return report(store) }
        return store.remember("report|\(Int(d.timeIntervalSince1970))") { computePast(store, day: d) }
    }

    /// Esfuerzo de un día: energía activa y ejercicio frente a lo normal en ti, y el pulso de cada hora
    /// (para que cuente también el trabajo físico, que sube el pulso sin sumar pasos).
    static func effort(_ store: HealthStore, day: Date) -> Score? {
        let d = store.dayStart(day)
        guard let e = store.value(.activeEnergy, on: d) ?? (store.has(.activeEnergy) ? 0 : nil) else { return nil }
        let eb = store.baseline(.activeEnergy, before: d)?.median ?? 450
        let ex = store.value(.exerciseMinutes, on: d) ?? 0
        let xb = max(10, store.baseline(.exerciseMinutes, before: d)?.median ?? 30)
        let raw = 0.6 * e / max(eb, 50) + 0.4 * ex / xb
        var value = Int((100 * (1 - exp(-1.1 * raw))).rounded())
        var byHeart = false
        if let h = HeartLoad.score(store, day: d) {
            let mixed = Int((0.5 * Double(value) + 0.5 * Double(h)).rounded())
            if mixed > value { value = mixed; byHeart = true }
        }
        var sentence = effortSentence(value, energy: e, exercise: ex, store: store)
        if byHeart {
            let level = value >= 75 ? "alto" : value >= 45 ? "moderado" : "bajo"
            sentence = WorkSchedule.current.isWorkDay(d)
                ? "Esfuerzo \(level): \(Fmt.full(.activeEnergy, e)) activas y el pulso alto de tu jornada."
                : "Esfuerzo \(level): \(Fmt.full(.activeEnergy, e)) activas y muchas horas con el pulso alto."
        }
        return Score(kind: .effort, value: value, sentence: sentence)
    }

    private static func computePast(_ store: HealthStore, day: Date) -> DayReport {
        var sleepScore: Score?
        var sleepParts: [String: Double] = [:]
        let night = store.nights[day]
        if let night {
            let (v, p) = sleep(night, store: store)
            sleepParts = p
            sleepScore = Score(kind: .sleep, value: v, sentence: sleepSentence(v, night: night, parts: p, store: store))
        }
        var weighted: [(Double, Double, String)] = []
        if let hrv = store.value(.hrv, on: day), let b = store.baseline(.hrv, before: day) {
            weighted.append((0.4, part(b.z(hrv)), "la variabilidad estaba baja"))
        }
        if let rhr = store.value(.restingHR, on: day), let b = store.baseline(.restingHR, before: day) {
            weighted.append((0.3, part(-b.z(rhr)), "el pulso en reposo estaba alto"))
        }
        if let s = sleepScore { weighted.append((0.3, Double(s.value) / 100, "dormiste poco")) }
        var recovery: Score?
        if weighted.count >= 2 {
            let w = weighted.reduce(0) { $0 + $1.0 }
            let value = Int(min(100, max(0, weighted.reduce(0) { $0 + $1.0 * $1.1 } / w * 100)).rounded())
            let worst = weighted.min { $0.1 < $1.1 }!
            let text = value >= 67 ? "Ese día estabas recuperado." : value >= 40 ? "Recuperación a medias: \(worst.2)." : "Tu cuerpo aún se estaba recuperando: \(worst.2)."
            recovery = Score(kind: .recovery, value: value, sentence: text)
        }
        let eff = effort(store, day: day)
        var parts: [String] = []
        if let night { parts.append("Dormiste \(Fmt.duration(night.asleep)).") }
        if let r = recovery { parts.append(r.sentence) }
        if let e = eff { parts.append(e.sentence) }
        _ = sleepParts
        let mood: Mood = recovery.map { $0.value >= 67 ? .recovered : $0.value >= 40 ? .steady : .easy } ?? .neutral
        return DayReport(recovery: recovery, sleep: sleepScore, effort: eff,
                         summary: parts.isEmpty ? "No hay datos de este día." : parts.prefix(3).joined(separator: " "),
                         mood: mood, advice: nil)
    }

    private static func computeReport(_ store: HealthStore) -> DayReport {
        let night = store.lastNight
        var sleepScore: Score?
        var sleepParts: [String: Double] = [:]
        if let night {
            let (v, p) = sleep(night, store: store)
            sleepParts = p
            sleepScore = Score(kind: .sleep, value: v, sentence: sleepSentence(v, night: night, parts: p, store: store))
        }

        // Recuperación: variabilidad, pulso en reposo y sueño.
        var weighted: [(Double, Double, String)] = []   // (peso, 0…1, motivo si va mal)
        if let hrv = Explainer.insight(.hrv, store: store), let b = hrv.baseline {
            weighted.append((0.4, part(b.z(hrv.value)), "la variabilidad está baja"))
        }
        if let rhr = Explainer.insight(.restingHR, store: store), let b = rhr.baseline {
            weighted.append((0.3, part(-b.z(rhr.value)), "el pulso en reposo está alto"))
        }
        if let s = sleepScore { weighted.append((0.3, Double(s.value) / 100, "dormiste poco")) }
        var recovery: Score?
        if weighted.count >= 2 {
            let w = weighted.reduce(0) { $0 + $1.0 }
            var v = weighted.reduce(0) { $0 + $1.0 * $1.1 } / w * 100
            if let rr = Explainer.insight(.respiratoryRate, store: store), let b = rr.baseline, b.z(rr.value) > 2 { v -= 8 }
            let value = Int(min(100, max(0, v)).rounded())
            let worst = weighted.min { $0.1 < $1.1 }!
            recovery = Score(kind: .recovery, value: value, sentence: recoverySentence(value, reason: worst.2))
        }

        let effort = Self.effort(store, day: store.today)

        let mood: Mood = {
            let h = Calendar.current.component(.hour, from: .now)
            if h >= 21 || h < 5 { return .night }
            guard let r = recovery?.value else { return .neutral }
            return r >= 67 ? .recovered : r >= 40 ? .steady : .easy
        }()

        return DayReport(recovery: recovery, sleep: sleepScore, effort: effort,
                         summary: summary(night: night, recovery: recovery, effort: effort, store: store), mood: mood,
                         advice: advice(recovery: recovery?.value, store: store))
    }

    // MARK: Frases de las puntuaciones

    private static func sleepSentence(_ v: Int, night: SleepNight, parts: [String: Double], store: HealthStore) -> String {
        let d = Fmt.duration(night.asleep)
        let deep = night.hasStages ? Fmt.duration(night.time(.deep)) : nil
        let worst = parts.min { $0.value < $1.value }?.key
        if v >= 80 && (parts["duracion"] ?? 0) >= 0.9 {
            return deep.map { "Noche de calidad: \(d), con \($0) de sueño profundo." } ?? "Noche de calidad: \(d) bien aprovechadas."
        }
        switch worst {
        case "duracion": return "Dormiste \(d): menos de lo que tu cuerpo suele necesitar."
        case "eficiencia": return "Dormiste \(d), pero con bastantes ratos despierto."
        case "reparador": return "Dormiste \(d), con poco sueño profundo y REM."
        case "regularidad": return "Dormiste \(d), pero te acostaste a una hora distinta de la habitual."
        default: return "Dormiste \(d)."
        }
    }

    private static func recoverySentence(_ v: Int, reason: String) -> String {
        if v >= 67 { return "Tu cuerpo está recuperado: corazón tranquilo y buena variabilidad." }
        if v >= 40 { return "Recuperación a medias: \(reason)." }
        return "Tu cuerpo aún se está recuperando: \(reason)."
    }

    private static func effortSentence(_ v: Int, energy: Double, exercise: Double, store: HealthStore) -> String {
        let level = v >= 75 ? "alto" : v >= 45 ? "moderado" : "bajo"
        return "Esfuerzo \(level) para ti: \(Fmt.full(.activeEnergy, energy)) activas y \(Fmt.number(exercise)) min de ejercicio."
    }

    // MARK: Resumen de arriba (2-3 frases)

    /// Usual hora de acostarse (mediana de las dos últimas semanas).
    static func usualBedtime(_ store: HealthStore) -> String? {
        let usual = store.recentNights(14).map { minutesFromMidnight($0.start) }.sorted()
        return usual.isEmpty ? nil : clock(fromMinutes: usual[usual.count / 2])
    }

    /// Qué te conviene hoy (o, por la noche, a qué hora acostarte).
    static func advice(recovery: Int?, store: HealthStore) -> String? {
        let day = store.today
        let h = Calendar.current.component(.hour, from: .now)
        guard let r = recovery else { return nil }
        if h >= 21 {
            return usualBedtime(store).map { "Para mañana, intenta acostarte sobre las \($0)." }
        }
        if r >= 67 {
            return Explainer.pick(["Estás recuperado: buen día para apretar si te apetece.", "Tu cuerpo está listo para un buen entreno."], "sum-r", day)
        }
        if r >= 40 {
            return Explainer.pick(["Hoy, a tu ritmo: muévete sin pasarte.", "Día normal: entrena suave o moderado."], "sum-m", day)
        }
        return Explainer.pick(["Hoy mejor un día suave.", "Tu cuerpo pide descanso: paseo y a dormir pronto."], "sum-e", day)
    }

    private static func summary(night: SleepNight?, recovery: Score?, effort: Score?, store: HealthStore) -> String {
        var parts: [String] = []
        let day = store.today
        if let night {
            let d = Fmt.duration(night.asleep)
            if let b = store.baseline(.sleep, before: night.day) {
                let z = b.z(night.asleep)
                if z < -1 { parts.append("Dormiste \(d), \(Explainer.much(z)) menos que tu media.") }
                else if z > 1 { parts.append("Dormiste \(d), \(Explainer.much(z)) más que tu media.") }
                else { parts.append(Explainer.pick(["Dormiste \(d), lo normal para ti.", "Anoche dormiste \(d), en tu media."], "sum-s", day)) }
            } else {
                parts.append("Dormiste \(d).")
            }
        }
        let h = Calendar.current.component(.hour, from: .now)
        if let a = advice(recovery: recovery?.value, store: store) { parts.append(a) }
        if let e = effort?.value, e >= 80, h >= 12 {
            parts.append("Ya llevas un esfuerzo alto para ti.")
        }
        if parts.isEmpty { return "Cuando el reloj tenga datos de unos días, aquí verás un resumen de cómo estás." }
        return parts.prefix(3).joined(separator: " ")
    }
}
