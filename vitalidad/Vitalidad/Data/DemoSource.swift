import Foundation

/// Datos de ejemplo creíbles (120 días) para las vistas previas, el simulador y las capturas (`-demo`).
struct DemoSource: HealthDataSource {
    var name: String { "Datos de ejemplo" }
    var isAvailable: Bool { true }
    func requestAuthorization() async throws {}
    func observeChanges(_ onChange: @escaping @Sendable () async -> Void) {}

    /// Progreso del día de hoy (para que lo acumulado vaya a medias, como en la vida real).
    static var todayProgress: Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: .now)
        let h = Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60
        return min(1, max(0.08, (h - 7) / 15))
    }

    func daily(_ metric: Metric, from: Date, to: Date) async -> [Date: Double] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var out: [Date: Double] = [:]
        var d = cal.startOfDay(for: from)
        while d <= to {
            let back = cal.dateComponents([.day], from: d, to: today).day ?? 0
            if let v = Self.value(metric, daysAgo: back) { out[d] = v }
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return out
    }

    static func value(_ m: Metric, daysAgo n: Int) -> Double? {
        var r = Rand(seed: UInt64(n) &* 7919 &+ UInt64(Metric.allCases.firstIndex(of: m) ?? 0) &* 104729)
        let weekend = { () -> Bool in
            let wd = Calendar.current.component(.weekday, from: Calendar.current.date(byAdding: .day, value: -n, to: .now)!)
            return wd == 1 || wd == 7
        }()
        let partial = n == 0 ? todayProgress : 1
        let trend = Double(n) / 120
        switch m {
        case .steps: return max(1500, r.normal(weekend ? 10500 : 8200, 2300)) * partial
        case .activeEnergy: return max(150, r.normal(weekend ? 610 : 480, 140)) * partial
        case .basalEnergy: return r.normal(1720, 25) * partial
        case .exerciseMinutes: return max(2, r.normal(weekend ? 48 : 31, 14)) * partial
        case .standHours: return (min(16, max(5, r.normal(11, 2))) * partial).rounded()
        case .heartRate: return r.normal(71, 3)
        case .restingHR:
            if n == 0 { return 60 }
            return r.normal(57.5 + trend * 2.5, 1.6)
        case .hrv:
            if n == 0 { return 44 }
            return max(18, r.normal(52 - trend * 6, 7))
        case .respiratoryRate: return n == 0 ? 15.1 : r.normal(14.4, 0.4)
        case .vo2max: return n % 4 == 0 ? 44.6 - trend * 1.8 + r.normal(0, 0.2) : nil
        case .walkingHR: return r.normal(97, 3)
        case .weight: return n % 3 == 0 ? 76.2 + trend * 1.6 + r.normal(0, 0.25) : nil
        case .calories: return max(900, r.normal(weekend ? 2450 : 2150, 260)) * (n == 0 ? min(1, partial * 1.15) : 1)
        case .protein: return max(40, r.normal(118, 22)) * (n == 0 ? min(1, partial * 1.15) : 1)
        case .carbs: return max(80, r.normal(235, 45)) * (n == 0 ? min(1, partial * 1.15) : 1)
        case .fat: return max(30, r.normal(74, 14)) * (n == 0 ? min(1, partial * 1.15) : 1)
        case .water: return max(0.5, r.normal(1.9, 0.4)) * (n == 0 ? min(1, partial * 1.15) : 1)
        case .sleep: return nil
        }
    }

    func nights(from: Date, to: Date) async -> [SleepNight] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var out: [SleepNight] = []
        var d = cal.startOfDay(for: from)
        while d <= min(to, today) {
            let n = cal.dateComponents([.day], from: d, to: today).day ?? 0
            out.append(Self.night(day: d, daysAgo: n))
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return out
    }

    static func night(day: Date, daysAgo n: Int) -> SleepNight {
        var r = Rand(seed: UInt64(n) &* 31337 &+ 17)
        let cal = Calendar.current
        let wd = cal.component(.weekday, from: day)
        let weekend = wd == 1 || wd == 7
        // Hora de acostarse en minutos desde la medianoche anterior al despertar (negativo = día anterior).
        var bed = r.normal(weekend ? -10 : -35, 28)
        var total = r.normal(weekend ? 470 : 440, 32)
        if n == 0 { bed = -5; total = 400 }   // anoche: 6 h 40
        var t = cal.date(byAdding: .minute, value: Int(bed), to: day)!
        let end = t.addingTimeInterval(total * 60)
        var segs: [SleepSegment] = []
        func add(_ s: SleepStage, _ minutes: Double) {
            let e = min(end, t.addingTimeInterval(max(2, minutes) * 60))
            if e > t { segs.append(SleepSegment(stage: s, start: t, end: e)) }
            t = e
        }
        add(.awake, r.normal(9, 3))
        var cycle = 0
        while t < end {
            let early = cycle < 2
            add(.core, r.normal(early ? 28 : 38, 6))
            add(.deep, r.normal(early ? 34 : 10, 5))
            add(.core, r.normal(14, 4))
            add(.rem, r.normal(early ? 12 : 26, 5))
            if r.next() < 0.35 { add(.awake, r.normal(4, 2)) }
            cycle += 1
        }
        return SleepNight(day: day, segments: segs)
    }

    func workouts(from: Date, to: Date) async -> [Workout] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var out: [Workout] = []
        let kinds: [(UInt, Double, Double, Double)] = [   // tipo, minutos, kcal/min, metros/min
            (37, 38, 11.5, 175), (50, 55, 6.5, 0), (13, 62, 9.0, 420), (52, 48, 4.6, 85), (63, 24, 12.5, 0),
        ]
        var d = cal.startOfDay(for: from)
        while d <= min(to, today) {
            let n = cal.dateComponents([.day], from: d, to: today).day ?? 0
            var r = Rand(seed: UInt64(n) &* 4421 &+ 5)
            if n == 1 || (n > 1 && r.next() < 0.5) {
                let k = n == 1 ? kinds[0] : kinds[Int(r.next() * Double(kinds.count)) % kinds.count]
                let minutes = r.normal(k.1, 6)
                let start = cal.date(byAdding: .minute, value: Int(r.normal(18.5 * 60, 50)), to: d)!
                out.append(Workout(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!,
                                   kind: k.0, start: start, end: start.addingTimeInterval(minutes * 60),
                                   energy: minutes * k.2, distance: k.3 > 0 ? minutes * k.3 : nil, avgHR: r.normal(k.2 > 10 ? 152 : 118, 8)))
            }
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return out.sorted { $0.start > $1.start }
    }

    func hourly(_ metric: Metric, day: Date) async -> [TimePoint] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let nowHour = cal.isDateInToday(day) ? cal.component(.hour, from: .now) : 23
        var r = Rand(seed: 99)
        return (0...nowHour).map { h in
            let date = cal.date(byAdding: .hour, value: h, to: start)!
            let awake = h >= 7 && h <= 23
            let v: Double = switch metric {
            case .heartRate: awake ? r.normal(h == 19 ? 128 : 76, 6) : r.normal(56, 2)
            case .steps: awake ? max(0, r.normal(h == 8 || h == 14 || h == 19 ? 1400 : 420, 220)) : 0
            default: 0
            }
            return TimePoint(date: date, value: v)
        }
    }
}

/// Generador pseudoaleatorio con semilla (los datos de ejemplo salen iguales cada vez).
struct Rand {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }

    mutating func normal(_ mean: Double, _ sd: Double) -> Double {
        let u1 = max(1e-9, next()), u2 = next()
        return mean + sd * sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }
}
