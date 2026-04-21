import HealthKit
import Foundation

class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    private init() {}

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            return true
        } catch {
            print("[HealthKit] Auth error: \(error.localizedDescription)")
            return false
        }
    }

    func syncTodayData() async {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)

        async let steps = fetchSum(.stepCount, from: startOfDay, to: now)
        async let calories = fetchSum(.activeEnergyBurned, from: startOfDay, to: now)
        async let exercise = fetchSum(.appleExerciseTime, from: startOfDay, to: now)

        let (s, c, e) = await (steps, calories, exercise)

        // Store in UserDefaults for the web view to access
        let defaults = UserDefaults.standard
        defaults.set(Int(s), forKey: "wylde_health_steps")
        defaults.set(Int(c), forKey: "wylde_health_calories")
        defaults.set(Int(e), forKey: "wylde_health_exercise_min")
        defaults.set(Date().timeIntervalSince1970, forKey: "wylde_health_last_sync")

        print("[HealthKit] Synced — Steps: \(Int(s)), Cal: \(Int(c)), Exercise: \(Int(e))min")
    }

    private func fetchSum(_ identifier: HKQuantityTypeIdentifier, from start: Date, to end: Date) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }

                let unit: HKUnit
                switch identifier {
                case .stepCount:
                    unit = .count()
                case .activeEnergyBurned:
                    unit = .kilocalorie()
                case .appleExerciseTime:
                    unit = .minute()
                default:
                    unit = .count()
                }

                continuation.resume(returning: sum.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    func fetchSleepHours(for date: Date) async -> Double {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }

        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }

                let asleepSamples = samples.filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                }

                let totalSeconds = asleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds / 3600.0)
            }
            store.execute(query)
        }
    }
}
