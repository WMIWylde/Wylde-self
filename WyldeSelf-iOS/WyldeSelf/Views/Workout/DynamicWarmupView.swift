import SwiftUI
import AVKit
import AudioToolbox

struct WarmupMovement {
    let name: String
    let cue: String
    let duration: Int
    let color: Color
    let icon: String
    let videoURL: URL?
}

struct DynamicWarmupView: View {
    @Environment(\.dismiss) private var dismiss

    private let movements: [WarmupMovement] = [
        WarmupMovement(name: "Arm Circles", cue: "Loosen the shoulders and open the chest.", duration: 30, color: Color(hex: "FF9A3C"), icon: "figure.arms.open", videoURL: URL(string: "https://www.wyldeself.com/warmup-videos/arm-circles.mp4")),
        WarmupMovement(name: "Leg Swings", cue: "Hips first. Let the leg fall and rise like a pendulum.", duration: 30, color: Color(hex: "5EE6D6"), icon: "figure.walk", videoURL: URL(string: "https://www.wyldeself.com/warmup-videos/leg-swings.mp4")),
        WarmupMovement(name: "Hip Openers", cue: "Slow rotations. Breathe into the joint.", duration: 35, color: Color(hex: "B68BFF"), icon: "figure.cooldown", videoURL: URL(string: "https://www.wyldeself.com/warmup-videos/hip-openers.mp4")),
        WarmupMovement(name: "Bodyweight Squats", cue: "Chest tall. Drive the knees out. Light, easy reps.", duration: 40, color: Color(hex: "FF6B8B"), icon: "figure.strengthtraining.functional", videoURL: URL(string: "https://www.wyldeself.com/warmup-videos/bodyweight-squats.mp4")),
        WarmupMovement(name: "Light Jog", cue: "In place. Find your rhythm. Get the blood moving.", duration: 45, color: Color(hex: "7FD0FF"), icon: "figure.run", videoURL: URL(string: "https://www.wyldeself.com/warmup-videos/light-jog.mp4")),
    ]

    enum Phase { case intro, active, complete }

    @State private var phase: Phase = .intro
    @State private var currentIndex = 0
    @State private var remaining = 0
    @State private var timer: Timer?
    @State private var isPaused = false
    @State private var player: AVPlayer?

    private var current: WarmupMovement { movements[currentIndex] }
    private var progress: CGFloat {
        guard current.duration > 0 else { return 0 }
        return 1.0 - CGFloat(remaining) / CGFloat(current.duration)
    }
    private var totalDuration: Int { movements.reduce(0) { $0 + $1.duration } }

    var body: some View {
        ZStack {
            // Background with movement accent color
            WyldeStyles.Colors.paper.ignoresSafeArea()

            if phase != .intro {
                RadialGradient(
                    colors: [current.color.opacity(0.15), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: currentIndex)
            }

            switch phase {
            case .intro:
                introView
            case .active:
                activeView
            case .complete:
                completeView
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "flame.fill")
                .font(.system(size: 48))
                .foregroundColor(WyldeStyles.Colors.bronze)

            Text("Prepare the body")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)

            Text("5 movements. 3 minutes.\nActivate everything.")
                .font(.system(size: 15))
                .foregroundColor(WyldeStyles.Colors.stone)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            GoldButton(label: "Begin Warmup") {
                remaining = movements[0].duration
                phase = .active
                startTimer()
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)

            Button("Skip") { dismiss() }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WyldeStyles.Colors.stone)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Active

    private var activeView: some View {
        ZStack {
            // Video background
            if let player = player {
                FullBleedVideoPlayer(player: player)
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.5))
            }

        VStack(spacing: 0) {
            // Close
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "A6A29A"))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            // Timer ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 6)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(current.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 8) {
                    Image(systemName: current.icon)
                        .font(.system(size: 36))
                        .foregroundColor(current.color)

                    Text("\(remaining)")
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "F4F1E8"))
                }
            }

            Spacer().frame(height: 32)

            // Movement info
            Text(current.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "F4F1E8"))

            Text(current.cue)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "A6A29A"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 6)

            // Next up
            if currentIndex < movements.count - 1 {
                Text("Next: \(movements[currentIndex + 1].name)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "A6A29A"))
                    .padding(.top, 16)
            }

            Spacer()

            // Controls
            HStack(spacing: 24) {
                Button {
                    remaining = min(remaining + 15, current.duration + 15)
                } label: {
                    Text("+15s")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "A6A29A"))
                        .frame(width: 56, height: 40)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Capsule())
                }

                Button {
                    isPaused.toggle()
                    if isPaused { timer?.invalidate() }
                    else { startTimer() }
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "F4F1E8"))
                        .frame(width: 56, height: 56)
                        .background(current.color.opacity(0.2))
                        .clipShape(Circle())
                }

                Button {
                    advanceMovement()
                } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "A6A29A"))
                        .frame(width: 56, height: 40)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 24)

            // Progress segments
            HStack(spacing: 6) {
                ForEach(0..<movements.count, id: \.self) { i in
                    Capsule()
                        .fill(i < currentIndex ? current.color : (i == currentIndex ? current.color.opacity(0.5) : Color.white.opacity(0.08)))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        } // close ZStack
        .onChange(of: currentIndex) { loadVideo() }
        .onAppear { loadVideo() }
    }

    private func loadVideo() {
        guard phase == .active, let url = current.videoURL else { return }
        let newPlayer = AVPlayer(url: url)
        newPlayer.isMuted = true
        newPlayer.play()
        // Loop the video
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: newPlayer.currentItem, queue: .main) { _ in
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }
        self.player = newPlayer
    }

    // MARK: - Complete

    private var completeView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(WyldeStyles.Colors.sage)

            Text("Body activated.")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)

            Text("Let's train.")
                .font(.system(size: 15))
                .foregroundColor(WyldeStyles.Colors.stone)

            GoldButton(label: "Start Workout") {
                dismiss()
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remaining > 0 {
                remaining -= 1
                if remaining <= 3 && remaining > 0 {
                    AudioServicesPlaySystemSound(1057)
                }
                if remaining == 0 {
                    AudioServicesPlaySystemSound(1025)
                }
            } else {
                advanceMovement()
            }
        }
    }

    private func advanceMovement() {
        timer?.invalidate()
        if currentIndex < movements.count - 1 {
            currentIndex += 1
            remaining = movements[currentIndex].duration
            startTimer()
        } else {
            phase = .complete
        }
    }
}
