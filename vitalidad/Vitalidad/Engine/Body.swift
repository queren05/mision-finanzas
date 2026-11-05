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

/// Tu jornada: tipo de trabajo y el horario de cada día (en minutos desde las 0:00).
struct WorkSchedule {
    struct Shift: Equatable {
        var from: Int
        var to: Int
    }

    var kind: JobKind
    /// Día de la semana (1 domingo … 7 sábado) → horario.
    var shifts: [Int: Shift]

    static let kindKey = "trabajoTipo", scheduleKey = "trabajoHorario", askedKey = "trabajoPreguntado"
    /// Lunes de 16:30 a 22:30 y de martes a viernes de 17:30 a 22:30.
    static let defaultSchedule = "2:990-1350,3:1050-1350,4:1050-1350,5:1050-1350,6:1050-1350"

    static func decode(_ s: String) -> [Int: Shift] {
        var out: [Int: Shift] = [:]
        for part in s.split(separator: ",") {
            let kv = part.split(separator: ":"), r = kv.last?.split(separator: "-") ?? []
            guard kv.count == 2, r.count == 2, let d = Int(kv[0]), let a = Int(r[0]), let b = Int(r[1]), b > a else { continue }
            out[d] = Shift(from: a, to: b)
        }
        return out
    }

    static func encode(_ m: [Int: Shift]) -> String {
        m.keys.sorted().compactMap { d in m[d].map { "\(d):\($0.from)-\($0.to)" } }.joined(separator: ",")
    }

    static var current: WorkSchedule {
        let d = UserDefaults.standard
        let kind = JobKind(rawValue: d.string(forKey: kindKey) ?? "") ?? .physical
        return WorkSchedule(kind: kind, shifts: decode(d.string(forKey: scheduleKey) ?? defaultSchedule))
    }

    var active: Bool { kind != .none }

    func shift(on d: Date) -> Shift? { active ? shifts[Calendar.current.component(.weekday, from: d)] : nil }

    func isWorkDay(_ d: Date) -> Bool { shift(on: d) != nil }

    /// Una hora cuenta como trabajo si su mitad cae dentro del horario.
    func isWorkHour(_ d: Date) -> Bool {
        guard let s = shift(on: d) else { return false }
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        let mid = (c.hour ?? 0) * 60 + (c.minute ?? 0) + 30
        return mid >= s.from && mid < s.to
    }

    /// Cuándo empieza y acaba la jornada de ese día.
    func bounds(on day: Date) -> (Date, Date)? {
        guard let s = shift(on: day) else { return nil }
        let start = Calendar.current.startOfDay(for: day)
        return (start.addingTimeInterval(Double(s.from) * 60), start.addingTimeInterval(Double(s.to) * 60))
    }

    static func clock(_ m: Int) -> String { "\(m / 60):\(String(format: "%02d", m % 60))" }

    func hoursText(on day: Date) -> String { shift(on: day).map { "\(Self.clock($0.from))–\(Self.clock($0.to))" } ?? "" }

    /// Resumen para el entrenador: «lunes 16:30–22:30, martes 17:30–22:30…».
    var summary: String {
        let names = [2: "lunes", 3: "martes", 4: "miércoles", 5: "jueves", 6: "viernes", 7: "sábado", 1: "domingo"]
        return [2, 3, 4, 5, 6, 7, 1].compactMap { d in shifts[d].map { "\(names[d]!) \(Self.clock($0.from))–\(Self.clock($0.to))" } }.joined(separator: ", ")
    }
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
                // Despierto y sentado, lo normal es ir 10-20 pulsaciones por encima del pulso en reposo.
                return Hour(date: p.date, level: over > 40 ? 3 : over > 30 ? 2 : over > 22 ? 1 : 0)
            }
        }
    }

    /// Estrés del día de 0 a 100 (las horas despierto, sin contar el trabajo físico ni el ejercicio).
    static func score(_ store: HealthStore, day: Date) -> Int? {
        let hs = hours(store, day: day).filter { $0.level >= 0 }
        guard hs.count >= 3 else { return nil }
        let avg = Double(hs.reduce(0) { $0 + $1.level }) / Double(hs.count) / 3
        var v = avg * 130 + 6
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

    /// Lo que más años te quitaría, de más a menos.
    static func tips(_ r: Result) -> [(Part, String)] {
        r.parts.filter { $0.years > 0.2 }.sorted { $0.years > $1.years }.prefix(3).map { p in
            let text: String = switch p.id {
            case "tabaco": "Dejar de fumar"
            case "alcohol": "Bajar a menos de 7 bebidas a la semana"
            case "porro": "Dejar los porros"
            case "vo2": "Mejorar el fondo: 3 días de cardio a la semana"
            case "rhr": "Bajar el pulso en reposo con cardio suave y dormir bien"
            case "hrv": "Subir la variabilidad: dormir, menos alcohol y menos estrés"
            case "sueno": "Dormir entre 7 y 9 horas"
            case "pasos": "Llegar a 8.000 pasos al día"
            default: p.title
            }
            return (p, text)
        }
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
        store.remember("edad-historia|\(Journal.shared.version)") {
            let cal = Calendar.current
            return stride(from: 90, through: 0, by: -15).compactMap { n -> TimePoint? in
                guard let d = cal.date(byAdding: .day, value: -n, to: store.today), let r = compute(store, at: d) else { return nil }
                return TimePoint(date: d, value: r.age)
            }
        }
    }

    static func compute(_ store: HealthStore, at day: Date) -> Result? {
        store.remember("edad|\(Int(day.timeIntervalSince1970))|\(Journal.shared.version)") { make(store, at: day) }
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
        // Hábitos del Diario de los últimos 30 días (si los apuntas).
        let journal = Journal.shared
        let answered = (0..<30).compactMap { cal.date(byAdding: .day, value: -$0, to: day) }.filter { journal.answered($0) }
        if answered.count >= 5 {
            func perDay(_ h: String) -> Double { Double(answered.reduce(0) { $0 + journal.value(h, on: $1) }) / Double(answered.count) }
            if journal.tracked.contains("tabaco") {
                let c = perDay("tabaco")
                parts.append(Part(id: "tabaco", title: "Tabaco", symbol: "smoke.fill", color: Color(red: 0.62, green: 0.6, blue: 0.58),
                                  value: c > 0 ? "\(Fmt.number(c, decimals: c < 10 ? 1 : 0)) al día" : "nada", years: c > 0 ? min(7, 1 + c * 0.3) : -0.3))
            }
            if journal.tracked.contains("alcohol") {
                let week = perDay("alcohol") * 7
                parts.append(Part(id: "alcohol", title: "Alcohol", symbol: "wineglass.fill", color: Palette.nutrition,
                                  value: "\(Fmt.number(week, decimals: week < 10 ? 1 : 0)) a la semana", years: week > 7 ? min(3, (week - 7) * 0.15) : week < 1 ? -0.2 : 0))
            }
            if journal.tracked.contains("porro") {
                let p = perDay("porro")
                if p > 0 {
                    parts.append(Part(id: "porro", title: "Porros", symbol: "leaf.fill", color: Color(red: 0.45, green: 0.75, blue: 0.35),
                                      value: "\(Fmt.number(p * 7, decimals: 1)) a la semana", years: min(2.5, 0.3 + p * 1.2)))
                }
            }
        }
        guard parts.count >= 2 else { return nil }
        let total = max(-15, min(15, parts.reduce(0) { $0 + $1.years }))
        return Result(age: real + total, real: real, parts: parts.sorted { $0.years < $1.years })
    }

    static func ageText(_ v: Double) -> String { String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",") }
}
