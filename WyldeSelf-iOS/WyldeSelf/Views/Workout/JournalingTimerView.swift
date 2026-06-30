import SwiftUI

struct JournalingTimerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMinutes: Int = 15
    @State private var remaining: Int = 15 * 60
    @State private var phase: Phase = .setup
    @State private var timer: Timer?
    @State private var isPaused = false

    enum Phase { case setup, active, complete }

    private var progress: CGFloat {
        let total = selectedMinutes * 60
        guard total > 0 else { return 0 }
        return 1.0 - CGFloat(remaining) / CGFloat(total)
    }

    private let accentColor = Color(hex: "C8A96E")

    var body: some View {
        ZStack {
            Color(hex: "070707").ignoresSafeArea()

            // Subtle warm glow
            RadialGradient(
                colors: [accentColor.opacity(0.06), .clear],
                center: .center,
                startRadius: 50,
                endRadius: 300
            )
            .ignoresSafeArea()

            switch phase {
            case .setup: setupView
            case .active: activeView
            case .complete: completeView
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "pencil.line")
                .font(.system(size: 48))
                .foregroundColor(accentColor)

            Text("Journaling")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "F4F1E8"))

            Text("Write what's on your mind.\nWhat you're grateful for.\nWhat you're building.")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "A6A29A"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            // Duration picker
            VStack(spacing: 8) {
                Text("DURATION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "6E6B65"))

                HStack(spacing: 10) {
                    ForEach([10, 15, 20], id: \.self) { mins in
                        Button {
                            selectedMinutes = mins
                            remaining = mins * 60
                        } label: {
                            Text("\(mins)m")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(selectedMinutes == mins ? Color(hex: "070707") : accentColor)
                                .frame(width: 52, height: 40)
                                .background(selectedMinutes == mins ? accentColor : Color(hex: "1A1A1A"))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(.top, 8)

            GoldButton(label: "Begin") {
                remaining = selectedMinutes * 60
                phase = .active
                startTimer()
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)

            Button("Skip") { dismiss() }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "6E6B65"))

            Spacer()
            Spacer()
        }
    }

    // MARK: - Active

    private var activeView: some View {
        VStack(spacing: 0) {
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
            .padding(.top, 12)

            Spacer()

            // Timer
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 4)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 8) {
                    Text(timeString)
                        .font(.system(size: 44, weight: .ultraLight, design: .monospaced))
                        .foregroundColor(Color(hex: "F4F1E8"))
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: remaining)
                    Text("write")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(accentColor.opacity(0.6))
                }
            }

            Spacer().frame(height: 32)

            // Prompt
            Text(journalPrompt)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundColor(Color(hex: "A6A29A"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineSpacing(4)
                .animation(.easeInOut(duration: 0.5), value: remaining / 60)

            Spacer()

            // Controls
            HStack(spacing: 24) {
                Button {
                    isPaused.toggle()
                    if isPaused { timer?.invalidate() }
                    else { startTimer() }
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "F4F1E8"))
                        .frame(width: 50, height: 50)
                        .background(accentColor.opacity(0.15))
                        .clipShape(Circle())
                }

                Button {
                    timer?.invalidate()
                    phase = .complete
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "A6A29A"))
                        .frame(width: 56, height: 40)
                        .background(Color(hex: "1A1A1A"))
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 50)
        }
    }

    // MARK: - Complete

    private var completeView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(hex: "7A8771"))

            Text("Thoughts captured.")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "F4F1E8"))

            Text("Clarity comes from the page, not the screen.")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "A6A29A"))

            GoldButton(label: "Continue") {
                dismiss()
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Timer

    private var timeString: String {
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                if remaining > 0 { remaining -= 1 }
                else {
                    timer?.invalidate()
                    phase = .complete
                }
            }
        }
    }

    // MARK: - Prompts

    private let prompts = [
        "What's on your mind right now?",
        "What are you grateful for today?",
        "What are you building?",
        "What would your future self say to you?",
        "What's one thing you're avoiding?",
        "What did you learn this week?",
        "What does your ideal day look like?",
        "Who do you want to become?",
    ]

    private var journalPrompt: String {
        let elapsed = (selectedMinutes * 60) - remaining
        let index = elapsed / 120 // new prompt every 2 minutes
        return prompts[index % prompts.count]
    }
}
