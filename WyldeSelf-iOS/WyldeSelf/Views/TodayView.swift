import SwiftUI

struct TodayView: View {
    @EnvironmentObject var appState: AppState
    @State private var showGreeting = true
    @State private var healthSteps: Int = 0
    @State private var healthCalories: Int = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                headerSection

                // Hero card — day + streak
                heroCard

                // Morning Protocol
                if !appState.morningProtocolCompleted {
                    morningProtocolCard
                }

                // Workout CTA
                workoutCard

                // Nutrition snapshot
                nutritionCard

                // Health data
                healthCard

                Spacer(minLength: 100)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 60)
        }
        .background(Theme.background)
        .onAppear {
            loadHealthData()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.muted)
                Text(appState.userName.isEmpty ? "Warrior" : appState.userName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.text)
            }
            Spacer()
            // Level badge
            Text(appState.level)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.sage)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Theme.sage.opacity(0.12))
                )
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAY \(appState.currentDay)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Theme.text)
                    Text("of your transformation")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.muted)
                }
                Spacer()
                // Streak
                VStack(spacing: 2) {
                    Text("\(appState.streak)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.sage)
                    Text("streak")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.muted)
                }
            }

            // XP bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(appState.xp) XP")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Text(nextLevelText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.muted)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.sage)
                            .frame(width: geo.size.width * xpProgress, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.surface)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Morning Protocol

    private var morningProtocolCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sunrise.fill")
                    .foregroundColor(Theme.gold)
                Text("Morning Protocol")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
            }

            if appState.morningProtocolActions.isEmpty {
                Text("Set up your morning ritual in settings")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.muted)
            } else {
                ForEach(Array(appState.morningProtocolActions.enumerated()), id: \.element.id) { index, action in
                    HStack(spacing: 12) {
                        Image(systemName: action.completed ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(action.completed ? Theme.sage : Theme.muted)
                            .font(.system(size: 20))
                            .onTapGesture {
                                toggleMorningAction(index)
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.text)
                            Text("\(action.dur) min")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.muted)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.surface)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Workout

    private var workoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(Theme.sage)
                Text("Today's Workout")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
                if appState.workoutCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.sage)
                }
            }

            if appState.workoutCompleted {
                Text("Workout complete. Nice work.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.muted)
            } else {
                Button(action: startWorkout) {
                    HStack {
                        Text("Start Workout")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.sage)
                    .cornerRadius(12)
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.surface)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Nutrition

    private var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(Theme.sage)
                Text("Nutrition")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
            }

            HStack(spacing: 20) {
                macroColumn(label: "Protein", current: appState.proteinLogged, goal: appState.proteinGoal, unit: "g")
                macroColumn(label: "Calories", current: appState.caloriesLogged, goal: appState.caloriesGoal, unit: "")
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.surface)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private func macroColumn(label: String, current: Int, goal: Int, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.muted)
            Text("\(current)\(unit)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.text)
            + Text(" / \(goal)\(unit)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.muted)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.sage)
                        .frame(width: min(geo.size.width, geo.size.width * CGFloat(current) / CGFloat(max(1, goal))), height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Health

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red.opacity(0.7))
                Text("Health")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
                Button(action: syncHealth) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.muted)
                }
            }

            HStack(spacing: 24) {
                healthStat(icon: "figure.walk", value: "\(healthSteps)", label: "steps")
                healthStat(icon: "flame", value: "\(healthCalories)", label: "kcal burned")
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.surface)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private func healthStat(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Theme.sage)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.text)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.muted)
            }
        }
    }

    // MARK: - Helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var xpProgress: CGFloat {
        let levels: [(String, Int)] = [
            ("Ember", 0), ("Spark", 200), ("Flame", 500),
            ("Blaze", 1000), ("Inferno", 2000), ("Forge", 4000),
            ("Titan", 8000), ("Legend", 15000)
        ]
        guard let currentIndex = levels.firstIndex(where: { $0.0 == appState.level }) else { return 0 }
        let currentThreshold = levels[currentIndex].1
        let nextThreshold = currentIndex + 1 < levels.count ? levels[currentIndex + 1].1 : 20000
        let range = nextThreshold - currentThreshold
        let progress = appState.xp - currentThreshold
        return CGFloat(progress) / CGFloat(range)
    }

    private var nextLevelText: String {
        let levels: [(String, Int)] = [
            ("Ember", 0), ("Spark", 200), ("Flame", 500),
            ("Blaze", 1000), ("Inferno", 2000), ("Forge", 4000),
            ("Titan", 8000), ("Legend", 15000)
        ]
        guard let currentIndex = levels.firstIndex(where: { $0.0 == appState.level }),
              currentIndex + 1 < levels.count else { return "Max level" }
        let needed = levels[currentIndex + 1].1 - appState.xp
        return "\(needed) to \(levels[currentIndex + 1].0)"
    }

    private func toggleMorningAction(_ index: Int) {
        HapticManager.shared.impact(.light)
        appState.morningProtocolActions[index].completed.toggle()

        // Check if all completed
        if appState.morningProtocolActions.allSatisfy({ $0.completed }) {
            HapticManager.shared.notification(.success)
            appState.morningProtocolCompleted = true
            appState.awardXP(25, reason: "Morning Protocol complete")
        }
    }

    private func startWorkout() {
        HapticManager.shared.impact(.medium)
        // Navigate to workout in web view
        NotificationCenter.default.post(
            name: .navigateToScreen,
            object: nil,
            userInfo: ["screen": "today"]
        )
    }

    private func syncHealth() {
        HapticManager.shared.impact(.light)
        Task {
            await HealthKitManager.shared.syncTodayData()
            loadHealthData()
        }
    }

    private func loadHealthData() {
        let defaults = UserDefaults.standard
        healthSteps = defaults.integer(forKey: "wylde_health_steps")
        healthCalories = defaults.integer(forKey: "wylde_health_calories")
    }
}

extension Notification.Name {
    static let navigateToScreen = Notification.Name("navigateToScreen")
}
