import SwiftUI
import Speech
import AVFoundation

/// Voice/text input → AI generates a structured workout from the user's description.
struct DescribeWorkoutView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = WorkoutService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var description = ""
    @State private var isRecording = false
    @State private var speechAuthorized = false
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()

    private let placeholders = [
        "45-minute leg day with dumbbells, focus on hamstrings",
        "Quick 30-min upper body, I only have resistance bands",
        "Full body HIIT, no equipment, 40 minutes",
        "Heavy back and biceps day at the gym",
        "Shoulder and core workout with kettlebells",
    ]

    @State private var currentPlaceholder = ""

    var body: some View {
        ZStack {
            WyldeStyles.Colors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
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
                    VStack(spacing: 24) {
                        Spacer().frame(height: 20)

                        Image(systemName: "mic.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(WyldeStyles.Colors.gold.opacity(0.6))

                        Text("Describe Your Workout")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundColor(WyldeStyles.Colors.ink)

                        Text("Tell us what you want to do.\nWe'll build a workout you can follow.")
                            .font(.system(size: 14))
                            .foregroundColor(WyldeStyles.Colors.stone)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)

                        // Text input
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text(currentPlaceholder)
                                        .font(.system(size: 16))
                                        .foregroundColor(WyldeStyles.Colors.stone.opacity(0.5))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                }

                                TextEditor(text: $description)
                                    .font(.system(size: 16))
                                    .foregroundColor(WyldeStyles.Colors.ink)
                                    .scrollContentBackground(.hidden)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(minHeight: 100, maxHeight: 160)
                            }
                            .background(WyldeStyles.Colors.bone)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isRecording ? WyldeStyles.Colors.gold.opacity(0.5) : WyldeStyles.Colors.charcoal.opacity(0.12), lineWidth: 1.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                            // Voice input button
                            HStack(spacing: 12) {
                                Button {
                                    if isRecording { stopRecording() } else { startRecording() }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                                            .font(.system(size: 14))
                                        Text(isRecording ? "Stop Recording" : "Use Voice")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(isRecording ? .red : WyldeStyles.Colors.gold)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(isRecording ? Color.red.opacity(0.08) : WyldeStyles.Colors.gold.opacity(0.08))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(isRecording ? Color.red.opacity(0.3) : WyldeStyles.Colors.gold.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)

                                if isRecording {
                                    HStack(spacing: 4) {
                                        Circle().fill(Color.red).frame(width: 6, height: 6)
                                        Text("Listening...")
                                            .font(.system(size: 12))
                                            .foregroundColor(.red)
                                    }
                                }

                                Spacer()
                            }
                        }
                        .padding(.horizontal, 20)

                        // Generate button
                        Button {
                            let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !text.isEmpty else { return }
                            stopRecording()
                            Task { await service.generateFromDescription(text, appState: appState) }
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14))
                                Text("Generate Workout")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundColor(WyldeStyles.Colors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? [WyldeStyles.Colors.stone.opacity(0.3), WyldeStyles.Colors.stone.opacity(0.2)]
                                        : [WyldeStyles.Colors.gold, Color(hex: "A6834A")],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(.horizontal, 20)

                        // Examples
                        VStack(alignment: .leading, spacing: 10) {
                            Text("EXAMPLES")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(WyldeStyles.Colors.stone)

                            ForEach(placeholders, id: \.self) { example in
                                Button {
                                    description = example
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "text.quote")
                                            .font(.system(size: 12))
                                            .foregroundColor(WyldeStyles.Colors.bronze.opacity(0.5))
                                        Text(example)
                                            .font(.system(size: 13))
                                            .foregroundColor(WyldeStyles.Colors.ink)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(WyldeStyles.Colors.bone)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer().frame(height: 40)
                    }
                }
            }
        }
        .onAppear {
            currentPlaceholder = placeholders.randomElement() ?? placeholders[0]
            requestSpeechAuth()
        }
        .onDisappear { stopRecording() }
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
                description = result.bestTranscription.formattedString
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
}
