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
        let duration = min(1, night.asleep / need)
        let efficiency = min(1, max(0, (night.efficiency - 0.75) / 0.2))
        let restorative = night.hasStages ? min(1, (night.time(.deep) + night.time(.rem)) / max(1, night.asleep) / 0.4) : 0.8
        let regularity = 1 - min(1, abs(bedtimeShift(night, store: store)) / 90)
        let total = 0.5 * duration + 0.15 * efficiency + 0.15 * restorative + 0.2 * regularity
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

        // Esfuerzo: energía activa y ejercicio de hoy frente a lo normal en ti.
        var effort: Score?
        if let e = store.value(.activeEnergy, on: store.today) ?? (store.has(.activeEnergy) ? 0 : nil) {
            let eb = store.baseline(.activeEnergy)?.median ?? 450
            let ex = store.value(.exerciseMinutes, on: store.today) ?? 0
            let xb = max(10, store.baseline(.exerciseMinutes)?.median ?? 30)
            let raw = 0.6 * e / max(eb, 50) + 0.4 * ex / xb
            let value = Int((100 * (1 - exp(-1.1 * raw))).rounded())
            effort = Score(kind: .effort, value: value, sentence: effortSentence(value, energy: e, exercise: ex, store: store))
        }

        let mood: Mood = {
            let h = Calendar.current.component(.hour, from: .now)
            if h >= 21 || h < 5 { return .night }
            guard let r = recovery?.value else { return .neutral }
            return r >= 67 ? .recovered : r >= 40 ? .steady : .easy
        }()

        return DayReport(recovery: recovery, sleep: sleepScore, effort: effort,
                         summary: summary(night: night, recovery: recovery, effort: effort, store: store), mood: mood)
    }

    // MARK: Frases de las puntuaciones

    private static func sleepSentence(_ v: Int, night: SleepNight, parts: [String: Double], store: HealthStore) -> String {
        let d = Fmt.duration(night.asleep)
        let deep = night.hasStages ? Fmt.duration(night.time(.deep)) : nil
        let worst = parts.min { $0.value < $1.value }?.key
        if v >= 80 {
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
        if let r = recovery?.value {
            if h >= 21 {
                let usual = store.recentNights(14).map { minutesFromMidnight($0.start) }.sorted()
                if !usual.isEmpty {
                    parts.append("Para mañana, intenta acostarte sobre las \(clock(fromMinutes: usual[usual.count / 2])).")
                }
            } else if r >= 67 {
                parts.append(Explainer.pick(["Estás recuperado: buen día para apretar si te apetece.", "Tu cuerpo está listo para un buen entreno."], "sum-r", day))
            } else if r >= 40 {
                parts.append(Explainer.pick(["Hoy, a tu ritmo: muévete sin pasarte.", "Día normal: entrena suave o moderado."], "sum-m", day))
            } else {
                parts.append(Explainer.pick(["Hoy mejor un día suave.", "Tu cuerpo pide descanso: paseo y a dormir pronto."], "sum-e", day))
            }
        }
        if let e = effort?.value, e >= 80, h >= 12 {
            parts.append("Ya llevas un esfuerzo alto para ti.")
        }
        if parts.isEmpty { return "Cuando el reloj tenga datos de unos días, aquí verás un resumen de cómo estás." }
        return parts.prefix(3).joined(separator: " ")
    }
}
