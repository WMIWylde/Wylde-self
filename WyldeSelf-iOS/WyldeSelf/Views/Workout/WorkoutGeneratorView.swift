import SwiftUI
import Speech

struct WorkoutGeneratorView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = WorkoutService.shared
    @State private var showEquipmentPicker = false
    @State private var showWyldeWorkout = false
    @State private var showDescribeWorkout = false
    @State private var pendingAction: ((Set<String>) -> Void)?

    var body: some View {
        ZStack {
            AmbientBackground(
                glowColor: WyldeStyles.Colors.bronze,
                secondaryGlow: WyldeStyles.Colors.sage
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer().frame(height: 60)

                    if service.isGenerating {
                        Spacer().frame(height: 80)
                        ProgressView()
                            .tint(WyldeStyles.Colors.bronze)
                            .scaleEffect(1.3)

                        Text("Building your program...")
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundColor(WyldeStyles.Colors.ink)

                        Text("Analyzing your goals, equipment, and experience")
                            .font(.system(size: 13))
                            .foregroundColor(WyldeStyles.Colors.stone)
                            .multilineTextAlignment(.center)
                    } else if service.program == nil {
                        // Header
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 44))
                            .foregroundColor(WyldeStyles.Colors.bronze.opacity(0.6))

                        Text("Choose Your Program")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundColor(WyldeStyles.Colors.ink)

                        Text("Select a training style, then pick your equipment.")
                            .font(.system(size: 14))
                            .foregroundColor(WyldeStyles.Colors.stone)
                            .multilineTextAlignment(.center)

                        // Program options
                        VStack(spacing: 12) {
                            // Wylde Workout — freeform with voice logging
                            programOption(
                                icon: "bolt.heart.fill",
                                title: "Wylde Workout",
                                subtitle: "No plan. Just move. Record what you did with voice notes.",
                                accent: Color(hex: "FF6B6B"),
                                action: { showWyldeWorkout = true }
                            )

                            // Describe Your Workout — voice/text → AI generates it
                            programOption(
                                icon: "mic.badge.plus",
                                title: "Describe Your Workout",
                                subtitle: "Tell us what you want to do. We'll build it for you.",
                                accent: WyldeStyles.Colors.gold,
                                action: { showDescribeWorkout = true }
                            )

                            // Training style — shapes the AI program's entire structure
                            VStack(alignment: .leading, spacing: 8) {
                                Text("TRAINING STYLE")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(2)
                                    .foregroundColor(WyldeStyles.Colors.stone)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(["Strength", "Hypertrophy", "Kettlebell & Dynamic", "HIIT", "Longevity"], id: \.self) { style in
                                            Button {
                                                appState.trainingStyle = (appState.trainingStyle == style) ? "" : style
                                            } label: {
                                                Text(style)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(appState.trainingStyle == style ? WyldeStyles.Colors.paper : WyldeStyles.Colors.ink)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 8)
                                                    .background(appState.trainingStyle == style ? WyldeStyles.Colors.ink : WyldeStyles.Colors.bone)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)

                            programOption(
                                icon: "sparkles",
                                title: "AI-Built Program",
                                subtitle: "Custom split based on your goals, equipment, and schedule.",
                                action: {
                                    pendingAction = { equipment in
                                        Task { await service.generateProgram(appState: appState, equipment: equipment) }
                                    }
                                    showEquipmentPicker = true
                                }
                            )

                            programOption(
                                icon: "figure.walk",
                                title: "Bodyweight Only",
                                subtitle: "No equipment needed. Push-ups, pull-ups, squats, HIIT. Train anywhere.",
                                accent: WyldeStyles.Colors.vitalTeal,
                                action: {
                                    service.sessionEquipment = ["bodyweight"]
                                    service.program = service.bodyweightProgram()
                                }
                            )

                            programOption(
                                icon: "dumbbell.fill",
                                title: "Gym Strength Split",
                                subtitle: "4-day push/pull split. Chest & Tri, Back & Bi, Legs, Shoulders & Arms.",
                                action: {
                                    service.sessionEquipment = ["bodyweight", "dumbbells", "barbell", "bench", "cables", "machines"]
                                    service.program = service.fallbackProgram(goal: appState.goals.first ?? "Build muscle & strength")
                                }
                            )

                            programOption(
                                icon: "flame.fill",
                                title: "Kettlebell HIIT",
                                subtitle: "Full body. Core-focused. 4 days of kettlebell + high intensity intervals.",
                                accent: WyldeStyles.Colors.vitalOrange,
                                action: {
                                    service.sessionEquipment = ["bodyweight", "kettlebell"]
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
        .fullScreenCover(isPresented: $showWyldeWorkout) {
            WyldeWorkoutView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showDescribeWorkout) {
            DescribeWorkoutView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showEquipmentPicker) {
            EquipmentPickerView { equipment in
                pendingAction?(equipment)
                pendingAction = nil
            }
            .environmentObject(appState)
        }
    }

    private func programOption(icon: String, title: String, subtitle: String, accent: Color = WyldeStyles.Colors.bronze, action: @escaping () -> Void) -> some View {
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
                        .foregroundColor(WyldeStyles.Colors.ink)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(WyldeStyles.Colors.stone)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(WyldeStyles.Colors.stone)
            }
            .padding(16)
            .background(Theme.elevatedBG)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accent.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
