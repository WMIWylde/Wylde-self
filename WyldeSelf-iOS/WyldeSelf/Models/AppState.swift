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
    @Published var xp: Int = 0                                      { didSet { defaults.set(xp, forKey: "wylde_xp") } }
    @Published var level: String = "Ember"                          { didSet { defaults.set(level, forKey: "wylde_level") } }

    // Profile
    @Published var gender: String = "Male"                          { didSet { defaults.set(gender, forKey: "wylde_gender") } }
    @Published var goals: [String] = []                             { didSet { defaults.set(goals, forKey: "wylde_goals") } }
    @Published var gymName: String = ""                             { didSet { defaults.set(gymName, forKey: "wylde_gym") } }

    // Morning Protocol — encoded as JSON
    @Published var morningProtocolActions: [MorningAction] = []     { didSet { saveCodable(morningProtocolActions, key: "wylde_morning_actions") } }
    @Published var morningProtocolCompleted: Bool = false           { didSet { defaults.set(morningProtocolCompleted, forKey: "wylde_morning_done") } }

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
        case optimize = "Optimize"

        var icon: String {
            switch self {
            case .today: return "house.fill"
            case .exercises: return "figure.strengthtraining.traditional"
            case .future: return "person.fill"
            case .coach: return "bubble.left.fill"
            case .optimize: return "waveform.path.ecg"
            }
        }
    }

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
        level = defaults.string(forKey: "wylde_level") ?? "Ember"
        gender = defaults.string(forKey: "wylde_gender") ?? "Male"
        goals = defaults.stringArray(forKey: "wylde_goals") ?? []
        gymName = defaults.string(forKey: "wylde_gym") ?? ""

        // Morning protocol
        morningProtocolActions = loadCodable([MorningAction].self, key: "wylde_morning_actions") ?? []
        morningProtocolCompleted = defaults.bool(forKey: "wylde_morning_done")

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
            "wylde_level", "wylde_gender", "wylde_goals", "wylde_gym",
            "wylde_morning_actions", "wylde_morning_done",
            "wylde_protein_goal", "wylde_calories_goal"
        ]
        for k in keys { defaults.removeObject(forKey: k) }
        // Sweep all date-scoped daily keys
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("wylde_workout_done_") ||
               key.hasPrefix("wylde_protein_logged_") ||
               key.hasPrefix("wylde_calories_logged_") {
                defaults.removeObject(forKey: key)
            }
        }
        loadFromDefaults()
    }

    func awardXP(_ amount: Int, reason: String) {
        xp += amount  // didSet writes to defaults automatically
        HapticManager.shared.impact(.light)

        // Level thresholds
        let levels: [(String, Int)] = [
            ("Ember", 0), ("Spark", 200), ("Flame", 500),
            ("Blaze", 1000), ("Inferno", 2000), ("Forge", 4000),
            ("Titan", 8000), ("Legend", 15000)
        ]
        for (name, threshold) in levels.reversed() {
            if xp >= threshold {
                if level != name {
                    level = name  // didSet persists
                    HapticManager.shared.notification(.success)
                }
                break
            }
        }
    }
}

struct MorningAction: Identifiable, Codable {
    let id: String
    let name: String
    let desc: String
    let dur: Int
    var completed: Bool = false
}
