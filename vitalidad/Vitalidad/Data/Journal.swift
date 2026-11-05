import Foundation
import SwiftUI
import UserNotifications

/// Un hábito del diario: se marca (sí/no) o se cuenta (bebidas, cigarros…).
struct Habit: Identifiable, Hashable {
    var id: String
    var title: String
    var symbol: String
    var color: Color
    /// Unidad si se cuenta; nil si es sí o no.
    var unit: String?

    var counted: Bool { unit != nil }

    static let all: [Habit] = [
        Habit(id: "alcohol", title: "Alcohol", symbol: "wineglass.fill", color: Palette.nutrition, unit: "bebidas"),
        Habit(id: "tabaco", title: "Tabaco", symbol: "smoke.fill", color: Color(red: 0.62, green: 0.6, blue: 0.58), unit: "cigarros"),
        Habit(id: "porro", title: "Porros", symbol: "leaf.fill", color: Color(red: 0.45, green: 0.75, blue: 0.35), unit: "porros"),
        Habit(id: "cafe", title: "Café por la tarde", symbol: "cup.and.saucer.fill", color: Color(red: 0.78, green: 0.55, blue: 0.35), unit: nil),
        Habit(id: "pantallas", title: "Móvil en la cama", symbol: "iphone", color: Palette.breath, unit: nil),
        Habit(id: "cena", title: "Cena tarde", symbol: "fork.knife", color: Palette.effort, unit: nil),
        Habit(id: "pesada", title: "Comida pesada", symbol: "takeoutbag.and.cup.and.straw.fill", color: Palette.effort, unit: nil),
        Habit(id: "sol", title: "Sol por la mañana", symbol: "sun.max.fill", color: Color(red: 1, green: 0.8, blue: 0.25), unit: nil),
        Habit(id: "agua", title: "Bastante agua", symbol: "drop.fill", color: Palette.breath, unit: nil),
        Habit(id: "estres", title: "Día estresante", symbol: "brain.head.profile", color: Palette.heart, unit: nil),
        Habit(id: "siesta", title: "Siesta", symbol: "bed.double.fill", color: Palette.sleep, unit: nil),
        Habit(id: "noche", title: "Deporte por la noche", symbol: "figure.run", color: Palette.effort, unit: nil),
        Habit(id: "estirar", title: "Estirar o meditar", symbol: "figure.mind.and.body", color: Palette.recovery, unit: nil),
        Habit(id: "dolor", title: "Dolor o agujetas", symbol: "bandage.fill", color: Palette.heart, unit: nil),
        Habit(id: "ducha", title: "Ducha antes de dormir", symbol: "shower.fill", color: Palette.breath, unit: nil),
        Habit(id: "melatonina", title: "Melatonina", symbol: "pills.fill", color: Palette.body, unit: nil),
    ]

    static let defaults = ["alcohol", "tabaco", "cafe", "pantallas", "cena", "sol", "agua", "estres"]

    static func by(_ id: String) -> Habit? { all.first { $0.id == id } }
}

/// El diario: qué hiciste cada día. Se guarda en el iPhone.
@Observable @MainActor
final class Journal {
    static let shared = Journal()

    /// día (yyyy-MM-dd) → hábito → valor (1 si es sí o no; cantidad si se cuenta). Un día guardado sin nada = día sin hábitos.
    private(set) var days: [String: [String: Int]] = [:] { didSet { version += 1 } }
    /// Cambia con cada cosa apuntada (para recalcular lo que te afecta).
    private(set) var version = 0
    var tracked: [String] = Habit.defaults { didSet { save() } }
    var reminder = false { didSet { save(); scheduleReminder() } }
    var reminderHour = 21 { didSet { save(); scheduleReminder() } }
    var reminderMinute = 30 { didSet { save(); scheduleReminder() } }

    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("diario.json")
    private var loading = false

    private struct Saved: Codable {
        var days: [String: [String: Int]]
        var tracked: [String]
        var reminder: Bool
        var hour: Int
        var minute: Int
    }

    init() {
        loading = true
        if Launch.demo {
            fillDemo()
        } else if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(Saved.self, from: d) {
            days = s.days; tracked = s.tracked; reminder = s.reminder; reminderHour = s.hour; reminderMinute = s.minute
        }
        loading = false
    }

