import Foundation
import SwiftUI

// MARK: - Trabajo

/// Qué tipo de trabajo tienes: con uno físico, el pulso alto en la jornada es esfuerzo, no estrés.
enum JobKind: String, CaseIterable, Identifiable {
    case none, standing, physical
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "Sentado o no lo cuento"
        case .standing: "De pie, moviéndome"
        case .physical: "Físico, cargando peso"
        }
    }
    var short: String {
        switch self {
        case .none: "No"
        case .standing: "De pie"
        case .physical: "Cargo peso"
        }
    }
    var symbol: String {
        switch self {
        case .none: "chair.fill"
        case .standing: "figure.walk"
        case .physical: "shippingbox.fill"
        }
    }
}

/// Tu jornada: tipo de trabajo, días y horas.
struct WorkSchedule {
    var kind: JobKind
    /// Días de la semana (1 domingo … 7 sábado).
    var days: Set<Int>
    var from: Int
    var to: Int

    static let kindKey = "trabajoTipo", daysKey = "trabajoDias", fromKey = "trabajoDesde", toKey = "trabajoHasta", askedKey = "trabajoPreguntado"

    static var current: WorkSchedule {
        let d = UserDefaults.standard
        if Launch.demo { return WorkSchedule(kind: .physical, days: [2, 3, 4, 5, 6], from: 7, to: 15) }
        let kind = JobKind(rawValue: d.string(forKey: kindKey) ?? "") ?? .none
        let days = Set((d.string(forKey: daysKey) ?? "23456").compactMap { Int(String($0)) })
        let from = d.object(forKey: fromKey) as? Int ?? 7
        let to = d.object(forKey: toKey) as? Int ?? 15
        return WorkSchedule(kind: kind, days: days, from: from, to: max(from + 1, to))
    }

    var active: Bool { kind != .none }

    func isWorkDay(_ d: Date) -> Bool { active && days.contains(Calendar.current.component(.weekday, from: d)) }

    func isWorkHour(_ d: Date) -> Bool {
        guard isWorkDay(d) else { return false }
        let h = Calendar.current.component(.hour, from: d)
        return h >= from && h < to
    }

    var hoursText: String { "\(from):00–\(to):00" }
}

// MARK: - Días

extension HealthStore {
    func dayStart(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }
    func isToday(_ d: Date) -> Bool { dayStart(d) >= today }

    /// La noche que termina ese día.
    func night(for day: Date) -> SleepNight? {
        isToday(day) ? lastNight.flatMap { $0.end > today ? $0 : nil } : nights[dayStart(day)]
    }

    func dayHours(_ day: Date) -> DayHours { hours[dayStart(day)] ?? DayHours() }

    /// Pulso en reposo de referencia para ese día.
    func restingHR(for day: Date) -> Double {
        baseline(.restingHR, before: dayStart(day))?.median ?? value(.restingHR, on: day) ?? latest(.restingHR)?.value ?? 60
    }
}

// MARK: - Carga del corazón

/// Esfuerzo medido con el pulso de cada hora (cuenta aunque no camines: cargar cajas también sube el pulso).
@MainActor
enum HeartLoad {
    static func maxHR(_ store: HealthStore) -> Double { 208 - 0.7 * (BioAge.realAge(store) ?? 35) }

    /// Puntos de carga del día (o solo de la jornada).
    static func points(_ store: HealthStore, day: Date, onlyWork: Bool = false) -> Double? {
        let d = store.dayStart(day)
        return store.remember("carga-pulso|\(Int(d.timeIntervalSince1970))|\(onlyWork)") {
            let hr = store.dayHours(d).hr.filter { $0.value > 0 }
            guard hr.count >= 4 else { return nil }
            let rhr = store.restingHR(for: d)
            let top = max(rhr + 40, maxHR(store))
            let night = store.night(for: d)
            let work = WorkSchedule.current
            var sum = 0.0
            for p in hr {
                if let n = night, p.date >= n.start.addingTimeInterval(-1800), p.date < n.end { continue }
                if onlyWork && !work.isWorkHour(p.date) { continue }
                let r = max(0, (p.value - rhr - 10) / (top - rhr))
                sum += r * r * 60
            }
            return sum
        }
    }

    /// De 0 a 100.
    static func score(_ store: HealthStore, day: Date) -> Int? {
        points(store, day: day).map { Int((100 * (1 - exp(-$0 / 50))).rounded()) }
    }

