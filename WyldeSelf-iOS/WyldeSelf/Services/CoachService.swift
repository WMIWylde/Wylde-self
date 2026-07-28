import Foundation
import SwiftUI

@MainActor
final class CoachService: ObservableObject {
    static let shared = CoachService()
    private init() { loadHistory() }

    @Published var messages: [CoachMessage] = []
    /// A coach-authored opener (daily check-in question) queued before the
    /// chat opens. CoachChatView consumes it on appear.
    @Published var pendingOpener: String?

    func consumePendingOpener() {
        guard let opener = pendingOpener else { return }
        pendingOpener = nil
        messages.append(CoachMessage(role: .assistant, content: opener))
        saveHistory()
    }
    @Published var isTyping = false

    private let historyKey = "wylde_coach_chat"
    private let maxHistory = 30
    private let secure = SecureStorage.shared

    // MARK: - Send Message

    func send(_ text: String, appState: AppState) async {
        let userMsg = CoachMessage(role: .user, content: text)
        messages.append(userMsg)
        saveHistory()
        isTyping = true

        do {
            let response = try await callAPI(userMessage: text, appState: appState)
            let aiMsg = CoachMessage(role: .assistant, content: response)
            messages.append(aiMsg)
            saveHistory()
        } catch {
            let errMsg = CoachMessage(role: .assistant, content: "Connection lost. I'm still here — try again.")
            messages.append(errMsg)
            saveHistory()
        }

        isTyping = false
    }

    // MARK: - Quick Actions

    func quickAction(_ action: String, appState: AppState) async {
        await send(action, appState: appState)
    }

    // MARK: - Daily check-in

