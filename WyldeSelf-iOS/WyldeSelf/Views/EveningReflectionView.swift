import SwiftUI

struct EveningReflectionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var whatHappened = ""
    @State private var whatSupported = ""
    @State private var whatBlocked = ""
    @State private var aiReflection: String?
    @State private var isReflecting = false
    @State private var step = 0

    var body: some View {
        ZStack {
            Color(hex: "070707").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "A6A29A"))
                            .frame(width: 36, height: 36)
                            .background(Color(hex: "111111"))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("EVENING REFLECTION")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2.5)
                                .foregroundColor(Color(hex: "C8A96E"))

                            Text("Close the day with clarity.")
                                .font(.system(size: 24, weight: .bold, design: .serif))
                                .foregroundColor(Color(hex: "F4F1E8"))
                        }

                        // Today's summary
                        todaySummary

                        if step == 0 {
                            questionCard(
                                prompt: "What happened today?",
                                hint: "What did you do, skip, or change from the plan?",
                                text: $whatHappened,
                                onNext: { step = 1 }
                            )
                        } else if step == 1 {
                            questionCard(
                                prompt: "What supported you?",
                                hint: "What made it easier to follow through?",
                                text: $whatSupported,
                                onNext: { step = 2 }
                            )
                        } else if step == 2 {
                            questionCard(
                                prompt: "What got in the way?",
                                hint: "No judgment. Just name it.",
                                text: $whatBlocked,
                                onNext: { Task { await generateReflection() } }
                            )
                        } else if step == 3 {
                            // AI reflection
                            if isReflecting {
                                VStack(spacing: 16) {
                                    ProgressView().tint(Color(hex: "C8A96E"))
                                    Text("Reflecting...")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "A6A29A"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else if let reflection = aiReflection {
                                reflectionCard(reflection)
                            }
                        }

                        Spacer().frame(height: 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Today's Summary

    private var todaySummary: some View {
        let ritualDone = appState.morningProtocolActions.filter(\.completed).count
        let ritualTotal = appState.morningProtocolActions.count

        return HStack(spacing: 16) {
            summaryPill(icon: "sunrise.fill", label: "Ritual", value: "\(ritualDone)/\(ritualTotal)", color: Color(hex: "C8A96E"))
            summaryPill(icon: "dumbbell.fill", label: "Workout", value: appState.workoutCompleted ? "Done" : "Skipped", color: appState.workoutCompleted ? Color(hex: "5EE6D6") : Color(hex: "6E6B65"))
            summaryPill(icon: "figure.walk", label: "Walk", value: appState.dailyWalkCompleted ? "Done" : "Skipped", color: appState.dailyWalkCompleted ? Color(hex: "7FD0FF") : Color(hex: "6E6B65"))
            summaryPill(icon: "fork.knife", label: "Nutrition", value: "\(appState.caloriesLogged) cal", color: Color(hex: "FF9A3C"))
        }
        .padding(14)
        .background(Color(hex: "111111"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func summaryPill(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "F4F1E8"))
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Color(hex: "6E6B65"))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Question Card

    private func questionCard(prompt: String, hint: String, text: Binding<String>, onNext: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(prompt)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "F4F1E8"))

            Text(hint)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "6E6B65"))

            TextField("", text: text, axis: .vertical)
                .lineLimit(3...8)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "F4F1E8"))
                .padding(14)
                .background(Color(hex: "111111"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "F4F1E8").opacity(0.06), lineWidth: 1)
                )
                .tint(Color(hex: "C8A96E"))

            Button(action: onNext) {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1816"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "E6C886"), Color(hex: "A6834A")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Reflection Card

    private func reflectionCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "C8A96E"))
                Text("YOUR REFLECTION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "C8A96E"))
            }

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "F4F1E8"))
                .lineSpacing(4)

            Button {
                saveReflection()
                dismiss()
            } label: {
                Text("Close the day")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1816"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "E6C886"), Color(hex: "A6834A")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(18)
        .background(Color(hex: "111111"))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "C8A96E").opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - AI Reflection

    private func generateReflection() async {
        step = 3
        isReflecting = true

        guard let url = URL(string: "https://www.wyldeself.com/api/openai") else {
            aiReflection = fallbackReflection()
            isReflecting = false
            return
        }

        let ritualDone = appState.morningProtocolActions.filter(\.completed).count
        let ritualTotal = appState.morningProtocolActions.count
        let context = """
        User's day: Ritual \(ritualDone)/\(ritualTotal), Workout \(appState.workoutCompleted ? "done" : "skipped"), Walk \(appState.dailyWalkCompleted ? "done" : "skipped"), \(appState.caloriesLogged) calories logged.
        Day \(appState.currentDay) of their transformation.
        What happened: \(whatHappened)
        What supported them: \(whatSupported)
        What got in the way: \(whatBlocked)
        """

        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "max_tokens": 300,
            "messages": [
                ["role": "system", "content": "You are the user's future self — warm, direct, non-shaming, identity-focused. Reflect on their day in 3-4 sentences. Acknowledge what they did. If they missed something, treat it as data, not failure. Name one pattern you see. Connect today to the person they're becoming. End with one small thing for tomorrow. Never guilt. Never lecture."],
                ["role": "user", "content": context]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await AuthService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 20
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Resp: Codable { let choices: [Choice]?; struct Choice: Codable { let message: Msg? }; struct Msg: Codable { let content: String? } }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            aiReflection = resp.choices?.first?.message?.content ?? fallbackReflection()
        } catch {
            aiReflection = fallbackReflection()
        }

        isReflecting = false
    }

    private func fallbackReflection() -> String {
        let did = [
            appState.workoutCompleted ? "your workout" : nil,
            appState.dailyWalkCompleted ? "your walk" : nil,
            appState.morningProtocolActions.filter(\.completed).count > 0 ? "your morning ritual" : nil
        ].compactMap { $0 }

        if did.isEmpty {
            return "Today was quiet — and that's allowed. The person you're becoming doesn't need every day to be perfect. They need to keep showing up. Tomorrow is a fresh start."
        }
        return "You showed up today with \(did.joined(separator: " and ")). That's the person you said you'd become — doing the work even when it's not easy. Keep building on that momentum tomorrow."
    }

    private func saveReflection() {
        let key = "wylde_reflection_\(dayKey())"
        let data: [String: String] = [
            "whatHappened": whatHappened,
            "whatSupported": whatSupported,
            "whatBlocked": whatBlocked,
            "aiReflection": aiReflection ?? ""
        ]
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
        appState.eveningReflectionDone = true
        // Record today as a "closed" day for the N-of-M progress meter
        // shown in the Today hero and You profile chip. Idempotent —
        // re-submitting the reflection today is a no-op.
        appState.markLoopClosed()
    }

    private func dayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