    static func level(_ p: Double) -> (String, Color) {
        p >= 35 ? ("Alta", Palette.heart) : p >= 15 ? ("Media", Palette.effort) : ("Baja", Palette.good)
    }
}

// MARK: - Estrés

@MainActor
enum StressEngine {
    struct Hour: Identifiable {
        var date: Date
        /// -2 trabajando, -1 durmiendo, 0 tranquilo, 1 algo, 2 medio, 3 alto
        var level: Int
        var id: Date { date }
    }

    static func hours(_ store: HealthStore, day: Date) -> [Hour] {
        let d = store.dayStart(day)
        return store.remember("estres|\(Int(d.timeIntervalSince1970))") {
            let cal = Calendar.current
            let rhr = store.restingHR(for: d)
            let h = store.dayHours(d)
            let steps = Dictionary(h.steps.map { (cal.component(.hour, from: $0.date), $0.value) }, uniquingKeysWith: { a, _ in a })
            let night = store.night(for: d)
            let work = WorkSchedule.current
            return h.hr.compactMap { p -> Hour? in
                guard p.value > 0 else { return nil }
                if let n = night, p.date >= n.start.addingTimeInterval(-1800), p.date < n.end { return Hour(date: p.date, level: -1) }
                let hour = cal.component(.hour, from: p.date)
                // En un trabajo físico el pulso alto es la carga, no los nervios.
                if work.kind == .physical && work.isWorkHour(p.date) { return Hour(date: p.date, level: -2) }
                let moving = (steps[hour] ?? 0) > (work.kind == .standing && work.isWorkHour(p.date) ? 400 : 900)
                if moving { return Hour(date: p.date, level: 0) }
                let over = p.value - rhr
                return Hour(date: p.date, level: over > 30 ? 3 : over > 20 ? 2 : over > 12 ? 1 : 0)
            }
        }
    }

    /// Estrés del día de 0 a 100 (las horas despierto, sin contar el trabajo físico ni el ejercicio).
    static func score(_ store: HealthStore, day: Date) -> Int? {
        let hs = hours(store, day: day).filter { $0.level >= 0 }
        guard hs.count >= 3 else { return nil }
        let avg = Double(hs.reduce(0) { $0 + $1.level }) / Double(hs.count) / 3
        var v = avg * 150 + 8
        // La variabilidad baja también es estrés del cuerpo.
        if let hrv = store.value(.hrv, on: day), let b = store.baseline(.hrv, before: store.dayStart(day)) {
            v += max(-8, min(14, -b.z(hrv) * 6))
        }
        return Int(min(100, max(0, v)).rounded())
    }

    static func label(_ v: Int) -> (String, Color) {
        v >= 55 ? ("Alto", Palette.heart) : v >= 30 ? ("Medio", Palette.effort) : ("Bajo", Palette.good)
    }

    static func sentence(_ v: Int, hours: [Hour]) -> String {
        let high = hours.filter { $0.level >= 2 }.count
        let work = hours.contains { $0.level == -2 }
        if v >= 55 { return "Día tenso: \(high) h con el pulso alto sin moverte. Un paseo o respirar despacio unos minutos ayuda a bajarlo." }
        if v >= 30 { return high > 0 ? "Estrés normal, con \(high) h de pulso alto sin moverte." : "Estrés normal, sin picos fuertes." }
        return work ? "Fuera del trabajo has estado tranquilo." : "Día tranquilo: el pulso ha ido acorde con lo que te movías."
    }
}

// MARK: - Edad del cuerpo

@MainActor
enum BioAge {
    struct Part: Identifiable {
        var id: String
        var title: String
        var symbol: String
        var color: Color
        var value: String
        var years: Double
    }

    struct Result {
        var age: Double
        var real: Double
        var parts: [Part]
        var diff: Double { age - real }
    }

    static let ageKey = "edadManual", sexKey = "sexoManual"

    static func realAge(_ store: HealthStore, at day: Date = .now) -> Double? {
        if let b = store.profile.birth { return day.timeIntervalSince(b) / (365.25 * 86400) }
        let manual = UserDefaults.standard.integer(forKey: ageKey)
        return manual > 0 ? Double(manual) - day.distance(to: .now) / (365.25 * 86400) : nil
    }

