import SwiftUI
import AVFoundation

/// Guided visualization meditation — timer with optional audio.
/// Audio file placeholder: when you create the guided meditation audio,
/// add it to the bundle as "guided-meditation.m4a" or stream from URL.
struct GuidedMeditationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .intro
    @State private var remaining: Int = 600  // 10 minutes default
    @State private var totalDuration: Int = 600
    @State private var timer: Timer?
    @State private var isPaused = false
    @State private var breathScale: CGFloat = 1.0
    @State private var glowRadius: CGFloat = 20
    @State private var glowOpacity: Double = 0.3
    @State private var audioPlayer: AVAudioPlayer?

    enum Phase { case intro, active, complete }

    private var progress: CGFloat {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - CGFloat(remaining) / CGFloat(totalDuration)
    }

    private let accentColor = Color(hex: "5EE6D6")

    var body: some View {
        ZStack {
            Color(hex: "070707").ignoresSafeArea()

            switch phase {
            case .intro: introView
            case .active: activeView
            case .complete: completeView
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            timer?.invalidate()
            audioPlayer?.stop()
        }
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(accentColor)

            Text("Guided Meditation")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "F4F1E8"))

            Text("Close your eyes. Visualize the version\nof yourself you're becoming.")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "A6A29A"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Text("10 minutes · guided audio")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(accentColor.opacity(0.6))
                .padding(.top, 8)

            GoldButton(label: "Begin") {
                phase = .active
                startTimer()
                startBreathingAnimation()
                tryPlayAudio()
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

    private func durationButton(minutes: Int) -> some View {
        let isSelected = totalDuration == minutes * 60
        return Button {
            totalDuration = minutes * 60
            remaining = minutes * 60
        } label: {
            Text("\(minutes)m")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? Color(hex: "070707") : accentColor)
                .frame(width: 48, height: 36)
                .background(isSelected ? accentColor : Color(hex: "1A1A1A"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
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

            // Glowing silhouette
            ZStack {
                // Outer glow — expands and contracts with breath
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accentColor.opacity(glowOpacity * 0.4), accentColor.opacity(glowOpacity * 0.15), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 320)
                    .scaleEffect(breathScale)

                // Inner glow — tighter, brighter
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accentColor.opacity(glowOpacity * 0.6), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(breathScale * 0.95)

                // Silhouette figure — meditating person
                Image(systemName: "figure.mind.and.body")
                    .font(.system(size: 80, weight: .ultraLight))
                    .foregroundColor(accentColor.opacity(0.7))
                    .scaleEffect(breathScale * 0.98)

                // Time overlay
                VStack(spacing: 4) {
                    Spacer()
                    Text(timeString)
                        .font(.system(size: 28, weight: .ultraLight, design: .monospaced))
                        .foregroundColor(Color(hex: "F4F1E8").opacity(0.6))

                    // Progress arc — thin, subtle
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                }
                .frame(height: 320)
                .padding(.bottom, 20)
            }

            Spacer().frame(height: 24)

            // Visualization prompts — rotate through
            Text(visualizationPrompt)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundColor(Color(hex: "A6A29A"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineSpacing(4)
                .animation(.easeInOut(duration: 1), value: remaining / 30)

            Spacer()

            // Controls
            HStack(spacing: 24) {
                Button {
                    isPaused.toggle()
                    if isPaused {
                        timer?.invalidate()
                        audioPlayer?.pause()
                    } else {
                        startTimer()
                        audioPlayer?.play()
                    }
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
                    remaining = 0
                    phase = .complete
                } label: {
                    Text("End")
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
                .foregroundColor(accentColor)

            Text("Mind clear.")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "F4F1E8"))

            Text("Carry this stillness into your day.")
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
            if remaining > 0 { remaining -= 1 }
            else {
                timer?.invalidate()
                audioPlayer?.stop()
                phase = .complete
            }
        }
    }

    private func startBreathingAnimation() {
        // Inhale: 4 seconds expand, Exhale: 4 seconds contract
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            breathScale = 1.15
            glowRadius = 40
            glowOpacity = 0.6
        }
    }

    private func tryPlayAudio() {
        // Try bundled audio first
        if let url = Bundle.main.url(forResource: "guided-meditation", withExtension: "m4a") {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        }
        // TODO: Add remote URL streaming when meditation audio is ready
    }

    // MARK: - Visualization Prompts

    private let prompts = [
        "See yourself one year from now.\nWhat does your morning look like?",
        "Picture the space you live in.\nEvery detail is intentional.",
        "Feel the strength in your body.\nYou earned this through discipline.",
        "See the people around you.\nThey respect who you've become.",
        "Your mind is quiet.\nYou trust yourself to handle anything.",
        "This version of you exists.\nYou're building the bridge to get there.",
        "Breathe in possibility.\nBreathe out doubt.",
        "You are not wishing.\nYou are becoming.",
    ]

    private var visualizationPrompt: String {
        let index = (totalDuration - remaining) / 30
        return prompts[index % prompts.count]
    }
}
