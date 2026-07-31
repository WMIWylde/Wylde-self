import Foundation
import Combine
import HealthKit

// ════════════════════════════════════════════════════════════════════
//  WatchWorkoutSessionManager — a REAL HKWorkoutSession with live
//  metrics (heart rate, active calories) that credits the user's rings.
//  Started locally from the watch UI, or remotely when the iPhone calls
//  startWatchApp(with:) as a walk/workout begins.
// ════════════════════════════════════════════════════════════════════

@MainActor
final class WatchWorkoutSessionManager: NSObject, ObservableObject {
    static let shared = WatchWorkoutSessionManager()

    @Published var isActive = false
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var elapsed: TimeInterval = 0

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?

    func start(activityType: HKWorkoutActivityType = .traditionalStrengthTraining,
               locationType: HKWorkoutSessionLocationType = .indoor) {
        guard !isActive else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = locationType
        start(configuration: config)
    }

    func start(configuration: HKWorkoutConfiguration) {
        guard !isActive else { return }
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }
            isActive = true
            elapsed = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.elapsed += 1 }
            }
        } catch {
            print("[WatchWorkout] session start failed: \(error.localizedDescription)")
        }
    }

    func end() {
        guard isActive else { return }
        timer?.invalidate()
        timer = nil
        session?.end()
        let workoutBuilder = builder
        workoutBuilder?.endCollection(withEnd: Date()) { _, _ in
            workoutBuilder?.finishWorkout { _, _ in }
        }
        isActive = false
    }
}

extension WatchWorkoutSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {}
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.isActive = false }
    }
}

extension WatchWorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let qType = type as? HKQuantityType,
                      let stats = workoutBuilder.statistics(for: qType) else { continue }
                switch qType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate):
                    self.heartRate = stats.mostRecentQuantity()?
                        .doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? self.heartRate
                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                    self.activeCalories = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? self.activeCalories
                default: break
                }
            }
        }
    }
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