    static func female(_ store: HealthStore) -> Bool {
        if let f = store.profile.female { return f }
        return UserDefaults.standard.string(forKey: sexKey) == "mujer"
    }

    static func today(_ store: HealthStore) -> Result? {
        compute(store, at: store.today)
    }

    /// Cómo ha ido cambiando: una cada 15 días durante los últimos 3 meses.
    static func history(_ store: HealthStore) -> [TimePoint] {
        store.remember("edad-historia") {
            let cal = Calendar.current
            return stride(from: 90, through: 0, by: -15).compactMap { n -> TimePoint? in
                guard let d = cal.date(byAdding: .day, value: -n, to: store.today), let r = compute(store, at: d) else { return nil }
                return TimePoint(date: d, value: r.age)
            }
        }
    }

    static func compute(_ store: HealthStore, at day: Date) -> Result? {
        store.remember("edad|\(Int(day.timeIntervalSince1970))") { make(store, at: day) }
    }

    private static func avg(_ store: HealthStore, _ m: Metric, _ day: Date, days: Int = 30) -> Double? {
        let cal = Calendar.current
        let from = cal.date(byAdding: .day, value: -days, to: day)!
        let end = cal.date(byAdding: .day, value: 1, to: day)!
        let vals = (store.values[m] ?? [:]).filter { $0.key >= from && $0.key < end && $0.key < store.today }.map(\.value).filter { $0 > 0 }
        guard vals.count >= 7 else { return nil }
        let s = vals.sorted()
        return s[s.count / 2]
    }

    private static func make(_ store: HealthStore, at day: Date) -> Result? {
        guard let real = realAge(store, at: day) else { return nil }
        let female = female(store)
        var parts: [Part] = []
        func clamp(_ v: Double, _ a: Double) -> Double { max(-a, min(a, v)) }

        // Forma física (VO₂ máx): la edad a la que tu VO₂ sería la media.
        let cal = Calendar.current
        let vo2From = cal.date(byAdding: .day, value: -90, to: day)!
        if let vo2 = (store.values[.vo2max] ?? [:]).filter({ $0.key >= vo2From && $0.key <= day }).max(by: { $0.key < $1.key })?.value {
            // Media del Apple Watch por edad: unos 40 a los 30 años en hombres (33 en mujeres), bajando cada año.
            let (a, b) = female ? (41.0, 0.25) : (48.5, 0.27)
            let fitAge = max(18, min(90, (a - vo2) / b))
            parts.append(Part(id: "vo2", title: "Forma física", symbol: "bolt.heart.fill", color: Palette.recovery,
                              value: "\(Fmt.value(.vo2max, vo2)) VO₂ máx", years: clamp((fitAge - real) * 0.3, 5)))
        }
        if let rhr = avg(store, .restingHR, day) {
            parts.append(Part(id: "rhr", title: "Pulso en reposo", symbol: "heart.fill", color: Palette.heart,
                              value: "\(Fmt.number(rhr)) lpm", years: clamp((rhr - (female ? 64 : 61)) * 0.22, 4)))
        }
        if let hrv = avg(store, .hrv, day) {
            let expected = max(20, (female ? 66 : 70) - 0.6 * real)
            parts.append(Part(id: "hrv", title: "Variabilidad", symbol: "waveform.path.ecg", color: Palette.recovery,
                              value: "\(Fmt.number(hrv)) ms", years: clamp((expected - hrv) / expected * 8, 4)))
        }
        if let sleep = avg(store, .sleep, day) {
            let h = sleep / 3600
            let y: Double = h < 6 ? 2 : h < 7 ? (7 - h) * 1.5 : h <= 9 ? -0.6 : 0.6
            parts.append(Part(id: "sueno", title: "Sueño", symbol: "moon.zzz.fill", color: Palette.sleep,
                              value: Fmt.duration(sleep), years: y))
        }
        if let steps = avg(store, .steps, day) {
            parts.append(Part(id: "pasos", title: "Pasos al día", symbol: "figure.walk", color: Palette.effort,
                              value: Fmt.number(steps), years: clamp((7500 - steps) / 2500, 2.5)))
        }
        guard parts.count >= 2 else { return nil }
        let total = max(-15, min(15, parts.reduce(0) { $0 + $1.years }))
        return Result(age: real + total, real: real, parts: parts.sorted { $0.years < $1.years })
    }

    static func ageText(_ v: Double) -> String { String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",") }
}
