import Foundation
import SwiftUI

/// Todo lo que la app sabe de ti: lo carga de la copia local al abrir y lo pone al día leyendo la fuente.
@Observable @MainActor
final class HealthStore {
    static let shared = HealthStore(source: Launch.demo ? DemoSource() : HealthKitSource.shared, inMemory: Launch.demo)

    let source: any HealthDataSource
    private let cache: Cache

    private(set) var values: [Metric: [Date: Double]] = [:]
    private(set) var nights: [Date: SleepNight] = [:]
    private(set) var workouts: [Workout] = []
    private(set) var heartToday: [TimePoint] = []
    private(set) var stepsToday: [TimePoint] = []
    private(set) var updated: Date?
    private(set) var loading = false
    /// Cambia cada vez que llegan datos nuevos (para refrescar las vistas que calculan cosas).
    private(set) var revision = 0

    private var lastFull: Date? {
        get { UserDefaults.standard.object(forKey: "ultimaLecturaCompleta") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "ultimaLecturaCompleta") }
    }
    private var observing = false

    init(source: any HealthDataSource, inMemory: Bool) {
        self.source = source
        cache = Cache(inMemory: inMemory)
        let c = cache.load()
        values = c.values
        nights = c.nights
        workouts = c.workouts
    }

    /// Vista previa con datos de ejemplo ya cargados.
    static func preview() -> HealthStore {
        let s = HealthStore(source: DemoSource(), inMemory: true)
        Task { await s.refresh(full: true) }
        return s
    }

    // MARK: - Lectura

    func start() {
        if !observing {
            observing = true
            source.observeChanges { [weak self] in
                await self?.refresh(full: false)
            }
        }
        Task { await refresh(full: (lastFull.map { Date.now.timeIntervalSince($0) > 12 * 3600 } ?? true) || values.isEmpty) }
    }

    /// Lectura pedida mientras otra estaba en marcha (`true` si alguna era completa).
    private var pending: Bool?

    /// `full`: los últimos 120 días. Si no, solo la última semana.
    func refresh(full: Bool) async {
        if loading {
            pending = (pending ?? false) || full
            return
        }
        loading = true
        await load(full: full)
        loading = false
        if let again = pending {
            pending = nil
            await refresh(full: again)
        }
    }

    private func load(full: Bool) async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let from = cal.date(byAdding: .day, value: full ? -120 : -7, to: today)!
        let to = Date.now

        var newValues: [Metric: [Date: Double]] = [:]
        await withTaskGroup(of: (Metric, [Date: Double]).self) { group in
            for m in Metric.allCases where m != .sleep {
                group.addTask { [source] in (m, await source.daily(m, from: from, to: to)) }
            }
            for await (m, v) in group { newValues[m] = v }
        }
        async let n = source.nights(from: from, to: to)
        async let w = source.workouts(from: from, to: to)
        async let hr = source.hourly(.heartRate, day: today)
        async let st = source.hourly(.steps, day: today)
        let (newNights, newWorkouts, newHR, newSteps) = await (n, w, hr, st)

        let old = values
        var merged = values
        for (m, days) in newValues {
            var current = merged[m] ?? [:]
            // Lo que había en el tramo leído y ya no está (borrado en Salud) desaparece.
            for d in current.keys where d >= from && days[d] == nil { current[d] = nil }
            for (d, v) in days { current[d] = v }
            merged[m] = current
        }
        var sleepByDay: [Date: Double] = [:]
        for night in newNights { nights[night.day] = night }
        for (d, night) in nights { sleepByDay[d] = night.asleep }
        merged[.sleep] = sleepByDay

        values = merged
        var ws = workouts.filter { $0.start < from }
        ws.append(contentsOf: newWorkouts)
        workouts = ws.sorted { $0.start > $1.start }
        heartToday = newHR
        stepsToday = newSteps
        updated = .now
        if full { lastFull = .now }
        revision += 1

        cache.save(values: merged, old: old, nights: newNights, workouts: newWorkouts)
        if full { cache.prune() }
    }

    // MARK: - Consultas

    var today: Date { Calendar.current.startOfDay(for: .now) }

    func value(_ m: Metric, on day: Date) -> Double? { values[m]?[Calendar.current.startOfDay(for: day)] }

    /// El último valor disponible (hoy o, si no hay, el más reciente) y su día.
    func latest(_ m: Metric, within days: Int = 30) -> (day: Date, value: Double)? {
        guard let dict = values[m], !dict.isEmpty else { return nil }
        let limit = Calendar.current.date(byAdding: .day, value: -days, to: today)!
        return dict.filter { $0.key >= limit }.max { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    /// Serie de los últimos `n` días (solo los días con dato).
    func series(_ m: Metric, days n: Int, includeToday: Bool = true) -> [TimePoint] {
        let cal = Calendar.current
        let from = cal.date(byAdding: .day, value: -(n - 1), to: today)!
        return (values[m] ?? [:])
            .filter { $0.key >= from && (includeToday || $0.key < today) }
            .map { TimePoint(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }
    }

    /// Si hay datos de esta métrica en el último mes (si no, la tarjeta no se enseña).
    func has(_ m: Metric) -> Bool { latest(m) != nil }

    var lastNight: SleepNight? {
        guard let d = nights.keys.max(), Calendar.current.dateComponents([.day], from: d, to: today).day ?? 99 <= 1 else { return nil }
        return nights[d]
    }

    func recentNights(_ n: Int) -> [SleepNight] {
        let from = Calendar.current.date(byAdding: .day, value: -(n - 1), to: today)!
        return nights.values.filter { $0.day >= from }.sorted { $0.day < $1.day }
    }

    func workouts(days n: Int) -> [Workout] {
        let from = Calendar.current.date(byAdding: .day, value: -(n - 1), to: today)!
        return workouts.filter { $0.start >= from }
    }
}