    /// One personalized opening question in the future-self voice.
    /// Returns nil on any failure — caller falls back to a rotation.
    func generateCheckinQuestion(appState: AppState) async -> String? {
        guard let url = URL(string: "https://www.wyldeself.com/api/anthropic") else { return nil }
        let context = """
        Day \(appState.currentDay) of their program. Streak: \(appState.streak) days. \
        Goals: \(appState.goals.joined(separator: ", ")). \
        Identity statement: \(appState.identityStatement.isEmpty ? "UNKNOWN" : appState.identityStatement). \
        Typical sleep: \(appState.sleepBaseline.isEmpty ? "UNKNOWN" : appState.sleepBaseline). \
        Stress: \(appState.stressBaseline.isEmpty ? "UNKNOWN" : appState.stressBaseline). \
        Energy: \(appState.energyBaseline.isEmpty ? "UNKNOWN" : appState.energyBaseline). \
        Biggest obstacle: \(appState.biggestObstacle.isEmpty ? "UNKNOWN" : appState.biggestObstacle). \
        Workout done today: \(appState.workoutCompleted ? "yes" : "not yet"). \
        Name: \(appState.userName.isEmpty ? "unknown" : appState.userName).
        """
        let payload: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 120,
            "system": "You are the user's future self (Wylde coach voice: calm, direct, warm, no hype, no emojis, no exclamation points). Write ONE opening line for today's check-in. PRIORITY: if any field below reads UNKNOWN, ask about ONE of them conversationally (never like a form — like their future self who wants to know). Otherwise ask a question that deepens your understanding of who they are or moves their becoming forward, referencing their real data. One or two sentences max. End with a question mark. Their data: " + context,
            "messages": [["role": "user", "content": "Write today's check-in question."]],
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await AuthService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 15
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Resp: Codable { struct C: Codable { let text: String? }; let content: [C]? }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            let text = resp.content?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (text?.isEmpty == false && text!.count < 300) ? text : nil
        } catch { return nil }
    }

    // MARK: - API

    private func callAPI(userMessage: String, appState: AppState) async throws -> String {
        guard let url = URL(string: "https://www.wyldeself.com/api/openai") else {
            throw CoachError.invalidURL
        }

        let systemPrompt = buildSystemPrompt(appState: appState)
        var conversationMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        let recentHistory = messages.suffix(8).map { ["role": $0.role.rawValue, "content": $0.content] }
        conversationMessages.append(contentsOf: recentHistory)
        conversationMessages.append(["role": "user", "content": userMessage])

        let payload: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 800,
            "temperature": 0.8,
            "messages": conversationMessages
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await AuthService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CoachError.apiFailed
        }

        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return result.choices?.first?.message?.content ?? "I'm here. Say more."
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(appState: AppState) -> String {
        let name = appState.userName.isEmpty ? nil : appState.userName
        let gender = appState.gender.isEmpty ? "unspecified" : appState.gender.lowercased()

        let nameBlock: String
        if let n = name {
            nameBlock = "The user is named \(n). You are literally a future version of \(n), speaking back through time. Speak from that frame."
        } else {
            nameBlock = "You don't know the user's name yet. Speak as their future self — calm, grounded, knowing."
        }

        let identityPhrase: String
        switch gender {
        case "male": identityPhrase = "the man you're becoming"
        case "female": identityPhrase = "the woman you're becoming"
        default: identityPhrase = "the version of you you're becoming"
        }

        let contextBlock = buildContextBlock(appState: appState)

        return """
        You are the Wylde Coach. You are not a generic AI assistant. You speak as the user's FUTURE SELF — the version of them that has already done the work, walked the path, and built the identity they're reaching for. \(nameBlock) You are calm, grounded, direct. Strong but not aggressive. Warm but never soft. You don't cheerlead, you don't lecture, you don't therapize. You speak like someone who remembers what it was like to be where they are now — and knows what comes next.

        FORMAT — hard rules:
        • 2–4 sentences default. Never write paragraphs unless they explicitly ask for depth.
        • No bullet lists unless they ask for steps. Plain sentences.
        • No "As your AI coach" or "I'm here to help" or any meta-talk about being an assistant. You are them, talking back through time.
        • No hedging ("I think you might want to consider..."). Speak with quiet certainty.
        • No emojis. No exclamation points unless something genuinely warrants it.
        • Occasionally weave in a single light science callout. Never lecture. One line, then back to action.

        \(contextBlock)

        You are NOT a medical or mental health professional. If someone describes an injury, pregnancy, or medical condition, tell them to see a doctor. If you notice signs of disordered eating, self-harm, or severe restriction, gently suggest professional help — never diagnose. Never shame or guilt anyone about food choices or missed workouts.

        They are becoming \(identityPhrase). Remind them of that identity — not with hype, but with quiet certainty.

        QUICK ACTIONS — if the user sends one of these exact phrases:
        • "Motivate me" → Remind them WHO they're becoming, not what to do. Short. Identity-driven.
        • "Fix my plan" → Name ONE thing to adjust this week. Specific. No menus.
        • "I'm off track" → No shame. One line. Then the smallest next action.
        • "Optimize everything" → Name their biggest leak and one lever to pull.
        """
    }

    private func buildContextBlock(appState: AppState) -> String {
        var lines: [String] = ["── USER CONTEXT ──"]

        if !appState.userName.isEmpty { lines.append("Name: \(appState.userName)") }
        if !appState.gender.isEmpty { lines.append("Gender: \(appState.gender)") }
        if !appState.identityStatement.isEmpty {
            lines.append("Identity: \"\(appState.identityStatement)\" — this is who they are becoming. Weave this into your responses. Reference it when they need motivation or when celebrating follow-through.")
        }
        if !appState.fitnessLevel.isEmpty { lines.append("Level: \(appState.fitnessLevel)") }
        if !appState.goals.isEmpty { lines.append("Goals: \(appState.goals.joined(separator: ", "))") }
        if !appState.trainingDays.isEmpty { lines.append("Training: \(appState.trainingDays)/week") }

        lines.append("Day: \(appState.currentDay) (\(appState.completedDays) closed out of \(appState.currentDay) started)")
        lines.append("Streak: \(appState.streak) days")

        // Today's state
        lines.append("")
        lines.append("── TODAY ──")
        lines.append("Workout: \(appState.workoutCompleted ? "Done" : "Not yet")")
        lines.append("Walk: \(appState.dailyWalkCompleted ? "Done" : "Not yet")")
        lines.append("Morning ritual: \(appState.morningProtocolCompleted ? "Complete" : "\(appState.morningProtocolActions.filter(\.completed).count)/\(appState.morningProtocolActions.count) done")")
        if appState.proteinLogged > 0 {
            lines.append("Protein: \(appState.proteinLogged)g / \(appState.proteinGoal)g goal")
        }

        if !appState.healthConcerns.isEmpty {
            lines.append("")
            lines.append("Health concerns: \(appState.healthConcerns.joined(separator: ", "))")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Persistence

    private func saveHistory() {
        let toSave = Array(messages.suffix(maxHistory))
        secure.setCodable(toSave, forKey: historyKey)
    }

    private func loadHistory() {
        // Try Keychain first, fall back to UserDefaults for migration
        if let saved = secure.getCodable([CoachMessage].self, forKey: historyKey) {
            messages = saved
        } else if let data = UserDefaults.standard.data(forKey: historyKey),
                  let saved = try? JSONDecoder().decode([CoachMessage].self, from: data) {
            messages = saved
            // Migrate: save to Keychain and remove from UserDefaults
            secure.setCodable(saved, forKey: historyKey)
            UserDefaults.standard.removeObject(forKey: historyKey)
        }
    }

    func clearHistory() {
        messages = []
        secure.remove(forKey: historyKey)
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    // MARK: - Types

    enum CoachError: LocalizedError {
        case invalidURL, apiFailed
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL"
            case .apiFailed: return "Coach connection failed"
            }
        }
    }

    private struct OpenAIResponse: Codable {
        let choices: [Choice]?
        struct Choice: Codable {
            let message: Message?
        }
        struct Message: Codable {
            let content: String?
        }
    }
}

struct CoachMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    enum Role: String, Codable {
        case user, assistant
    }

    init(role: Role, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}
