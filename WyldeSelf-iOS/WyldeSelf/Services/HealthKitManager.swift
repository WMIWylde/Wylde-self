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
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType()
        ]

        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            return true
        } catch {
            #if DEBUG
            print("[HealthKit] Auth error: \(error.localizedDescription)")
            #endif
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

        #if DEBUG
        print("[HealthKit] Synced — Steps: \(Int(s)), Cal: \(Int(c)), Exercise: \(Int(e))min")
        #endif
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

    // MARK: - Workout Session (activates Apple Watch + Activity rings)

    private var workoutStartDate: Date?
    private var workoutActivityType: HKWorkoutActivityType = .traditionalStrengthTraining
    private(set) var isWorkoutActive = false

    /// Start an HKWorkout session — this activates the Apple Watch sensors
    /// and begins tracking active energy, heart rate, and exercise minutes.
    func startWorkoutSession(activityType: HKWorkoutActivityType = .traditionalStrengthTraining) {
        guard isAvailable else { return }
        workoutStartDate = Date()
        workoutActivityType = activityType
        isWorkoutActive = true
        #if DEBUG
        print("[HealthKit] Workout session started (\(activityType.rawValue))")
        #endif
    }

    /// End the workout session and save it to HealthKit.
    /// This shows up in the Activity app, Health app, and on the Apple Watch rings.
    func endWorkoutSession() async {
        guard isAvailable, let start = workoutStartDate else { return }
        let end = Date()
        let activityType = workoutActivityType
        isWorkoutActive = false
        workoutStartDate = nil

        await saveWorkout(activityType: activityType, start: start, end: end)
    }

    /// Save a completed walk to HealthKit as an outdoor walking workout.
    /// Called when the walk timer completes — uses the actual start/end dates
    /// so it's accurate even if the app was backgrounded.
    func saveWalkWorkout(start: Date, end: Date) async {
        guard isAvailable else { return }
        await saveWorkout(activityType: .walking, start: start, end: end, location: .outdoor)
    }

    private func saveWorkout(activityType: HKWorkoutActivityType, start: Date, end: Date, location: HKWorkoutSessionLocationType? = nil) async {
        // Calculate active calories during the workout window
        let calories = await fetchSum(.activeEnergyBurned, from: start, to: end)

        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = location ?? (activityType == .walking ? .outdoor : .indoor)

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())

        do {
            try await builder.beginCollection(at: start)

            // Add active energy burned sample
            if calories > 0, let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let energySample = HKQuantitySample(
                    type: energyType,
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
                    start: start,
                    end: end
                )
                try await builder.addSamples([energySample])
            }

            // Add distance for walking workouts
            if activityType == .walking {
                let distance = await fetchSum(.distanceWalkingRunning, from: start, to: end)
                if distance > 0, let distType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
                    let distSample = HKQuantitySample(
                        type: distType,
                        quantity: HKQuantity(unit: .meter(), doubleValue: distance),
                        start: start,
                        end: end
                    )
                    try await builder.addSamples([distSample])
                }
            }

            try await builder.endCollection(at: end)
            try await builder.finishWorkout()

            #if DEBUG
            let mins = Int(end.timeIntervalSince(start) / 60)
            print("[HealthKit] Workout saved: \(activityType.rawValue), \(mins)min, \(Int(calories)) cal")
            #endif
        } catch {
            #if DEBUG
            print("[HealthKit] Failed to save workout: \(error.localizedDescription)")
            #endif
        }

        // Sync updated totals
        await syncTodayData()
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
