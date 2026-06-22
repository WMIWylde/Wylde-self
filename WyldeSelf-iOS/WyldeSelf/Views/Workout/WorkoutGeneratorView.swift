import SwiftUI

struct WorkoutGeneratorView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = WorkoutService.shared

    var body: some View {
        ZStack {
            AmbientBackground(
                glowColor: Color(hex: "C8A96E"),
                secondaryGlow: Color(hex: "7A8771")
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer().frame(height: 60)

                    if service.isGenerating {
                        Spacer().frame(height: 80)
                        ProgressView()
                            .tint(Color(hex: "C8A96E"))
                            .scaleEffect(1.3)

                        Text("Building your program...")
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundColor(Color(hex: "F4F1E8"))

                        Text("Analyzing your goals, equipment, and experience")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "A6A29A"))
                            .multilineTextAlignment(.center)
                    } else if service.program == nil {
                        // Header
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 44))
                            .foregroundColor(Color(hex: "C8A96E").opacity(0.6))

                        Text("Choose Your Program")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundColor(Color(hex: "F4F1E8"))

                        Text("Select a training style built for your goals.")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "A6A29A"))
                            .multilineTextAlignment(.center)

                        // Program options
                        VStack(spacing: 12) {
                            programOption(
                                icon: "sparkles",
                                title: "AI-Built Program",
                                subtitle: "Custom split based on your goals, equipment, and schedule.",
                                action: { Task { await service.generateProgram(appState: appState) } }
                            )

                            programOption(
                                icon: "dumbbell.fill",
                                title: "Strength Split",
                                subtitle: "4-day push/pull split. Chest & Tri, Back & Bi, Legs, Shoulders & Arms.",
                                action: {
                                    service.program = service.fallbackProgram(goal: appState.goals.first ?? "Build muscle & strength")
                                }
                            )

                            programOption(
                                icon: "flame.fill",
                                title: "Kettlebell HIIT",
                                subtitle: "Full body. Core-focused. 4 days of kettlebell + high intensity intervals.",
                                accent: Color(hex: "FF9A3C"),
                                action: {
                                    service.program = service.kettlebellHIITProgram()
                                }
                            )
                        }
                        .padding(.top, 8)
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 28)
            }
        }
    }

    private func programOption(icon: String, title: String, subtitle: String, accent: Color = Color(hex: "C8A96E"), action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(accent)
                    .frame(width: 44, height: 44)
                    .background(accent.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "F4F1E8"))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "A6A29A"))
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "6E6B65"))
            }
            .padding(16)
            .background(Color(hex: "111111"))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accent.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
