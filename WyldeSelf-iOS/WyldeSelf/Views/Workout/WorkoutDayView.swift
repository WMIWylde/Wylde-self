import SwiftUI

struct WorkoutDayView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = WorkoutService.shared
    @Environment(\.dismiss) private var dismiss

    let dayIndex: Int
    @State private var showRestTimer = false
    @State private var restDuration = 90
    @State private var showWarmup = false

    private var day: WorkoutDay? {
        service.program?.days.indices.contains(dayIndex) == true ? service.program?.days[dayIndex] : nil
    }

    var body: some View {
        ZStack {
            Color(hex: "070707").ignoresSafeArea()

            if let day = day {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        header(day)

                        // Progress
                        if day.totalSets > 0 {
                            GlowingProgressBar(progress: CGFloat(day.completedSets) / CGFloat(day.totalSets))
                                .padding(.horizontal, 4)
                        }

                        // Exercise cards
                        ForEach(Array(day.exercises.enumerated()), id: \.element.id) { exIndex, exercise in
                            ExerciseCard(
                                exercise: exercise,
                                dayIndex: dayIndex,
                                exerciseIndex: exIndex,
                                pr: service.pr(for: exercise.name),
                                gender: appState.gender,
                                fitnessLevel: appState.fitnessLevel,
                                onSetLogged: { setIndex, weight, reps in
                                    service.logSet(dayIndex: dayIndex, exerciseIndex: exIndex, setIndex: setIndex, weight: weight, reps: Int(reps))
                                },
                                onWarmupTap: {
                                    showWarmup = true
                                },
                                onRestNeeded: {
                                    restDuration = exercise.isCompound ? 90 : 60
                                    showRestTimer = true
                                }
                            )
                        }

                        // Complete Workout button
                        if !appState.workoutCompleted {
                            GoldButton(label: "Complete Workout") {
                                HapticManager.shared.notification(.success)
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    appState.workoutCompleted = true
                                }
                                dismiss()
                            }
                            .padding(.top, 8)
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }

            // Rest timer overlay
            if showRestTimer {
                RestTimerView(duration: restDuration) {
                    showRestTimer = false
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .fullScreenCover(isPresented: $showWarmup) {
            DynamicWarmupView()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(hex: "F4F1E8"))
                }
            }
        }
    }

    private func header(_ day: WorkoutDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DAY \(day.dayNumber)")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(Color(hex: "C8A96E"))

            Text(day.focus)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "F4F1E8"))

            Text("\(day.exercises.count) exercises")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "A6A29A"))
        }
        .padding(.bottom, 8)
    }
}
