import Foundation
import SwiftUI

/// Energía del cuerpo (0–100) a lo largo del día: se carga mientras duermes (más cuanto mejor te recuperas)
/// y se gasta con los pasos y con el pulso por encima de tu pulso en reposo.
/// Es una estimación propia, no una medida médica.
@MainActor
enum EnergyEngine {
    struct Day {
        var points: [TimePoint]
        var now: Double
        var wake: Date?
        var peak: Double
    }

    static func today(_ store: HealthStore) -> Day? {
        store.remember("energia") { compute(store) }
    }

    private static func compute(_ store: HealthStore) -> Day? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let hr = Dictionary(store.heartToday.map { (cal.component(.hour, from: $0.date), $0.value) }, uniquingKeysWith: { a, _ in a })
        let steps = Dictionary(store.stepsToday.map { (cal.component(.hour, from: $0.date), $0.value) }, uniquingKeysWith: { a, _ in a })
        guard !hr.isEmpty || !steps.isEmpty else { return nil }
        let rhr = store.baseline(.restingHR)?.median ?? store.latest(.restingHR)?.value ?? 60
        let recovery = Double(ScoreEngine.report(store).recovery?.value ?? 60)
        let night = store.lastNight.flatMap { $0.end > start ? $0 : nil }
        let wake = night?.end ?? cal.date(byAdding: .hour, value: 7, to: start)!
        let sleepFrom = night.map { max($0.start, start) } ?? start
        let peak = min(100, 40 + 0.6 * recovery)
        var level = 22.0
        var out: [TimePoint] = []
        let nowHour = cal.component(.hour, from: .now)
        for h in 0...nowHour {
            let t = cal.date(byAdding: .hour, value: h, to: start)!
            let tEnd = cal.date(byAdding: .hour, value: 1, to: t)!
            out.append(TimePoint(date: t, value: level))
            if tEnd <= sleepFrom {
                level = max(8, level - 1.5)
            } else if t < wake {
                // Se carga durmiendo, más deprisa al principio.
                let left = max(1, wake.timeIntervalSince(max(t, sleepFrom)) / 3600)
                level += (peak - level) / left * 1.1
                level = min(level, peak)
            } else {
                let s = steps[h] ?? 0
                let pulse = hr[h] ?? rhr + 12
                let drain = 1.6 + s / 450 + max(0, pulse - rhr - 15) * 0.2
                level = max(4, level - drain)
            }
        }
        let now = Date.now
        out.append(TimePoint(date: now, value: level))
        return Day(points: out, now: level, wake: night?.end, peak: peak)
    }

    static func sentence(_ v: Double) -> String {
        if v >= 70 { return "Tienes energía de sobra: buen momento para entrenar fuerte o para lo que más te cueste." }
        if v >= 45 { return "Te queda energía para un entreno moderado o una tarde activa." }
        if v >= 25 { return "Vas justo de energía: algo suave y no te acuestes tarde." }
        return "Batería baja: descansa y prioriza dormir bien esta noche."
    }

    /// Estrés de cada hora: pulso alto para lo poco que te estás moviendo (0 nada, 3 alto).
    struct StressHour: Identifiable {
        var date: Date
        /// -1 durmiendo, 0 tranquilo, 1 algo, 2 medio, 3 alto
        var level: Int
        var id: Date { date }
    }

    static func stress(_ store: HealthStore) -> [StressHour] {
        store.remember("estres") {
            let cal = Calendar.current
            let rhr = store.baseline(.restingHR)?.median ?? 60
            let steps = Dictionary(store.stepsToday.map { (cal.component(.hour, from: $0.date), $0.value) }, uniquingKeysWith: { a, _ in a })
            let night = store.lastNight
            return store.heartToday.compactMap { p -> StressHour? in
                guard p.value > 0 else { return nil }
                if let n = night, p.date >= n.start.addingTimeInterval(-1800), p.date < n.end { return StressHour(date: p.date, level: -1) }
                let h = cal.component(.hour, from: p.date)
                // Si te mueves, el pulso alto es ejercicio, no estrés.
                if (steps[h] ?? 0) > 900 { return StressHour(date: p.date, level: 0) }
                let over = p.value - rhr
                return StressHour(date: p.date, level: over > 30 ? 3 : over > 20 ? 2 : over > 12 ? 1 : 0)
            }
        }
    }
}

/// Lo que te conviene hacer hoy: esfuerzo, pasos y a qué hora acostarte.
@MainActor
enum DayPlan {
    struct Goal: Identifiable {
        var id: String
        var title: String
        var symbol: String
        var color: Color
        var progress: Double
        var value: String
        var detail: String
        var done: Bool
    }

