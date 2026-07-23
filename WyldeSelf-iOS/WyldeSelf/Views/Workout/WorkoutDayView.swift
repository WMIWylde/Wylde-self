import SwiftUI

struct WorkoutDayView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = WorkoutService.shared
    @Environment(\.dismiss) private var dismiss

    let dayIndex: Int
    @State private var showRestTimer = false
    @State private var restDuration = 90
    @State private var showWarmup = false
    @State private var workoutSessionActive = false
    @StateObject private var workoutClock = BackgroundTimer(persistKey: "wylde_workout_start")

    private var day: WorkoutDay? {
        service.program?.days.indices.contains(dayIndex) == true ? service.program?.days[dayIndex] : nil
    }

    var body: some View {
        ZStack {
            Theme.appBG.ignoresSafeArea()

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

                        // Workout timer + complete button
                        if !appState.workoutCompleted {
                            VStack(spacing: 12) {
                                // Live workout timer
                                if workoutSessionActive {
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                        Text("WORKOUT ACTIVE")
                                            .font(.system(size: 10, weight: .bold))
                                            .tracking(2)
                                            .foregroundColor(Theme.primaryText)
                                        Spacer()
                                        Text(formatElapsed(workoutClock.elapsed))
                                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                                            .foregroundColor(WyldeStyles.Colors.bronze)
                                            .contentTransition(.numericText())
                                            .animation(.easeInOut(duration: 0.3), value: workoutClock.elapsed)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Theme.elevatedBG)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                GoldButton(label: "Complete Workout") {
                                    HapticManager.shared.notification(.success)
                                    let _ = workoutClock.stop()
                                    workoutSessionActive = false
                                    Task { await HealthKitManager.shared.endWorkoutSession() }
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        appState.workoutCompleted = true
                                    }
                                    dismiss()
                                }
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    // If workout is active and user goes back, keep session running
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Theme.primaryText)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if workoutSessionActive {
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text(formatElapsed(workoutClock.elapsed))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(WyldeStyles.Colors.bronze)
                    }
                }
            }
        }
        .onAppear {
            if !appState.workoutCompleted && !workoutSessionActive {
                HealthKitManager.shared.startWorkoutSession()
                workoutSessionActive = true
                workoutClock.start()
            }
        }
        .task {
            await WorkoutLogSync.shared.refreshHistory()
        }
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func header(_ day: WorkoutDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DAY \(day.dayNumber)")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(WyldeStyles.Colors.bronze)

            Text(day.focus)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(Theme.primaryText)

            Text("\(day.exercises.count) exercises")
                .font(.system(size: 13))
                .foregroundColor(Theme.secondaryText)
        }
        .padding(.bottom, 8)
    }
}
