import Foundation
import WatchConnectivity
import Combine

/// Phone-side WatchConnectivity bridge. Sends daily state to the watch
/// and receives actions (water logged, workout started/ended, walk done).
@MainActor
class WatchSync: NSObject, ObservableObject {
    static let shared = WatchSync()

    private var session: WCSession?
    private var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    /// Start observing AppState changes and syncing to the watch.
    func start(appState: AppState) {
        self.appState = appState

        // Observe key state changes and push to watch
        let publishers: [AnyPublisher<Void, Never>] = [
            appState.$currentDay.map { _ in () }.eraseToAnyPublisher(),
            appState.$workoutCompleted.map { _ in () }.eraseToAnyPublisher(),
            appState.$dailyWalkCompleted.map { _ in () }.eraseToAnyPublisher(),
            appState.$waterLogged.map { _ in () }.eraseToAnyPublisher(),
            appState.$morningProtocolActions.map { _ in () }.eraseToAnyPublisher(),
        ]

        Publishers.MergeMany(publishers)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] in self?.syncToWatch() }
            .store(in: &cancellables)

        // Initial sync
        syncToWatch()
    }

    /// Push current state to the watch.
    func syncToWatch() {
        guard let state = appState, let session = session, session.isReachable || session.activationState == .activated else { return }

        let ritualDone = state.morningProtocolActions.filter(\.completed).count
        let service = WorkoutService.shared
        let todayWorkout = service.todaysWorkout(day: state.currentDay)

        let context: [String: Any] = [
            "currentDay": state.currentDay,
            "userName": state.userName,
            "wyldeScore": WyldeScoreService.shared.todayScore,
            "ritualDone": ritualDone,
            "ritualTotal": state.morningProtocolActions.count,
            "workoutCompleted": state.workoutCompleted,
            "workoutFocus": todayWorkout?.focus ?? "",
            "workoutExerciseCount": todayWorkout?.exercises.count ?? 0,
            "waterLogged": state.waterLogged,
            "waterGoal": state.waterGoal,
            "walkCompleted": state.dailyWalkCompleted,
        ]

        try? session.updateApplicationContext(context)
    }
}

// MARK: - WCSessionDelegate

extension WatchSync: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            syncToWatch()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// Receive actions from the watch.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        Task { @MainActor in
            guard let state = appState else { return }
            switch action {
            case "water_add":
                if state.waterLogged < state.waterGoal {
                    state.waterLogged += 1
                }
            case "workout_start":
                HealthKitManager.shared.startWorkoutSession()
            case "workout_end":
                state.workoutCompleted = true
                Task { await HealthKitManager.shared.endWorkoutSession() }
            case "walk_start":
                break // walk timer is phone-side
            case "walk_end":
                state.dailyWalkCompleted = true
            default:
                break
            }
            syncToWatch()
        }
    }
}
