import Foundation
import Combine
import WatchConnectivity

/// Bridges watch ↔ phone via WatchConnectivity.
/// The phone app sends daily state (day, score, ritual progress, workout status,
/// water count, walk status) and the watch displays it. The watch sends back
/// actions (water logged, workout started/ended, walk started/ended) which the
/// phone applies to AppState.
@MainActor
class PhoneConnector: NSObject, ObservableObject, WCSessionDelegate {

    // Daily state synced from phone
    @Published var currentDay: Int = 1
    @Published var userName: String = ""
    @Published var wyldeScore: Int = 0

    // Ritual
    @Published var ritualDone: Int = 0
    @Published var ritualTotal: Int = 4

    // Workout
    @Published var workoutCompleted: Bool = false
    @Published var workoutFocus: String = ""
    @Published var workoutExerciseCount: Int = 0

    // Water
    @Published var waterLogged: Int = 0
    @Published var waterGoal: Int = 8

    // Walk
    @Published var walkCompleted: Bool = false

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Send actions to phone

    func addWater() {
        guard waterLogged < waterGoal else { return }
        waterLogged += 1
        send(["action": "water_add"])
    }

    func startWorkout() {
        send(["action": "workout_start"])
    }

    func endWorkout() {
        workoutCompleted = true
        send(["action": "workout_end"])
    }

    func startWalk() {
        send(["action": "walk_start"])
    }

    func endWalk() {
        walkCompleted = true
        send(["action": "walk_end"])
    }

    private func send(_ message: [String: Any]) {
        session?.sendMessage(message, replyHandler: nil) { error in
            #if DEBUG
            print("[Watch] Send error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Receive state from phone

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            updateState(from: applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            updateState(from: message)
        }
    }

    private func updateState(from data: [String: Any]) {
        if let d = data["currentDay"] as? Int { currentDay = d }
        if let n = data["userName"] as? String { userName = n }
        if let s = data["wyldeScore"] as? Int { wyldeScore = s }
        if let rd = data["ritualDone"] as? Int { ritualDone = rd }
        if let rt = data["ritualTotal"] as? Int { ritualTotal = rt }
        if let wc = data["workoutCompleted"] as? Bool { workoutCompleted = wc }
        if let wf = data["workoutFocus"] as? String { workoutFocus = wf }
        if let we = data["workoutExerciseCount"] as? Int { workoutExerciseCount = we }
        if let wl = data["waterLogged"] as? Int { waterLogged = wl }
        if let wg = data["waterGoal"] as? Int { waterGoal = wg }
        if let walk = data["walkCompleted"] as? Bool { walkCompleted = walk }
    }

    // Required delegate methods
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        #if DEBUG
        print("[Watch] Activation: \(activationState.rawValue)")
        #endif
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
