import SwiftUI

// MARK: - Persistence

/// Step state for StartTodayFlow. Persisted to UserDefaults under the
/// same key (`wylde_stf_state`) the web app uses, so the user can move
/// between web and iOS during a single day and resume at the same step.
@MainActor
final class StartTodayFlowState: ObservableObject {
    @Published var step: Int = 1

    private let storageKey = "wylde_stf_state"
    static let totalSteps = 6

    init() { load() }

    func load() {
        let today = Self.todayKey()
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let saved = try? JSONDecoder().decode(SavedState.self, from: data)
        else {
            step = 1
            return
        }
        // New day → reset to step 1
        if saved.date != today {
            step = 1
            save()
        } else {
            step = max(1, min(Self.totalSteps, saved.step))
        }
    }

    func save() {
        let saved = SavedState(date: Self.todayKey(), step: step)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func next() {
        guard step < Self.totalSteps else { return }
        step += 1
        save()
    }

    func back() {
        guard step > 1 else { return }
        step -= 1
        save()
    }

    static func todayKey() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private struct SavedState: Codable {
        let date: String
        let step: Int
    }
}

// MARK: - Main flow view

struct StartTodayFlow: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @StateObject private var flow = StartTodayFlowState()
    @ObservedObject private var workoutService = WorkoutService.shared

    @State private var showQiGong = false
    @State private var showMeditation = false
    @State private var showJournaling = false
    @State private var showWorkout = false
    @State private var showFoodSearch = false
    @State private var showFoodScanner = false
    @State private var showMealPlan = false
    @State private var showCoach = false

    // Step 6 final-state visibility — once Close-the-Loop fires we replace
    // the checks with a calm completion message until the user dismisses.
    @State private var showFinal = false

    var body: some View {
        VStack(spacing: 0) {
            header
            progressBar
            ScrollView {
                stepContent
                    .padding(.horizontal, 22)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            footer
        }
        .background(Theme.surface)
        .onAppear {
            flow.load()
            let today = StartTodayFlowState.todayKey()
            if let last = UserDefaults.standard.string(forKey: "wylde_last_completed_day"),
               last == today {
                flow.step = StartTodayFlowState.totalSteps
                showFinal = true
            }
        }
        .fullScreenCover(isPresented: $showQiGong) {
            QiGongFlowView()
        }
        .fullScreenCover(isPresented: $showMeditation) {
            GuidedMeditationView()
        }
        .fullScreenCover(isPresented: $showJournaling) {
            JournalingTimerView()
        }
        .fullScreenCover(isPresented: $showWorkout) {
            WorkoutContainerView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showFoodSearch) {
            NavigationStack { FoodSearchView() }
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showFoodScanner) {
            NavigationStack { FoodScannerView() }
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showMealPlan) {
            NavigationStack { MealPlanView() }
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showCoach) {
            CoachChatView()
                .environmentObject(appState)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button {
                HapticManager.shared.impact(.light)
                flow.back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(flow.step > 1 ? Theme.text3 : Theme.muted.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.04)))
            }
            .buttonStyle(.plain)
            .disabled(flow.step <= 1)

            Spacer()
            Text("Step \(flow.step) of \(StartTodayFlowState.totalSteps)")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.6)
                .foregroundColor(Theme.muted)
            Spacer()

