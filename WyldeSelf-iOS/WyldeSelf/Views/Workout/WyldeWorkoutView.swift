import SwiftUI
import Speech
import AVFoundation

/// Freeform "Wylde Workout" — do whatever you want, record it with voice,
/// AI summarizes and logs it to your training history.
struct WyldeWorkoutView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var isActive = false
    @State private var elapsed = 0
    @State private var timer: Timer?

    // Voice recording
    @State private var isRecording = false
    @State private var transcribedText = ""
    @State private var voiceNotes: [String] = []
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var speechAuthorized = false

    // Summary
    @State private var showSummary = false
    @State private var aiSummary: String?
    @State private var isParsing = false
    @State private var parsedExercises: [ParsedExercise] = []

    struct ParsedExercise: Identifiable, Codable {
        var id: String { name }
        let name: String
        let sets: String?
        let notes: String?
    }

    var body: some View {
        ZStack {
            WyldeStyles.Colors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(WyldeStyles.Colors.ink)
                    }
                    Spacer()
                    if isActive {
                        HStack(spacing: 4) {
                            Circle().fill(Color.red).frame(width: 6, height: 6)
                            Text(formatTime(elapsed))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(WyldeStyles.Colors.bronze)
                        }
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(WyldeStyles.Colors.stone)
                            .frame(width: 36, height: 36)
                            .background(WyldeStyles.Colors.bone)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if !isActive && !showSummary {
                            preWorkout
                        } else if isActive {
                            activeWorkout
                        } else if showSummary {
                            summaryView
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { requestSpeechAuth() }
        .onDisappear { stopRecording(); timer?.invalidate() }
    }

    // MARK: - Pre-Workout

    private var preWorkout: some View {
        VStack(spacing: 24) {
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 44))
                .foregroundColor(WyldeStyles.Colors.bronze.opacity(0.6))

            Text("Wylde Workout")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)

            Text("No plan. No rules. Just move.\nRecord what you did with voice notes.")
                .font(.system(size: 14))
                .foregroundColor(WyldeStyles.Colors.stone)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button {
                startWorkout()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                    Text("Start Wylde Workout")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(WyldeStyles.Colors.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [WyldeStyles.Colors.gold, Color(hex: "A6834A")],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 40)
    }

    // MARK: - Active Workout

    private var activeWorkout: some View {
        VStack(spacing: 20) {
            // Timer
            Text(formatTime(elapsed))
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(WyldeStyles.Colors.bronze)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: elapsed)

            Text("WYLDE WORKOUT")
                .font(.system(size: 10, weight: .bold))
                .tracking(2.5)
                .foregroundColor(WyldeStyles.Colors.stone)

            // Voice recording button
            VStack(spacing: 12) {
                Button {
                    if isRecording { finishVoiceNote() } else { startRecording() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red.opacity(0.15) : WyldeStyles.Colors.bronze.opacity(0.10))
                            .frame(width: 80, height: 80)

                        if isRecording {
                            Circle()
                                .stroke(Color.red.opacity(0.4), lineWidth: 3)
                                .frame(width: 80, height: 80)
                                .scaleEffect(isRecording ? 1.15 : 1.0)
                                .opacity(isRecording ? 0.5 : 1)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isRecording)
                        }

                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 28))
                            .foregroundColor(isRecording ? .red : WyldeStyles.Colors.bronze)
                    }
                }
                .buttonStyle(.plain)

                Text(isRecording ? "Recording... tap to save" : (speechAuthorized ? "Tap to record what you did" : "Mic access needed"))
                    .font(.system(size: 13))
                    .foregroundColor(isRecording ? .red : WyldeStyles.Colors.stone)
            }

            // Live transcription
            if !transcribedText.isEmpty && isRecording {
                Text(transcribedText)
                    .font(.system(size: 14))
                    .foregroundColor(WyldeStyles.Colors.ink)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(WyldeStyles.Colors.bone)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Logged voice notes
            if !voiceNotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LOGGED")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(WyldeStyles.Colors.stone)

                    ForEach(voiceNotes.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(WyldeStyles.Colors.bronze)
                                .frame(width: 20, height: 20)
                                .background(WyldeStyles.Colors.bronze.opacity(0.12))
                                .clipShape(Circle())
                            Text(voiceNotes[i])
                                .font(.system(size: 13))
                                .foregroundColor(WyldeStyles.Colors.ink)
                                .lineLimit(3)
                        }
                        .padding(12)
                        .background(WyldeStyles.Colors.bone)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            Spacer().frame(height: 20)

            // End workout
            Button {
                endWorkout()
            } label: {
                Text("End Workout")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Summary

    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Stats
            HStack(spacing: 0) {
                statPill("Duration", formatTime(elapsed))
                statPill("Notes", "\(voiceNotes.count)")
                statPill("Exercises", "\(parsedExercises.count)")
            }
            .padding(14)
            .background(WyldeStyles.Colors.bone)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if isParsing {
                VStack(spacing: 12) {
                    ProgressView().tint(WyldeStyles.Colors.bronze)
                    Text("Summarizing your workout...")
                        .font(.system(size: 14))
                        .foregroundColor(WyldeStyles.Colors.stone)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else if let summary = aiSummary {
                // AI Summary
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(WyldeStyles.Colors.bronze)
                        Text("WORKOUT SUMMARY")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(WyldeStyles.Colors.bronze)
                    }

                    Text(summary)
                        .font(.system(size: 14))
                        .foregroundColor(WyldeStyles.Colors.ink)
                        .lineSpacing(3)
                }
                .padding(16)
                .background(WyldeStyles.Colors.bone)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(WyldeStyles.Colors.bronze.opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Parsed exercises
                if !parsedExercises.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EXERCISES DETECTED")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(WyldeStyles.Colors.stone)

                        ForEach(parsedExercises) { ex in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(WyldeStyles.Colors.bronze.opacity(0.15))
                                    .frame(width: 8, height: 8)
                                Text(ex.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(WyldeStyles.Colors.ink)
                                Spacer()
                                if let sets = ex.sets {
                                    Text(sets)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(WyldeStyles.Colors.stone)
                                }
                            }
                        }
                    }
                }
            }

            // Log it
            Button {
                logWorkout()
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Log Wylde Workout")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(WyldeStyles.Colors.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [WyldeStyles.Colors.gold, Color(hex: "A6834A")],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
    }

    private func statPill(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(WyldeStyles.Colors.bronze)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(WyldeStyles.Colors.stone)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Workout Control

    private func startWorkout() {
        isActive = true
        elapsed = 0
        HealthKitManager.shared.startWorkoutSession()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async { elapsed += 1 }
        }
        HapticManager.shared.impact(.medium)
    }

    private func endWorkout() {
        timer?.invalidate()
        timer = nil
        isActive = false
        stopRecording()
        Task { await HealthKitManager.shared.endWorkoutSession() }
        showSummary = true
        HapticManager.shared.notification(.success)

        if !voiceNotes.isEmpty {
            Task { await generateSummary() }
        }
    }

    private func logWorkout() {
        appState.workoutCompleted = true

        // Save freeform workout to UserDefaults history
        let entry: [String: Any] = [
            "type": "wylde",
            "date": ISO8601DateFormatter().string(from: Date()),
            "duration": elapsed,
            "notes": voiceNotes,
            "summary": aiSummary ?? "",
            "exercises": parsedExercises.map { $0.name }
        ]
        var history = UserDefaults.standard.array(forKey: "wylde_workout_history") as? [[String: Any]] ?? []
        history.append(entry)
        UserDefaults.standard.set(history, forKey: "wylde_workout_history")
    }

    // MARK: - Speech Recognition

    private func requestSpeechAuth() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async { speechAuthorized = status == .authorized }
        }
    }

    private func startRecording() {
        guard speechAuthorized, let recognizer = speechRecognizer, recognizer.isAvailable else { return }

        recognitionTask?.cancel()
        recognitionTask = nil
        transcribedText = ""

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { return }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result = result {
                transcribedText = result.bestTranscription.formattedString
            }
            if error != nil || (result?.isFinal ?? false) {
                stopRecording()
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest?.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            HapticManager.shared.impact(.medium)
        } catch {}
    }

    private func finishVoiceNote() {
        stopRecording()
        let note = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            voiceNotes.append(note)
            HapticManager.shared.notification(.success)
        }
        transcribedText = ""
    }

    private func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
    }

    // MARK: - AI Summary

    private func generateSummary() async {
        isParsing = true

        guard let url = URL(string: "https://www.wyldeself.com/api/openai") else {
            aiSummary = voiceNotes.joined(separator: ". ")
            isParsing = false
            return
        }

        let combined = voiceNotes.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        let prompt = """
        The user just finished a freeform workout (\(elapsed / 60) minutes). They recorded these voice notes during the session:

        \(combined)

        Do two things:
        1. Write a 2-3 sentence summary of the workout in second person ("You did..."). Be specific about what they did. Encouraging but not over the top.
        2. Extract a JSON array of exercises they mentioned.

        Return ONLY valid JSON:
        {
          "summary": "You hit a solid upper body session...",
          "exercises": [
            {"name": "Bench Press", "sets": "3 × 10", "notes": null},
            {"name": "Pull-ups", "sets": "4 × 8", "notes": "bodyweight"}
          ]
        }
        """

        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "max_tokens": 500,
            "messages": [
                ["role": "system", "content": "You are a concise workout summarizer. Return only valid JSON."],
                ["role": "user", "content": prompt]
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

            struct AIResp: Codable { let choices: [Choice]?; struct Choice: Codable { let message: Msg? }; struct Msg: Codable { let content: String? } }
            let aiResp = try JSONDecoder().decode(AIResp.self, from: data)
            guard let content = aiResp.choices?.first?.message?.content else {
                aiSummary = voiceNotes.joined(separator: ". ")
                isParsing = false
                return
            }

            // Parse the JSON
            guard let jsonStart = content.firstIndex(of: "{"),
                  let jsonEnd = content.lastIndex(of: "}") else {
                aiSummary = content
                isParsing = false
                return
            }

            struct SummaryResp: Codable {
                let summary: String?
                let exercises: [ParsedExercise]?
            }

            let jsonData = Data(String(content[jsonStart...jsonEnd]).utf8)
            let parsed = try JSONDecoder().decode(SummaryResp.self, from: jsonData)
            aiSummary = parsed.summary ?? voiceNotes.joined(separator: ". ")
            parsedExercises = parsed.exercises ?? []
        } catch {
            aiSummary = voiceNotes.joined(separator: ". ")
        }

        isParsing = false
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
