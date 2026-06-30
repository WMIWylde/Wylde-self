import SwiftUI
import AudioToolbox

struct RestTimerView: View {
    let duration: Int  // seconds
    var onComplete: (() -> Void)?

    @State private var remaining: Int
    @State private var isRunning = true
    @State private var timer: Timer?

    init(duration: Int, onComplete: (() -> Void)? = nil) {
        self.duration = duration
        self.onComplete = onComplete
        self._remaining = State(initialValue: duration)
    }

    private var progress: CGFloat {
        1.0 - CGFloat(remaining) / CGFloat(duration)
    }

    private var isFinishing: Bool { remaining <= 10 && remaining > 0 }
    private var isDone: Bool { remaining <= 0 }

    private var ringColor: Color {
        if isDone { return Color(hex: "7A8771") }
        if isFinishing { return Color(hex: "FF9A3C") }
        return Color(hex: "C8A96E")
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Status
                Text(isDone ? "Go!" : isFinishing ? "Get Ready" : "Rest")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(ringColor)

                // Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 6)
                        .frame(width: 180, height: 180)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)

                    VStack(spacing: 4) {
                        Text(timeString)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "F4F1E8"))
                        Text("seconds")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "6E6B65"))
                    }
                }

                // Skip
                if !isDone {
                    Button("Skip") {
                        remaining = 0
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "A6A29A"))
                }
            }
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
        .onChange(of: remaining) {
            // Countdown sounds
            if remaining <= 3 && remaining > 0 {
                AudioServicesPlaySystemSound(1057) // tick
            }
            if remaining <= 0 {
                AudioServicesPlaySystemSound(1025) // completion chime
                HapticManager.shared.notification(.success)
                timer?.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    onComplete?()
                }
            }
        }
    }

    private var timeString: String {
        let m = remaining / 60
        let s = remaining % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : "\(s)"
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remaining > 0 { remaining -= 1 }
        }
    }
}