            Button {
                HapticManager.shared.impact(.light)
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.text3)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.04)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    // MARK: Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.black.opacity(0.04))
                Rectangle()
                    .fill(Theme.gold)
                    .frame(
                        width: geo.size.width *
                            CGFloat(flow.step - 1) /
                            CGFloat(StartTodayFlowState.totalSteps - 1)
                    )
                    .animation(.easeOut(duration: 0.3), value: flow.step)
            }
        }
        .frame(height: 2)
    }

    // MARK: Step content

    @ViewBuilder
    private var stepContent: some View {
        switch flow.step {
        case 1: anchorStep
        case 2: ritualStep
        case 3: trainingStep
        case 4: nutritionStep
        case 5: futureSelfStep
        case 6: closeoutStep
        default: EmptyView()
        }
    }

    // MARK: Footer (Skip + Primary)

    private var footer: some View {
        HStack(spacing: 10) {
            if showSkip {
                Button {
                    HapticManager.shared.impact(.light)
                    flow.next()
                } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(Theme.text3)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            Button(action: handlePrimary) {
                Text(primaryLabel)
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12).fill(Theme.gold)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        // max() so the home-indicator safe area doesn't eat the buttons
        .padding(.bottom, 18)
        .background(
            Theme.surface
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.border).frame(height: 1)
                }
        )
    }

    private var showSkip: Bool {
        // Hide skip on the anchor (step 1) and the closeout (step 6) —
        // matches web behavior. Visible on every other step.
        flow.step != 1 && flow.step != 6
    }

    private var primaryLabel: String {
        switch flow.step {
        case 1: return "Begin"
        case 2: return "Continue"
        case 3: return "Start Training"
        case 4: return "Continue"
        case 5: return "Continue"
        case 6: return showFinal ? "Done" : "Close the Loop"
        default: return "Continue"
        }
    }

    private func handlePrimary() {
        HapticManager.shared.impact(.light)
        switch flow.step {
        case 3:
            // Training — dismiss flow and open the native workout
            isPresented = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(
                    name: .navigateToScreen,
                    object: nil,
                    userInfo: ["screen": "workout"]
                )
            }
        case 6:
            if showFinal {
                isPresented = false
                return
            }
            completeDay()
            HapticManager.shared.notification(.success)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                showFinal = true
            }
        default:
            flow.next()
        }
    }

    // MARK: - Step 1: Identity Anchor

    private var anchorStep: some View {
        let phase = JourneyPhase.forDay(appState.currentDay)
        let day = appState.currentDay
        let identity = appState.identityStatement.isEmpty ? nil : appState.identityStatement

        return VStack(alignment: .leading, spacing: 14) {
            eyebrow("Day \(day) \u{00B7} \(phase.name)")

            if let identity = identity {
                // Personalized anchor — tied to their identity
                Text("I am becoming")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.muted)
                Text(identity)
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundColor(Theme.text)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
                Text("Today\u{2019}s actions are evidence of that.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.muted)
            } else {
                // Fallback for users without identity statement
                let titles = [
                    "Today sets the standard.",
                    "One clear day. One honest step.",
                    "Quiet work. Real progress.",
                    "Show up. Follow through."
                ]
                Text(titles[day % titles.count])
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Keep it simple: ritual, training, fuel, follow-through.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.muted)
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Step 2: Morning Ritual

    private var ritualStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrow("Morning Ritual")
            Text("Start the day on purpose.")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Theme.text)
            Text("Check off each action. Keep it light. Keep it real.")
                .font(.system(size: 14))
                .foregroundColor(Theme.muted)
                .padding(.bottom, 14)

            ForEach(Array(appState.morningProtocolActions.enumerated()), id: \.element.id) { idx, action in
                ritualRow(idx: idx, action: action)
            }
        }
    }

    private func ritualRow(idx: Int, action: MorningAction) -> some View {
        HStack(spacing: 12) {
            // Checkbox
            ZStack {
                Circle()
                    .fill(action.completed ? Theme.sage : Color.clear)
                    .frame(width: 22, height: 22)
                Circle()
                    .stroke(action.completed ? Theme.sage : Theme.border.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                if action.completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.onAccent)
                }
            }
            .onTapGesture {
                HapticManager.shared.impact(.light)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    appState.morningProtocolActions[idx].completed.toggle()
                }
                if appState.morningProtocolActions.allSatisfy({ $0.completed }) {
                    HapticManager.shared.notification(.success)
                    appState.morningProtocolCompleted = true
                    appState.awardXP(25, reason: "Morning Protocol complete")
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(action.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(action.completed ? Theme.muted : Theme.text)
                    .strikethrough(action.completed, color: Theme.muted)
                Text(action.desc)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }

            Spacer()

            // Launch button for activities that have a dedicated screen
            if !action.completed, let icon = ritualLaunchIcon(action.id) {
                Button {
                    launchRitualActivity(action.id, idx: idx)
                } label: {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.gold)
                        .frame(width: 34, height: 34)
                        .background(Theme.gold.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(action.completed ? Theme.sage.opacity(0.05) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(action.completed ? Theme.sage.opacity(0.4) : Theme.border, lineWidth: 1)
                )
        )
        .padding(.bottom, 8)
    }

    private func ritualLaunchIcon(_ id: String) -> String? {
        switch id {
        case "qigong": return "play.fill"
        case "meditation": return "play.fill"
        case "journaling": return "play.fill"
        default: return nil
        }
    }

    private func launchRitualActivity(_ id: String, idx: Int) {
        HapticManager.shared.impact(.medium)
        switch id {
        case "qigong":
            showQiGong = true
            withAnimation { appState.morningProtocolActions[idx].completed = true }
        case "meditation":
            showMeditation = true
            withAnimation { appState.morningProtocolActions[idx].completed = true }
        case "journaling":
            showJournaling = true
            withAnimation { appState.morningProtocolActions[idx].completed = true }
        default: break
        }
    }

    // MARK: - Step 3: Training

    private var trainingStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrow("Training")
            Text("Today\u{2019}s session")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Theme.text)

            if appState.workoutCompleted {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.sage)
                    Text("You already trained today. Recovery counts too.")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.muted)
                }
                .padding(.top, 4)
            } else if let day = workoutService.todaysWorkout(day: appState.currentDay) {
                // Show today's workout summary
                VStack(alignment: .leading, spacing: 14) {
                    Text(day.focus)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.text)
                    Text("\(day.exercises.count) exercises")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)

                    // Exercise list preview
                    ForEach(day.exercises.prefix(8)) { ex in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(ex.isWarmup ? Theme.gold.opacity(0.15) : (ex.isCardio ? Color(hex: "7FD0FF").opacity(0.15) : Theme.sage.opacity(0.15)))
                                .frame(width: 8, height: 8)
                            Text(ex.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.text)
                                .lineLimit(1)
                            Spacer()
                            Text(ex.setsReps)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.muted)
                        }
                        .padding(.vertical, 4)
                    }

                    if day.exercises.count > 8 {
                        Text("+ \(day.exercises.count - 8) more")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.muted)
                    }

                    // Start workout button
                    Button { showWorkout = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12))
                            Text("Start Workout")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "1A1816"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "E6C886"), Color(hex: "A6834A")],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(16)
                .background(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                // No program generated yet
                VStack(alignment: .leading, spacing: 8) {
                    Text("No workout program yet.")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.muted)
                    Button { showWorkout = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                            Text("Generate Program")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Theme.gold)
                    }
                }
            }
        }
    }

    // MARK: - Step 4: Nutrition

    private var nutritionStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrow("Nutrition")
            Text("Fuel the version you\u{2019}re building.")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Theme.text)
            Text("Protein is your anchor today. Keep it simple: protein, plants, carbs, water.")
                .font(.system(size: 14))
                .foregroundColor(Theme.muted)
                .padding(.bottom, 14)

            nutritionOptionRow(label: "Log a meal") { showFoodSearch = true }
            nutritionOptionRow(label: "Snap a meal photo") { showFoodScanner = true }
            nutritionOptionRow(label: "View today\u{2019}s meal plan") { showMealPlan = true }

            Text("Your next meal doesn\u{2019}t need to be perfect. It needs to be aligned.")
                .font(.system(size: 13, weight: .regular))
                .italic()
                .foregroundColor(Theme.muted)
                .padding(.top, 14)
        }
    }

    private func optionRow(label: String) -> some View {
        Button {
            HapticManager.shared.impact(.light)
            isPresented = false
        } label: {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }

    private func nutritionOptionRow(label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.impact(.light)
            action()
        } label: {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }

    // MARK: - Step 5: Future Self

    private var futureSelfStep: some View {
        let week = max(1, Int(ceil(Double(appState.currentDay) / 7.0)))
        return VStack(alignment: .leading, spacing: 10) {
            eyebrow("Future Self")
            Text("A short check-in.")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Theme.text)
            Text(FutureYouCopy.forWeek(week))
                .font(.system(size: 14))
                .foregroundColor(Theme.muted)
                .padding(.bottom, 14)

            Button {
                HapticManager.shared.impact(.light)
                showCoach = true
            } label: {
                HStack {
                    Text("Talk to your future self")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.muted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.02))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Text("Optional \u{2014} skip if you\u{2019}re not in the mood today.")
                .font(.system(size: 13))
                .foregroundColor(Theme.muted)
                .padding(.top, 14)
        }
    }

    // MARK: - Step 6: Close the Loop

    @State private var showCloseDay = false

    private var closeoutStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            eyebrow("Close the Loop")
            Text(showFinal ? "Day complete." : "Lock it in.")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Theme.text)
            Text(showFinal ? CoachLine.get(.closeout) : "Review your day, reflect, and close the loop.")
                .font(.system(size: 14))
                .foregroundColor(Theme.muted)
                .padding(.bottom, 8)

            if showFinal {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.sage)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Day closed.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Theme.text)
                        Text("Momentum logged. Rest well.")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.muted)
                    }
                }
                .padding(.top, 8)
            } else {
                // Today's summary
                VStack(spacing: 10) {
                    HStack(spacing: 14) {
                        closeoutCheck(label: "Ritual",    done: appState.morningProtocolCompleted)
                        closeoutCheck(label: "Workout",   done: appState.workoutCompleted)
                        closeoutCheck(label: "Walk",      done: appState.dailyWalkCompleted)
                        closeoutCheck(label: "Nutrition", done: appState.proteinLogged > 0 || appState.caloriesLogged > 0)
                    }

                    // Water progress
                    HStack(spacing: 6) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "7FD0FF"))
                        Text("\(appState.waterLogged)/\(appState.waterGoal) glasses")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.muted)
                        Spacer()
                    }
                }
                .padding(.top, 4)

                // Close the Day button → launches reflection
                Button { showCloseDay = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 14))
                        Text("Close the Day")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "1A1816"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "E6C886"), Color(hex: "A6834A")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .fullScreenCover(isPresented: $showCloseDay) {
                    EveningReflectionView()
                        .environmentObject(appState)
                        .onDisappear {
                            if appState.eveningReflectionDone {
                                completeDay()
                                showFinal = true
                            }
                        }
                }
            }
        }
    }

    private func closeoutCheck(label: String, done: Bool) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(done ? Theme.sage : Color.clear)
                    .frame(width: 14, height: 14)
                Circle()
                    .stroke(done ? Theme.sage : Theme.border, lineWidth: 1.5)
                    .frame(width: 14, height: 14)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.onAccent)
                }
            }
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(done ? Theme.text : Theme.muted)
        }
    }

    // MARK: - Eyebrow helper

    private func eyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(2.0)
            .foregroundColor(Theme.gold)
    }

    // MARK: - completeDay

    /// Marks today complete and updates the streak. This is iOS-LOCAL state
    /// (UserDefaults on this device). The web app keeps its own equivalent
    /// state in localStorage; there is NO cross-device sync between web and
    /// iOS, so these values do not round-trip between the two surfaces.
    private func completeDay() {
        let today = StartTodayFlowState.todayKey()
        let defaults = UserDefaults.standard
        defaults.set(today, forKey: "wylde_last_completed_day")

        // Day counter is now automatic (computed from start date).
        // Just refresh it so the UI updates immediately.
        appState.refreshCurrentDay()

        // Update streak — if last completed day was yesterday, increment;
        // otherwise reset to 1.
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        // Use calendar day arithmetic (not a fixed 86 400s subtraction) so a
        // DST transition doesn't shift "yesterday" by an hour into the wrong day.
        let yesterdayDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterday = f.string(from: yesterdayDate)
        let lastDayKey = defaults.string(forKey: "wylde_last_day_key") ?? ""
        if lastDayKey == yesterday {
            appState.streak += 1
        } else if lastDayKey != today {
            appState.streak = 1
        }
        defaults.set(today, forKey: "wylde_last_day_key")

        // XP — silent, same as web
        appState.awardXP(50, reason: "Day completed")
    }
}
