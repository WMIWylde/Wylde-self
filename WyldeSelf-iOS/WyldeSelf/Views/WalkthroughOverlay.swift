import SwiftUI

struct WalkthroughStep {
    let title: String
    let description: String
    let icon: String
    let accent: Color
}

struct WalkthroughOverlay: View {
    @Binding var isShowing: Bool
    @State private var currentStep = 0

    private let steps: [WalkthroughStep] = [
        WalkthroughStep(
            title: "Wylde Score",
            description: "Your daily alignment score. Complete actions throughout the day to build it toward 100.",
            icon: "chart.line.uptrend.xyaxis",
            accent: WyldeStyles.Colors.bronze
        ),
        WalkthroughStep(
            title: "Morning Ritual",
            description: "Energy movement, meditation, journaling, reading. Your non-negotiable morning practice.",
            icon: "sunrise.fill",
            accent: WyldeStyles.Colors.bronze
        ),
        WalkthroughStep(
            title: "Today's Workout",
            description: "AI-built training programs personalized to your goals. Tap to start today's session.",
            icon: "dumbbell.fill",
            accent: WyldeStyles.Colors.vitalTeal
        ),
        WalkthroughStep(
            title: "Daily Walk",
            description: "30 minutes outside. Start the timer or log it done. Movement is medicine.",
            icon: "figure.walk",
            accent: WyldeStyles.Colors.vitalBlue
        ),
        WalkthroughStep(
            title: "Nutrition",
            description: "Scan your meals with a photo. AI estimates your macros instantly. Track protein, carbs, fat, calories.",
            icon: "leaf.fill",
            accent: WyldeStyles.Colors.vitalOrange
        ),
        WalkthroughStep(
            title: "AI Coach",
            description: "Talk to your future self. It knows your goals, your progress, and speaks with quiet certainty.",
            icon: "person.fill",
            accent: WyldeStyles.Colors.bronze
        ),
        WalkthroughStep(
            title: "Future Vision",
            description: "Create a visual representation of the life you're building. See your transformation evolve.",
            icon: "figure.walk.motion",
            accent: WyldeStyles.Colors.vitalPurple
        ),
        WalkthroughStep(
            title: "You",
            description: "Protocols, care team, therapy library, exercise library, and your profile all live here.",
            icon: "person.crop.circle.fill",
            accent: WyldeStyles.Colors.sage
        ),
    ]

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture { nextStep() }

            VStack(spacing: 0) {
                Spacer()

                // Card
                VStack(spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(steps[currentStep].accent.opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: steps[currentStep].icon)
                            .font(.system(size: 28))
                            .foregroundColor(steps[currentStep].accent)
                    }

                    // Title
                    Text(steps[currentStep].title)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(WyldeStyles.Colors.ink)

                    // Description
                    Text(steps[currentStep].description)
                        .font(.system(size: 14))
                        .foregroundColor(WyldeStyles.Colors.stone)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 8)

                    // Progress dots
                    HStack(spacing: 6) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Circle()
                                .fill(i == currentStep ? steps[currentStep].accent : Color.white.opacity(0.15))
                                .frame(width: i == currentStep ? 8 : 6, height: i == currentStep ? 8 : 6)
                                .animation(.easeInOut(duration: 0.2), value: currentStep)
                        }
                    }

                    // Buttons
                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Skip")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(WyldeStyles.Colors.stone)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }

                        Button {
                            nextStep()
                        } label: {
                            Text(currentStep == steps.count - 1 ? "Get Started" : "Next")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(WyldeStyles.Colors.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(steps[currentStep].accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(28)
                .background(WyldeStyles.Colors.bone)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
                .padding(.horizontal, 24)

                Spacer().frame(height: 60)
            }
        }
        .transition(.opacity)
    }

    private func nextStep() {
        if currentStep < steps.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentStep += 1
            }
        } else {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            isShowing = false
        }
        UserDefaults.standard.set(true, forKey: "wylde_walkthrough_seen")
    }
}
