import SwiftUI
import Speech
import AVFoundation

struct VoiceFoodLogView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var tracker = MacroTrackerService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMealType: MealType = .lunch
    @State private var transcribedText = ""
    @State private var isRecording = false
    @State private var isParsing = false
    @State private var parsedMeals: [ParsedFoodItem] = []
    @State private var totalMacros: ParsedTotal?
    @State private var errorText: String?
    @State private var showResult = false
    @State private var manualText = ""

    // Speech recognition
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var speechAuthorized = false

    var body: some View {
        ZStack {
            Color(hex: "070707").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("VOICE LOG")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(Color(hex: "C8A96E"))
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

                // Meal type
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Button { selectedMealType = type } label: {
                                Text(type.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(selectedMealType == type ? Color(hex: "070707") : Color(hex: "A6A29A"))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(selectedMealType == type ? Color(hex: "C8A96E") : Color(hex: "1A1A1A"))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 14)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if !showResult {
                            inputSection
                        } else {
                            resultSection
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
        .onDisappear { stopRecording() }
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(spacing: 24) {
            // Mic button
            VStack(spacing: 16) {
                Button {
                    if isRecording { stopRecording() } else { startRecording() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red.opacity(0.15) : Color(hex: "C8A96E").opacity(0.10))
                            .frame(width: 100, height: 100)

                        if isRecording {
                            Circle()
                                .stroke(Color.red.opacity(0.4), lineWidth: 3)
                                .frame(width: 100, height: 100)
                                .scaleEffect(isRecording ? 1.15 : 1.0)
                                .opacity(isRecording ? 0.5 : 1)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isRecording)
                        }

                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(isRecording ? .red : Color(hex: "C8A96E"))
                    }
                }
                .buttonStyle(.plain)

                Text(isRecording ? "Listening..." : (speechAuthorized ? "Tap to speak" : "Microphone access needed"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isRecording ? .red : Color(hex: "A6A29A"))

                if !speechAuthorized {
                    Text("Go to Settings → Wylde Self → Speech Recognition")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "6E6B65"))
                }
            }

            // Transcribed text preview
            if !transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("I HEARD:")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "A6A29A"))

                    Text(transcribedText)
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "F4F1E8"))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Or type manually
            VStack(alignment: .leading, spacing: 8) {
                Text("OR TYPE IT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "A6A29A"))

                HStack(spacing: 8) {
                    TextField("e.g. 2 eggs, toast with butter, black coffee", text: $manualText, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "F4F1E8"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(hex: "111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "F4F1E8").opacity(0.06), lineWidth: 1)
                        )
                        .tint(Color(hex: "C8A96E"))
                }
            }

            // Parse button
            let inputText = !transcribedText.isEmpty ? transcribedText : manualText
            if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    Task { await parseFood(inputText) }
                } label: {
                    HStack(spacing: 8) {
                        if isParsing {
                            ProgressView().tint(Color(hex: "1A1816")).scaleEffect(0.8)
                        }
                        Text(isParsing ? "Calculating macros..." : "Calculate Macros")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "1A1816"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "E6C886"), Color(hex: "A6834A")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
                }
                .disabled(isParsing)
                .buttonStyle(.plain)
            }

            if let error = errorText {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "C26B5A"))
            }
        }
    }

    // MARK: - Result

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Total macros
            if let total = totalMacros {
                VStack(spacing: 12) {
                    Text("TOTAL")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "A6A29A"))

                    HStack(spacing: 0) {
                        macroStat("Calories", "\(total.calories)", Color(hex: "C8A96E"))
                        macroStat("Protein", "\(total.protein)g", Color(hex: "5EE6D6"))
                        macroStat("Carbs", "\(total.carbs)g", Color(hex: "FF9A3C"))
                        macroStat("Fat", "\(total.fat)g", Color(hex: "B68BFF"))
                    }
                }
                .padding(16)
                .background(Color(hex: "111111"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Individual items
            Text("BREAKDOWN")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(Color(hex: "A6A29A"))

            ForEach(parsedMeals) { item in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "F4F1E8"))
                        if let qty = item.quantity {
                            Text(qty)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "6E6B65"))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(item.calories)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "C8A96E"))
                        Text("\(item.protein)g P")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "5EE6D6"))
                    }
                }
                .padding(14)
                .background(Color(hex: "111111"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Actions
            HStack(spacing: 12) {
                Button {
                    showResult = false
                    parsedMeals = []
                    totalMacros = nil
                    transcribedText = ""
                    manualText = ""
                } label: {
                    Text("Redo")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "A6A29A"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "111111"))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "F4F1E8").opacity(0.06), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button { logAll() } label: {
                    Text("Log \(selectedMealType.rawValue)")
                        .font(.system(size: 14, weight: .bold))
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
                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.top, 8)
        }
    }

    private func macroStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "A6A29A"))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Speech Recognition

    private func requestSpeechAuth() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                speechAuthorized = status == .authorized
            }
        }
    }

    private func startRecording() {
        guard speechAuthorized, let recognizer = speechRecognizer, recognizer.isAvailable else { return }

        recognitionTask?.cancel()
        recognitionTask = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            #if DEBUG
            print("[VoiceLog] Audio session error: \(error)")
            #endif
            return
        }

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
        } catch {
            #if DEBUG
            print("[VoiceLog] Engine error: \(error)")
            #endif
        }
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

    // MARK: - Parse

    private func parseFood(_ text: String) async {
        isParsing = true
        errorText = nil

        defer { isParsing = false }

        guard let url = URL(string: "https://www.wyldeself.com/api/nutrition/parse") else {
            errorText = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await AuthService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 30

        let payload: [String: String] = ["text": text]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard httpCode == 200 else {
                errorText = "Could not parse food (error \(httpCode))"
                return
            }

            let result = try JSONDecoder().decode(ParseResponse.self, from: data)
            parsedMeals = result.meals
            totalMacros = result.total
            showResult = true
            HapticManager.shared.notification(.success)
        } catch {
            #if DEBUG
            print("[VoiceLog] Parse error: \(error)")
            #endif
            errorText = "Failed to analyze food. Try again."
        }
    }

    // MARK: - Log

    private func logAll() {
        guard let total = totalMacros else { return }

        let itemNames = parsedMeals.map { $0.name }
        let description = itemNames.joined(separator: ", ")

        let analysis = FoodAnalysis(
            description: description,
            calories: total.calories,
            protein: total.protein,
            carbs: total.carbs,
            fat: total.fat,
            items: parsedMeals.map { FoodAnalysis.FoodItem(name: $0.name, calories: $0.calories, protein: $0.protein, carbs: $0.carbs, fat: $0.fat) }
        )

        tracker.addMeal(name: description, analysis: analysis, mealType: selectedMealType)
        appState.proteinLogged = tracker.totalProtein
        appState.caloriesLogged = tracker.totalCalories
        appState.carbsLogged = tracker.totalCarbs
        appState.fatLogged = tracker.totalFat
        HapticManager.shared.notification(.success)
        dismiss()
    }
}

// MARK: - Models

struct ParsedFoodItem: Identifiable, Codable {
    var id: String { name + String(calories) }
    let name: String
    let quantity: String?
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
}

struct ParsedTotal: Codable {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
}

struct ParseResponse: Codable {
    let meals: [ParsedFoodItem]
    let total: ParsedTotal
}