    private func save() {
        guard !loading, !Launch.demo else { return }
        let s = Saved(days: days, tracked: tracked, reminder: reminder, hour: reminderHour, minute: reminderMinute)
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: url, options: .atomic) }
    }

    static func key(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func value(_ h: String, on d: Date) -> Int { days[Self.key(d)]?[h] ?? 0 }
    func answered(_ d: Date) -> Bool { days[Self.key(d)] != nil }
    func entry(_ d: Date) -> [String: Int] { days[Self.key(d)] ?? [:] }

    func set(_ h: String, _ v: Int, on d: Date) {
        var e = days[Self.key(d)] ?? [:]
        e[h] = v > 0 ? v : nil
        days[Self.key(d)] = e
        save()
    }

    /// Marca el día como apuntado aunque no hicieras nada de la lista.
    func markAnswered(_ d: Date) {
        if days[Self.key(d)] == nil { days[Self.key(d)] = [:]; save() }
    }

    /// Días seguidos apuntados hasta hoy (o ayer).
    var streak: Int {
        let cal = Calendar.current
        var d = cal.startOfDay(for: .now)
        if !answered(d) { d = cal.date(byAdding: .day, value: -1, to: d)! }
        var n = 0
        while answered(d) { n += 1; d = cal.date(byAdding: .day, value: -1, to: d)! }
        return n
    }

    func scheduleReminder() {
        guard !loading else { return }
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: ["diario"])
        guard reminder else { return }
        let hour = reminderHour, minute = reminderMinute
        c.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            let n = UNMutableNotificationContent()
            n.title = "¿Qué tal el día?"
            n.body = "Apunta en el diario lo que has hecho hoy."
            n.sound = .default
            var t = DateComponents()
            t.hour = hour
            t.minute = minute
            c.add(UNNotificationRequest(identifier: "diario", content: n, trigger: UNCalendarNotificationTrigger(dateMatching: t, repeats: true)))
        }
    }

    private func fillDemo() {
        var r = Rand(seed: 4242)
        let cal = Calendar.current
        for n in 1...75 {
            let d = cal.date(byAdding: .day, value: -n, to: cal.startOfDay(for: .now))!
            var e: [String: Int] = [:]
            if r.next() < 0.3 { e["alcohol"] = Int(r.next() * 4) + 1 }
            e["tabaco"] = Int(r.next() * 9) + 4
            if r.next() < 0.4 { e["cafe"] = 1 }
            if r.next() < 0.55 { e["pantallas"] = 1 }
            if r.next() < 0.3 { e["cena"] = 1 }
            if r.next() < 0.45 { e["sol"] = 1 }
            if r.next() < 0.6 { e["agua"] = 1 }
            if r.next() < 0.25 { e["estres"] = 1 }
            days[Self.key(d)] = e
        }
        days[Self.key(.now)] = ["tabaco": 6, "agua": 1, "sol": 1]
    }
}

// MARK: - Lo que te afecta

/// Cómo cambian el sueño y la recuperación de la noche siguiente los días que haces algo, frente a los que no.
@MainActor
enum HabitImpact {
    struct Effect: Identifiable {
        var habit: Habit
        var sleep: Double?
        var recovery: Double?
        var yes: Int
        var no: Int
        var id: String { habit.id }
        var strongest: Double { max(abs(sleep ?? 0), abs(recovery ?? 0)) }
    }

    static let minDays = 3

    struct Next {
        var day: Date
        var sleep: Int?
        var recovery: Int?
    }

    static func effects(_ store: HealthStore, journal: Journal) -> [Effect] {
        store.remember("impacto|\(journal.version)|\(journal.tracked.joined(separator: ","))") { compute(store, journal: journal) }
    }

    private static func compute(_ store: HealthStore, journal: Journal) -> [Effect] {
        let cal = Calendar.current
        let days = (1...90).compactMap { cal.date(byAdding: .day, value: -$0, to: store.today) }.filter { journal.answered($0) }
        // Lo que pasó al día siguiente (la noche termina ese día).
        let next: [Next] = days.map { d in
            let n = cal.date(byAdding: .day, value: 1, to: d)!
            let r = ScoreEngine.report(store, day: n)
            return Next(day: d, sleep: r.sleep?.value, recovery: r.recovery?.value)
        }
        return journal.tracked.compactMap(Habit.by).map { h in
            func avg(_ v: [Int]) -> Double? { v.isEmpty ? nil : Double(v.reduce(0, +)) / Double(v.count) }
            let yes = next.filter { journal.value(h.id, on: $0.day) > 0 }
            let no = next.filter { journal.value(h.id, on: $0.day) == 0 }
            func diff(_ k: (Next) -> Int?) -> Double? {
                let a = yes.compactMap(k), b = no.compactMap(k)
                guard a.count >= minDays, b.count >= minDays, let x = avg(a), let y = avg(b) else { return nil }
                return x - y
            }
            return Effect(habit: h, sleep: diff { $0.sleep }, recovery: diff { $0.recovery }, yes: yes.count, no: no.count)
        }
        .sorted { $0.strongest > $1.strongest }
    }
}
