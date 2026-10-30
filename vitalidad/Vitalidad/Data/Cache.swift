import Foundation
import SwiftData

/// Copia local de lo leído en Salud, para abrir la app al instante y sin esperar.
@Model final class DayValue {
    @Attribute(.unique) var key: String
    var metric: String
    var day: Date
    var value: Double

    init(metric: Metric, day: Date, value: Double) {
        self.key = "\(metric.rawValue)|\(Int(day.timeIntervalSince1970))"
        self.metric = metric.rawValue
        self.day = day
        self.value = value
    }
}

@Model final class NightRecord {
    @Attribute(.unique) var day: Date
    var data: Data

    init(_ night: SleepNight) {
        day = night.day
        data = (try? JSONEncoder().encode(night)) ?? Data()
    }
}

@Model final class WorkoutRecord {
    @Attribute(.unique) var id: UUID
    var start: Date
    var data: Data

    init(_ w: Workout) {
        id = w.id
        start = w.start
        data = (try? JSONEncoder().encode(w)) ?? Data()
    }
}

@MainActor
final class Cache {
    let container: ModelContainer?
    var context: ModelContext? { container?.mainContext }

    init(inMemory: Bool) {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try? ModelContainer(for: DayValue.self, NightRecord.self, WorkoutRecord.self, configurations: config)
    }

    func load() -> (values: [Metric: [Date: Double]], nights: [Date: SleepNight], workouts: [Workout]) {
        guard let ctx = context else { return ([:], [:], []) }
        var values: [Metric: [Date: Double]] = [:]
        for row in (try? ctx.fetch(FetchDescriptor<DayValue>())) ?? [] {
            if let m = Metric(rawValue: row.metric) { values[m, default: [:]][row.day] = row.value }
        }
        var nights: [Date: SleepNight] = [:]
        for row in (try? ctx.fetch(FetchDescriptor<NightRecord>())) ?? [] {
            if let n = try? JSONDecoder().decode(SleepNight.self, from: row.data) { nights[n.day] = n }
        }
        let workouts = ((try? ctx.fetch(FetchDescriptor<WorkoutRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? [])
            .compactMap { try? JSONDecoder().decode(Workout.self, from: $0.data) }
        return (values, nights, workouts)
    }

    /// Guarda solo lo que ha cambiado. Inserta con la misma clave = sustituye.
    func save(values: [Metric: [Date: Double]], old: [Metric: [Date: Double]], nights: [SleepNight], workouts: [Workout]) {
        guard let ctx = context else { return }
        for (m, days) in values {
            for (d, v) in days where old[m]?[d] != v {
                ctx.insert(DayValue(metric: m, day: d, value: v))
            }
        }
        for n in nights { ctx.insert(NightRecord(n)) }
        for w in workouts { ctx.insert(WorkoutRecord(w)) }
        try? ctx.save()
    }

    /// Borra lo que tenga más de 400 días.
    func prune() {
        guard let ctx = context, let limit = Calendar.current.date(byAdding: .day, value: -400, to: .now) else { return }
        try? ctx.delete(model: DayValue.self, where: #Predicate { $0.day < limit })
        try? ctx.delete(model: NightRecord.self, where: #Predicate { $0.day < limit })
        try? ctx.delete(model: WorkoutRecord.self, where: #Predicate { $0.start < limit })
        try? ctx.save()
    }
}
