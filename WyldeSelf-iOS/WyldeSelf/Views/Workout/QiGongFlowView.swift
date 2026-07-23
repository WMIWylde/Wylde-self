import SwiftUI

struct QiGongMovement {
    let name: String
    let cue: String
    let duration: Int
    let icon: String
}

/// Guided morning Qi Gong flow — 5-7 minutes of slow, intentional movement.
struct QiGongFlowView: View {
    @Environment(\.dismiss) private var dismiss

    private let movements: [QiGongMovement] = [
        QiGongMovement(name: "Lymphatic Bounce", cue: "Jump lightly up and down. Loose ankles, soft knees. Wake the lymphatic system.", duration: 45, icon: "figure.jumprope"),
        QiGongMovement(name: "Sweep to the Sky", cue: "Hinge over, let the arms hang. Inhale, sweep them wide and up to the sky. Exhale, fold back down.", duration: 50, icon: "figure.arms.open"),
        QiGongMovement(name: "Trunk Twists", cue: "Feet planted, twist the trunk side to side. Let the arms follow loosely.", duration: 45, icon: "figure.flexibility"),
        QiGongMovement(name: "Golf Swings", cue: "Sweep both arms across the body like a slow golf swing. Rotate through the hips. Both directions.", duration: 45, icon: "figure.golf"),
        QiGongMovement(name: "Shoulder Openers", cue: "Right arm rises as the left falls. Alternate in rhythm. Open through the shoulders.", duration: 45, icon: "figure.mixed.cardio"),
        QiGongMovement(name: "Dead Arm Swings", cue: "Arms fully relaxed. Turn the body left and right, letting the arms whip and tap the shoulders.", duration: 45, icon: "figure.walk.motion"),
    ]

    enum Phase { case intro, active, complete }

    @State private var phase: Phase = .intro
    @State private var currentIndex = 0
    @State private var remaining = 0
    @State private var timer: Timer?
    @State private var isPaused = false

    private var current: QiGongMovement { movements[currentIndex] }
    private var progress: CGFloat {
        guard current.duration > 0 else { return 0 }
        return 1.0 - CGFloat(remaining) / CGFloat(current.duration)
    }

    private let accentColor = WyldeStyles.Colors.vitalPurple

    var body: some View {
        ZStack {
            WyldeStyles.Colors.paper.ignoresSafeArea()

            // Soft ambient glow
            RadialGradient(
                colors: [accentColor.opacity(0.10), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            switch phase {
            case .intro: introView
            case .active: activeView
            case .complete: completeView
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "wind")
                .font(.system(size: 48))
                .foregroundColor(accentColor)

            Text("Energy Movement")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)

            Text("7 movements. Slow and intentional.\nWake up the body's energy.")
                .font(.system(size: 15))
                .foregroundColor(WyldeStyles.Colors.stone)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            GoldButton(label: "Begin") {
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
        VStack(spacing: 0) {
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
            .padding(.top, 12)

            Spacer()

            // Timer ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 5)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 8) {
                    Image(systemName: current.icon)
                        .font(.system(size: 32))
                        .foregroundColor(accentColor)

                    Text("\(remaining)")
                        .font(.system(size: 40, weight: .light, design: .monospaced))
                        .foregroundColor(WyldeStyles.Colors.ink)
                }
            }

            Spacer().frame(height: 32)

            Text(current.name)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)

            Text(current.cue)
                .font(.system(size: 14))
                .foregroundColor(WyldeStyles.Colors.stone)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 6)
                .lineSpacing(3)

            if currentIndex < movements.count - 1 {
                Text("Next: \(movements[currentIndex + 1].name)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(WyldeStyles.Colors.stone)
                    .padding(.top, 16)
            }

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
                        .foregroundColor(WyldeStyles.Colors.ink)
                        .frame(width: 50, height: 50)
                        .background(accentColor.opacity(0.15))
                        .clipShape(Circle())
                }

                Button { advanceMovement() } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(WyldeStyles.Colors.stone)
                        .frame(width: 56, height: 40)
                        .background(WyldeStyles.Colors.sand)
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 24)

            // Progress
            HStack(spacing: 4) {
                ForEach(0..<movements.count, id: \.self) { i in
                    Capsule()
                        .fill(i < currentIndex ? accentColor : (i == currentIndex ? accentColor.opacity(0.5) : Color.white.opacity(0.08)))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Complete

    private var completeView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "wind")
                .font(.system(size: 48))
                .foregroundColor(accentColor)

            Text("Energy activated.")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)

            Text("Your body is awake. Your mind is clear.")
                .font(.system(size: 15))
                .foregroundColor(WyldeStyles.Colors.stone)

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

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remaining > 0 { remaining -= 1 }
            else { advanceMovement() }
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
