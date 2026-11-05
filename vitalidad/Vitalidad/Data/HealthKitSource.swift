import Foundation
import HealthKit

/// Fuente de datos: Apple Salud (Apple Watch, Yazio y todo lo que escribe en Salud). Solo lectura.
final class HealthKitSource: HealthDataSource, @unchecked Sendable {
    static let shared = HealthKitSource()
    let store = HKHealthStore()

    var name: String { "Apple Salud" }
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static let quantityIDs: [HKQuantityTypeIdentifier] = [
        .stepCount, .activeEnergyBurned, .basalEnergyBurned, .appleExerciseTime,
        .heartRate, .restingHeartRate, .heartRateVariabilitySDNN, .respiratoryRate,
        .vo2Max, .walkingHeartRateAverage, .bodyMass,
        .dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal, .dietaryWater,
    ]

    static var readTypes: Set<HKObjectType> {
        var s = Set<HKObjectType>(quantityIDs.map { HKQuantityType($0) })
        s.insert(HKCategoryType(.sleepAnalysis))
        s.insert(HKCategoryType(.appleStandHour))
        s.insert(HKObjectType.workoutType())
        s.insert(HKCharacteristicType(.dateOfBirth))
        s.insert(HKCharacteristicType(.biologicalSex))
        return s
    }

