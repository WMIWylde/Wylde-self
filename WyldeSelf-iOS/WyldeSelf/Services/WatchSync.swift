import Foundation
import Combine

#if canImport(WatchConnectivity)
import WatchConnectivity

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

    func start(appState: AppState) {
        self.appState = appState

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

        syncToWatch()
    }

    func syncToWatch() {
        guard let state = appState,
              let session = session,
              session.activationState == .activated else { return }

        let ritualDone = state.morningProtocolActions.filter(\.completed).count
        let todayWorkout = WorkoutService.shared.todaysWorkout(day: state.currentDay)

        let context: [String: Any] = [
            "currentDay": state.currentDay,
            "userName": state.userName,
            // Send the plain Int total — a WyldeScore? struct is not a
            // property-list type and would make updateApplicationContext throw
            // (silently, via try?), so the watch would never get a score.
            "wyldeScore": WyldeScoreService.shared.todayScore?.totalScore ?? 0,
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

extension WatchSync: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in syncToWatch() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        Task { @MainActor in
            guard let state = appState else { return }
            switch action {
            case "water_add":
                if state.waterLogged < state.waterGoal { state.waterLogged += 1 }
            case "workout_start":
                HealthKitManager.shared.startWorkoutSession()
            case "workout_end":
                state.workoutCompleted = true
                Task { await HealthKitManager.shared.endWorkoutSession() }
            case "walk_start":
                // Walk started on the watch. There is no in-progress walk
                // state to persist on the phone yet — the loop closes on
                // "walk_end" (below). Handled explicitly so it isn't dropped.
                break
            case "walk_end":
                state.dailyWalkCompleted = true
            default: break
            }
            syncToWatch()
        }
    }
}

#else

// Stub for simulator / environments without WatchConnectivity
@MainActor
class WatchSync: ObservableObject {
    static let shared = WatchSync()
    func start(appState: AppState) {}
    func syncToWatch() {}
}

#endif