    static func goals(_ store: HealthStore) -> [Goal] {
        let report = ScoreEngine.report(store)
        var out: [Goal] = []
        if let r = report.recovery?.value {
            let range: ClosedRange<Int> = r >= 67 ? 60...85 : r >= 40 ? 40...60 : 15...35
            let e = report.effort?.value ?? 0
            let detail: String
            if e < range.lowerBound { detail = "Objetivo \(range.lowerBound)–\(range.upperBound): te faltan \(range.lowerBound - e) puntos" }
            else if e <= range.upperBound { detail = "Objetivo \(range.lowerBound)–\(range.upperBound): en tu zona" }
            else { detail = "Objetivo \(range.lowerBound)–\(range.upperBound): te has pasado, descansa" }
            out.append(Goal(id: "esfuerzo", title: "Esfuerzo", symbol: "flame.fill", color: Palette.effort,
                            progress: min(1, Double(e) / Double(range.lowerBound)), value: "\(e)", detail: detail,
                            done: range.contains(e)))
        }
        if store.has(.steps) {
            let usual = store.baseline(.steps)?.median ?? 7000
            let goal = max(6000, (usual / 500).rounded() * 500)
            let now = store.value(.steps, on: store.today) ?? 0
            let left = max(0, goal - now)
            out.append(Goal(id: "pasos", title: "Pasos", symbol: "figure.walk", color: Palette.effort,
                            progress: min(1, now / goal), value: Fmt.number(now),
                            detail: left > 0 ? "Objetivo \(Fmt.number(goal)): te faltan \(Fmt.number(left))" : "Objetivo \(Fmt.number(goal)) cumplido",
                            done: left == 0))
        }
        if let bed = bedtime(store) {
            out.append(Goal(id: "dormir", title: "Acostarte", symbol: "bed.double.fill", color: Palette.sleep,
                            progress: 0, value: bed.time, detail: bed.detail, done: false))
        }
        return out
    }

    /// Hora para acostarse: la de siempre, antes si anoche dormiste menos de lo que necesitas.
    static func bedtime(_ store: HealthStore) -> (time: String, detail: String)? {
        let nights = store.recentNights(14)
        guard nights.count >= 3 else { return nil }
        let beds = nights.map { ScoreEngine.minutesFromMidnight($0.start) }.sorted()
        let wakes = nights.map { ScoreEngine.minutesFromMidnight($0.end) }.sorted()
        let usualWake = wakes[wakes.count / 2]
        let need = max(7 * 60, min(9 * 60, (store.baseline(.sleep)?.median ?? 7.5 * 3600) / 60))
        let debt = store.lastNight.map { max(0, need - $0.asleep / 60) } ?? 0
        let target = min(beds[beds.count / 2], usualWake - need - 15 - min(45, debt / 2))
        let sleepFor = Fmt.duration((usualWake - target - 15) * 60)
        return (ScoreEngine.clock(fromMinutes: target), "Para dormir \(sleepFor) y levantarte a las \(ScoreEngine.clock(fromMinutes: usualWake))")
    }
}

/// Carga de entreno: la última semana frente a las cuatro anteriores (relación aguda/crónica).
@MainActor
enum TrainingLoad {
    struct Load {
        var ratio: Double
        var acute: Double
        var chronic: Double
    }

    static func compute(_ store: HealthStore) -> Load? {
        store.remember("carga") {
            let cal = Calendar.current
            let vals = store.values[.activeEnergy] ?? [:]
            let today = store.today
            func avg(_ from: Int, _ to: Int) -> Double? {
                let days = (from...to).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }.compactMap { vals[$0] }.filter { $0 > 0 }
                return days.count >= max(3, (to - from + 1) / 2) ? days.reduce(0, +) / Double(days.count) : nil
            }
            guard let a = avg(1, 7), let c = avg(1, 28), c > 0 else { return nil }
            return Load(ratio: a / c, acute: a, chronic: c)
        }
    }

    enum Zone { case low, optimal, high, risk }

    static func zone(_ r: Double) -> Zone { r < 0.8 ? .low : r <= 1.3 ? .optimal : r <= 1.5 ? .high : .risk }

    static func title(_ z: Zone) -> String {
        switch z {
        case .low: "Pierdes forma"
        case .optimal: "Zona óptima"
        case .high: "Carga alta"
        case .risk: "Riesgo de lesión"
        }
    }

    static func color(_ z: Zone) -> Color {
        switch z {
        case .low: Palette.breath
        case .optimal: Palette.recovery
        case .high: Palette.effort
        case .risk: Palette.heart
        }
    }

    static func sentence(_ l: Load) -> String {
        let pct = Int((abs(l.ratio - 1) * 100).rounded())
        switch zone(l.ratio) {
        case .low: return "Esta semana te mueves un \(pct) % menos que tu media del mes. Si sigue así, perderás forma poco a poco."
        case .optimal: return "Tu carga de esta semana va acorde con tu mes: ganas forma sin pasarte."
        case .high: return "Esta semana cargas un \(pct) % más que tu media del mes. Bien para progresar, pero mete un día suave."
        case .risk: return "Has subido la carga un \(pct) % de golpe. Es cuando más lesiones hay: baja un poco el ritmo unos días."
        }
    }
}
