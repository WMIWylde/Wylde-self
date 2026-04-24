import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var selectedTab: Tab = .today
    @Published var isAuthenticated = false
    @Published var userName: String = ""
    @Published var currentDay: Int = 1
    @Published var streak: Int = 0
    @Published var xp: Int = 0
    @Published var level: String = "Ember"

    // Profile
    @Published var gender: String = "Male"
    @Published var goals: [String] = []
    @Published var gymName: String = ""

    // Morning Protocol
    @Published var morningProtocolActions: [MorningAction] = []
    @Published var morningProtocolCompleted: Bool = false

    // Today
    @Published var workoutCompleted: Bool = false
    @Published var proteinLogged: Int = 0
    @Published var proteinGoal: Int = 180
    @Published var caloriesLogged: Int = 0
    @Published var caloriesGoal: Int = 2400

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

    init() {
        loadFromDefaults()
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
        isAuthenticated = !userName.isEmpty
    }

    func awardXP(_ amount: Int, reason: String) {
        xp += amount
        defaults.set(xp, forKey: "wylde_xp")
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
                    level = name
                    defaults.set(level, forKey: "wylde_level")
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