    /// Lo único que escribe: las comidas y el agua que apuntas en la app.
    static let shareIDs: [HKQuantityTypeIdentifier] = [.dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal, .dietaryWater]

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: Set(Self.shareIDs.map { HKQuantityType($0) }), read: Self.readTypes)
    }

    // MARK: - Escribir comidas

    func saveFood(name: String, date: Date, kcal: Double, protein: Double, carbs: Double, fat: Double) async -> [UUID] {
        let meta: [String: Any] = [HKMetadataKeyFoodType: name]
        var samples: [HKQuantitySample] = []
        func add(_ id: HKQuantityTypeIdentifier, _ v: Double, _ u: HKUnit) {
            guard v > 0 else { return }
            samples.append(HKQuantitySample(type: HKQuantityType(id), quantity: HKQuantity(unit: u, doubleValue: v), start: date, end: date, metadata: meta))
        }
        add(.dietaryEnergyConsumed, kcal, .kilocalorie())
        add(.dietaryProtein, protein, .gram())
        add(.dietaryCarbohydrates, carbs, .gram())
        add(.dietaryFatTotal, fat, .gram())
        guard !samples.isEmpty else { return [] }
        do { try await store.save(samples) } catch { return [] }
        return samples.map(\.uuid)
    }

    func saveWater(_ liters: Double, date: Date) async -> [UUID] {
        let s = HKQuantitySample(type: HKQuantityType(.dietaryWater), quantity: HKQuantity(unit: .liter(), doubleValue: liters), start: date, end: date)
        do { try await store.save(s) } catch { return [] }
        return [s.uuid]
    }

    func deleteSamples(_ ids: [UUID]) async {
        guard !ids.isEmpty else { return }
        let predicate = HKQuery.predicateForObjects(with: Set(ids))
        for id in Self.shareIDs {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                store.deleteObjects(of: HKQuantityType(id), predicate: predicate) { _, _, _ in c.resume() }
            }
        }
    }

    // MARK: - Tipos y unidades

    private static func quantity(_ m: Metric) -> (HKQuantityTypeIdentifier, HKUnit)? {
        let perMinute = HKUnit.count().unitDivided(by: .minute())
        switch m {
        case .steps: return (.stepCount, .count())
        case .activeEnergy: return (.activeEnergyBurned, .kilocalorie())
        case .basalEnergy: return (.basalEnergyBurned, .kilocalorie())
        case .exerciseMinutes: return (.appleExerciseTime, .minute())
        case .heartRate: return (.heartRate, perMinute)
        case .restingHR: return (.restingHeartRate, perMinute)
        case .hrv: return (.heartRateVariabilitySDNN, .secondUnit(with: .milli))
        case .respiratoryRate: return (.respiratoryRate, perMinute)
        case .vo2max: return (.vo2Max, HKUnit(from: "ml/kg*min"))
        case .walkingHR: return (.walkingHeartRateAverage, perMinute)
        case .weight: return (.bodyMass, .gramUnit(with: .kilo))
        case .calories: return (.dietaryEnergyConsumed, .kilocalorie())
        case .protein: return (.dietaryProtein, .gram())
        case .carbs: return (.dietaryCarbohydrates, .gram())
        case .fat: return (.dietaryFatTotal, .gram())
        case .water: return (.dietaryWater, .liter())
        case .standHours, .sleep: return nil
        }
    }

    // MARK: - Valores por día

    func daily(_ metric: Metric, from: Date, to: Date) async -> [Date: Double] {
        if metric == .standHours { return await standHours(from: from, to: to) }
        guard let q = Self.quantity(metric) else { return [:] }
        return await collection(q.0, unit: q.1, metric: metric, from: from, to: to, interval: DateComponents(day: 1))
            .reduce(into: [:]) { $0[$1.date] = $1.value }
    }

    func hourly(_ metric: Metric, day: Date) async -> [TimePoint] {
        guard let q = Self.quantity(metric) else { return [] }
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return await collection(q.0, unit: q.1, metric: metric, from: start, to: min(end, .now), interval: DateComponents(hour: 1))
    }

    private func collection(_ id: HKQuantityTypeIdentifier, unit: HKUnit, metric: Metric, from: Date, to: Date, interval: DateComponents) async -> [TimePoint] {
        let type = HKQuantityType(id)
        let options: HKStatisticsOptions = switch metric.aggregation {
        case .sum: .cumulativeSum
        case .average: .discreteAverage
        case .latest: .mostRecent
        }
        let anchor = Calendar.current.startOfDay(for: from)
        let predicate = HKQuery.predicateForSamples(withStart: anchor, end: to)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: type, predicate: predicate),
            options: options, anchorDate: anchor, intervalComponents: interval)
        guard let result = try? await descriptor.result(for: store) else { return [] }
        var out: [TimePoint] = []
        result.enumerateStatistics(from: anchor, to: to) { s, _ in
            let q: HKQuantity? = switch metric.aggregation {
            case .sum: s.sumQuantity()
            case .average: s.averageQuantity()
            case .latest: s.mostRecentQuantity()
            }
            if let q { out.append(TimePoint(date: s.startDate, value: q.doubleValue(for: unit))) }
        }
        return out
    }

    private func standHours(from: Date, to: Date) async -> [Date: Double] {
        let type = HKCategoryType(.appleStandHour)
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: from), end: to)
        let d = HKSampleQueryDescriptor(predicates: [.categorySample(type: type, predicate: predicate)], sortDescriptors: [])
        guard let samples = try? await d.result(for: store) else { return [:] }
        var out: [Date: Double] = [:]
        for s in samples where s.value == HKCategoryValueAppleStandHour.stood.rawValue {
            out[Calendar.current.startOfDay(for: s.startDate), default: 0] += 1
        }
        return out
    }

    // MARK: - Sueño

    func nights(from: Date, to: Date) async -> [SleepNight] {
        let type = HKCategoryType(.sleepAnalysis)
        let cal = Calendar.current
        // Las noches empiezan la tarde anterior al primer día pedido.
        let start = cal.date(byAdding: .hour, value: -18, to: cal.startOfDay(for: from))!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: to)
        let d = HKSampleQueryDescriptor(predicates: [.categorySample(type: type, predicate: predicate)],
                                        sortDescriptors: [SortDescriptor(\.startDate)])
        guard let samples = try? await d.result(for: store) else { return [] }

        // Cada tramo va a la noche del día en que te despiertas (se suman 6 h al punto medio del tramo).
        var bySourceAndDay: [Date: [String: [SleepSegment]]] = [:]
        for s in samples {
            guard let value = HKCategoryValueSleepAnalysis(rawValue: s.value) else { continue }
            let stage: SleepStage
            switch value {
            case .inBed: continue
            case .awake: stage = .awake
            case .asleepREM: stage = .rem
            case .asleepCore: stage = .core
            case .asleepDeep: stage = .deep
            default: stage = .unspecified
            }
            let mid = s.startDate.addingTimeInterval(s.endDate.timeIntervalSince(s.startDate) / 2)
            let day = cal.startOfDay(for: mid.addingTimeInterval(6 * 3600))
            guard day >= cal.startOfDay(for: from) else { continue }
            let src = s.sourceRevision.source.bundleIdentifier
            bySourceAndDay[day, default: [:]][src, default: []].append(SleepSegment(stage: stage, start: s.startDate, end: s.endDate))
        }

        // Si varias apps apuntan la misma noche, se queda la que tenga fases (el reloj) y más tiempo dormido.
        return bySourceAndDay.compactMap { day, sources in
            let best = sources.values.max { a, b in
                score(a) < score(b)
            }
            guard let segs = best, segs.contains(where: { $0.stage != .awake }) else { return nil }
            return SleepNight(day: day, segments: segs.sorted { $0.start < $1.start })
        }
        .sorted { $0.day < $1.day }
    }

    private func score(_ segs: [SleepSegment]) -> Double {
        let staged = segs.contains { $0.stage == .deep || $0.stage == .rem || $0.stage == .core }
        let asleep = segs.filter { $0.stage != .awake }.reduce(0) { $0 + $1.duration }
        return (staged ? 1e7 : 0) + asleep
    }

    // MARK: - Entrenos

    func workouts(from: Date, to: Date) async -> [Workout] {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
        let d = HKSampleQueryDescriptor(predicates: [.workout(predicate)],
                                        sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)])
        guard let list = try? await d.result(for: store) else { return [] }
        return list.map { w in
            Workout(
                id: w.uuid,
                kind: w.workoutActivityType.rawValue,
                start: w.startDate,
                end: w.endDate,
                energy: w.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                distance: w.totalDistance?.doubleValue(for: .meter()),
                avgHR: w.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            )
        }
    }

    // MARK: - Perfil

    func profile() async -> Profile {
        var p = Profile()
        if let c = try? store.dateOfBirthComponents() { p.birth = Calendar.current.date(from: c) }
        if let s = try? store.biologicalSex().biologicalSex {
            p.female = s == .female ? true : s == .male ? false : nil
        }
        return p
    }

    // MARK: - Cambios en segundo plano

    private static let observed: [HKSampleType] = [
        HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned), HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRateVariabilitySDNN), HKQuantityType(.dietaryEnergyConsumed),
        HKCategoryType(.sleepAnalysis), HKObjectType.workoutType(),
    ]

    func observeChanges(_ onChange: @escaping @Sendable () async -> Void) {
        guard isAvailable else { return }
        for type in Self.observed {
            let q = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                guard error == nil else { completion(); return }
                Task {
                    await onChange()
                    completion()
                }
            }
            store.execute(q)
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }
}
