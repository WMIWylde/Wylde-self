import SwiftUI
import Combine

class AppState: ObservableObject {
    // Tab — not persisted (always start on Today)
    @Published var selectedTab: Tab = .today

    // Auth / profile — persisted
    @Published var isAuthenticated = false                          { didSet { defaults.set(isAuthenticated, forKey: "wylde_authed") } }
    @Published var userName: String = ""                            { didSet { defaults.set(userName, forKey: "wylde_name") } }
    @Published var currentDay: Int = 1                              { didSet { defaults.set(currentDay, forKey: "wylde_day") } }
    @Published var streak: Int = 0                                  { didSet { defaults.set(streak, forKey: "wylde_streak") } }
    // XP is now a silent internal counter — used for analytics + future
    // identity-driven badges, never surfaced as a level/rank.
    @Published var xp: Int = 0                                      { didSet { defaults.set(xp, forKey: "wylde_xp") } }

    // Profile
    @Published var gender: String = "Male"                          { didSet { defaults.set(gender, forKey: "wylde_gender") } }
    @Published var goals: [String] = []                             { didSet { defaults.set(goals, forKey: "wylde_goals") } }
    @Published var gymName: String = ""                             { didSet { defaults.set(gymName, forKey: "wylde_gym") } }

    // Morning Protocol — three fixed practices, persisted as completion flags
    // per day. No more "user picks 3-5" — the protocol IS the practice.
    @Published var morningProtocolActions: [MorningAction] = AppState.defaultMorningActions {
        didSet { saveCodable(morningProtocolActions, key: "wylde_morning_actions") }
    }
    @Published var morningProtocolCompleted: Bool = false           { didSet { defaults.set(morningProtocolCompleted, forKey: "wylde_morning_done") } }

    // Daily long walk — separate from training, mid-day movement
    @Published var dailyWalkCompleted: Bool = false                 { didSet { defaults.set(dailyWalkCompleted, forKey: dayKey("wylde_walk_done")) } }

    // Today — daily state, scoped by day-of-year so it auto-resets at midnight
    @Published var workoutCompleted: Bool = false                   { didSet { defaults.set(workoutCompleted, forKey: dayKey("wylde_workout_done")) } }
    @Published var proteinLogged: Int = 0                           { didSet { defaults.set(proteinLogged, forKey: dayKey("wylde_protein_logged")) } }
    @Published var proteinGoal: Int = 180                           { didSet { defaults.set(proteinGoal, forKey: "wylde_protein_goal") } }
    @Published var caloriesLogged: Int = 0                          { didSet { defaults.set(caloriesLogged, forKey: dayKey("wylde_calories_logged")) } }
    @Published var caloriesGoal: Int = 2400                         { didSet { defaults.set(caloriesGoal, forKey: "wylde_calories_goal") } }

    enum Tab: String, CaseIterable {
        case today = "Today"
        case exercises = "Library"
        case future = "Future"
        case coach = "Coach"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .today: return "house.fill"
            case .exercises: return "figure.strengthtraining.traditional"
            case .future: return "person.fill"
            case .coach: return "bubble.left.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    // MARK: - Default Morning Practices
    // Three fixed practices — meditation, journaling, reading. Workout is
    // not part of morning protocol because it lives in the daily routine.
    static let defaultMorningActions: [MorningAction] = [
        MorningAction(id: "meditation", name: "Meditation", desc: "Sit. Breathe. Notice.", dur: 10),
        MorningAction(id: "journaling", name: "Journaling", desc: "What's on your mind. What you're grateful for. What you're building.", dur: 10),
        MorningAction(id: "reading",    name: "Reading",    desc: "Feed your mind something deliberate.", dur: 15)
    ]

    // MARK: - Persistence

    private let defaults = UserDefaults.standard
    // Suspend didSet writes during the initial load so we don't write the
    // defaults back over themselves (also avoids redundant disk hits).
    private var isLoading = true

    init() {
        loadFromDefaults()
        isLoading = false
    }

