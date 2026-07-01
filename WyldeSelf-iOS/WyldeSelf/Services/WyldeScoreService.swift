import Foundation

@MainActor
final class WyldeScoreService: ObservableObject {
    static let shared = WyldeScoreService()
    private init() {}

    @Published var todayScore: WyldeScore?
    @Published var scoreHistory: [WyldeScore] = []
    @Published var isLoading = false

    private let baseURL = "https://www.wyldeself.com"

    // MARK: - Calculate and update today's score

    func updateScore(appState: AppState) async {
        guard let token = await AuthService.shared.accessToken else { return }

        let morningActions = appState.morningProtocolActions
        let ritualDone = morningActions.filter(\.completed).count
        let ritualTotal = morningActions.count
        let ritualCompletion = ritualTotal > 0 ? Double(ritualDone) / Double(ritualTotal) : 0

        let workoutDone = appState.workoutCompleted ? 1.0 : 0.0
        let walkDone = appState.dailyWalkCompleted ? 1.0 : 0.0
        let movementCompletion = (workoutDone * 0.7 + walkDone * 0.3)

        let proteinRatio = appState.proteinGoal > 0 ? min(1.0, Double(appState.proteinLogged) / Double(appState.proteinGoal)) : 0
        let calorieRatio = appState.caloriesGoal > 0 ? min(1.0, Double(appState.caloriesLogged) / Double(appState.caloriesGoal)) : 0
        let nutritionCompletion = (proteinRatio * 0.6 + calorieRatio * 0.4)

        // Protocol: check if they have active prescriptions and logged today
        let protocolCompletion = 0.0 // Will be updated when protocol tracker is wired

        // Recovery: placeholder based on walk + not overtraining
        let recoveryCompletion = walkDone * 0.5 + (appState.morningProtocolActions.first(where: { $0.id == "meditation" })?.completed == true ? 0.5 : 0.0)

        // Mindset: journaling + meditation + coach engagement
        let journalingDone = morningActions.first(where: { $0.id == "journaling" })?.completed == true ? 1.0 : 0.0
        let meditationDone = morningActions.first(where: { $0.id == "meditation" })?.completed == true ? 1.0 : 0.0
        let mindsetCompletion = (journalingDone * 0.5 + meditationDone * 0.5)

        let payload: [String: Any] = [
            "ritual_completion": ritualCompletion,
            "movement_completion": movementCompletion,
            "nutrition_completion": nutritionCompletion,
            "protocol_completion": protocolCompletion,
            "recovery_completion": recoveryCompletion,
            "mindset_completion": mindsetCompletion,
        ]

        guard let url = URL(string: "\(baseURL)/api/consumer/wylde-score"),
              let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Resp: Codable { let score: WyldeScore? }
            if let resp = try? JSONDecoder().decode(Resp.self, from: data) {
                todayScore = resp.score
            }
        } catch {
            #if DEBUG
            print("[WyldeScore] Update failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Fetch history

    func fetchHistory(days: Int = 30) async {
        guard let token = await AuthService.shared.accessToken,
              let url = URL(string: "\(baseURL)/api/consumer/wylde-score?range=\(days)") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Resp: Codable { let scores: [WyldeScore] }
            if let resp = try? JSONDecoder().decode(Resp.self, from: data) {
                scoreHistory = resp.scores
            }
        } catch {
            #if DEBUG
            print("[WyldeScore] Fetch failed: \(error.localizedDescription)")
            #endif
        }
    }
}
