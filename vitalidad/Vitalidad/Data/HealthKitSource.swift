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
        return s
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }
}