    /// Date-scoped key so daily counters reset automatically at midnight
    private func dayKey(_ base: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return base + "_" + f.string(from: Date())
    }

    private func saveCodable<T: Encodable>(_ value: T, key: String) {
        guard !isLoading else { return }
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func loadCodable<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func loadFromDefaults() {
        userName = defaults.string(forKey: "wylde_name") ?? ""
        currentDay = defaults.integer(forKey: "wylde_day")
        if currentDay == 0 { currentDay = 1 }
        streak = defaults.integer(forKey: "wylde_streak")
        xp = defaults.integer(forKey: "wylde_xp")
        gender = defaults.string(forKey: "wylde_gender") ?? "Male"
        goals = defaults.stringArray(forKey: "wylde_goals") ?? []
        gymName = defaults.string(forKey: "wylde_gym") ?? ""

        // Morning protocol — load any persisted state, but reconcile against
        // the canonical 3 practices so old multi-action protocols collapse
        // down to the new shape automatically on next launch.
        let saved = loadCodable([MorningAction].self, key: "wylde_morning_actions") ?? []
        let canonicalIds = Set(AppState.defaultMorningActions.map { $0.id })
        let savedIds = Set(saved.map { $0.id })
        if savedIds == canonicalIds {
            // Same set — keep their completion state
            morningProtocolActions = saved
        } else {
            // Stale set — wipe to canonical defaults
            morningProtocolActions = AppState.defaultMorningActions
        }
        morningProtocolCompleted = defaults.bool(forKey: "wylde_morning_done")

        // Daily walk — date-scoped
        dailyWalkCompleted = defaults.bool(forKey: dayKey("wylde_walk_done"))

        // Daily state — scoped to today, so naturally empty on a fresh day
        workoutCompleted = defaults.bool(forKey: dayKey("wylde_workout_done"))
        proteinLogged = defaults.integer(forKey: dayKey("wylde_protein_logged"))
        caloriesLogged = defaults.integer(forKey: dayKey("wylde_calories_logged"))

        // Goals carry over day-to-day, only reset when user changes them
        let pg = defaults.integer(forKey: "wylde_protein_goal")
        if pg > 0 { proteinGoal = pg }
        let cg = defaults.integer(forKey: "wylde_calories_goal")
        if cg > 0 { caloriesGoal = cg }

        // Auth: prefer explicit flag, fall back to "did the user set a name"
        if defaults.object(forKey: "wylde_authed") != nil {
            isAuthenticated = defaults.bool(forKey: "wylde_authed")
        } else {
            isAuthenticated = !userName.isEmpty
        }
    }

    /// Wipe all persisted state — call from a debug menu or sign-out flow
    func resetAllData() {
        let keys = [
            "wylde_authed", "wylde_name", "wylde_day", "wylde_streak", "wylde_xp",
            "wylde_gender", "wylde_goals", "wylde_gym",
            "wylde_morning_actions", "wylde_morning_done",
            "wylde_protein_goal", "wylde_calories_goal"
        ]
        for k in keys { defaults.removeObject(forKey: k) }
        // Sweep all date-scoped daily keys
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("wylde_workout_done_") ||
               key.hasPrefix("wylde_protein_logged_") ||
               key.hasPrefix("wylde_calories_logged_") ||
               key.hasPrefix("wylde_walk_done_") {
                defaults.removeObject(forKey: key)
            }
        }
        loadFromDefaults()
    }

    /// Silent XP accumulator — used for analytics + future identity-driven
    /// badges, never displayed as a rank. The Ember/Spark/Flame ladder was
    /// stripped because it pulled the brand toward video-game gamification
    /// when the actual point of Wylde Self is transforming your relationship
    /// with yourself.
    func awardXP(_ amount: Int, reason: String) {
        xp += amount  // didSet writes to defaults automatically
        HapticManager.shared.impact(.light)
    }
}

struct MorningAction: Identifiable, Codable {
    let id: String
    let name: String
    let desc: String
    let dur: Int
    var completed: Bool = false
}
