import SwiftUI

struct TodayView: View {
    @EnvironmentObject var appState: AppState
    @State private var showGreeting = true
    @State private var healthSteps: Int = 0
    @State private var healthCalories: Int = 0
    @State private var showPaywall = false
    @State private var showStartToday = false

    @State private var didAppear = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                headerSection
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 8)
                    .animation(.easeOut(duration: 0.5), value: didAppear)

                // Hero card — day + Start Today CTA. (Level/XP stripped —
                // brand is about transforming your relationship with
                // yourself, not climbing a ladder.)
                heroCard
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.05), value: didAppear)

                // ─── Today's Path: required actions first ───────────────
                // Order mirrors the web brief: Today's Path (training,
                // walk) → Nutrition → Future You → Morning Routine →
                // Health. Reduces cognitive load so the user knows what
                // to do next, not everything at once.

                workoutCard
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.10), value: didAppear)

                walkCard
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.15), value: didAppear)

                nutritionCard
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.20), value: didAppear)

                // Future You strip — calm reminder of what consistency is
                // building toward. Copy evolves week-by-week via
                // FutureYouCopy.forWeek so it doesn't read like a
                // template. Tap routes to the Future tab.
                futureYouCard
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.25), value: didAppear)

                // Morning Protocol — moved lower since users can also run
                // it inside the StartTodayFlow now. Stays here for
                // direct check-off when they don't want the guided flow.
                if !appState.morningProtocolCompleted {
                    morningProtocolCard
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal:   .opacity.combined(with: .scale(scale: 0.95))
                        ))
                        .opacity(didAppear ? 1 : 0)
                        .offset(y: didAppear ? 0 : 12)
                        .animation(.easeOut(duration: 0.6).delay(0.30), value: didAppear)
                }

                healthCard
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.35), value: didAppear)

                // Founding Member offer — only shown to non-Pro users.
                // Soft CTA, never blocks. Identity-driven framing.
                if !appState.isPro {
                    foundingMemberCard
                        .opacity(didAppear ? 1 : 0)
                        .offset(y: didAppear ? 0 : 12)
                        .animation(.easeOut(duration: 0.6).delay(0.40), value: didAppear)
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 60)
        }
        .background(Theme.background)
        .onAppear {
            loadHealthData()
            // First-time-on-screen staggered fade up. Once shown, stays visible.
            if !didAppear {
                didAppear = true
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(appState)
        }
        .sheet(isPresented: $showStartToday) {
            StartTodayFlow(isPresented: $showStartToday)
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Founding Member CTA card

    private var foundingMemberCard: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            showPaywall = true
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(Theme.gold).frame(width: 5, height: 5)
                    Text("FOUNDING MEMBER")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2.2)
                        .foregroundColor(Theme.gold)
                }
                Text("Sponsor the work. Lock in lifetime.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.leading)
                Text("First 1,000 members only. Founder pricing forever.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.muted)
                HStack {
                    Text("See the offer")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.gold)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.gold)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardRadius)
                            .stroke(Theme.gold.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.muted)
                Text(appState.userName.isEmpty ? "Welcome" : appState.userName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.text)
            }
            Spacer()
            // Streak badge — replaces the old level badge. A streak is a
            // measure of how consistently you've shown up for yourself,
            // which is on-brand. A "level" implies you're being graded.
            if appState.streak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                    Text("\(appState.streak)")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Theme.sage)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Theme.sage.opacity(0.12))
                )
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DAY \(appState.currentDay)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Theme.text)
            Text("of becoming who you said you'd be")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.muted)

            // Primary CTA — opens the StartTodayFlow guided 6-step flow.
            // Native equivalent of the web "Start Today" button.
            Button {
                HapticManager.shared.impact(.medium)
                showStartToday = true
            } label: {
                HStack(spacing: 8) {
                    Text("Start Today")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1.0)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(Color(hex: "0B0B0B"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(Theme.gold)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .background(Theme.surface)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Morning Protocol

    private var morningProtocolCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "sunrise.fill")
                    .foregroundColor(Theme.gold)
                Text("Morning Protocol")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
                Text("\(completedActionsCount)/\(appState.morningProtocolActions.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.muted)
            }

            ForEach(Array(appState.morningProtocolActions.enumerated()), id: \.element.id) { index, action in
                HStack(spacing: 14) {
                    Image(systemName: action.completed ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(action.completed ? Theme.sage : Theme.muted)
                        .font(.system(size: 22))
                        .onTapGesture {
                            toggleMorningAction(index)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(action.completed ? Theme.muted : Theme.text)
                            .strikethrough(action.completed, color: Theme.muted)
                        Text(action.desc)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.muted)
                            .lineLimit(2)
                    }
                    Spacer()
                    Text("\(action.dur)m")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.muted)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleMorningAction(index)
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.surface)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private var completedActionsCount: Int {
        appState.morningProtocolActions.filter { $0.completed }.count
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

    // MARK: - Daily Walk

    private var walkCard: some View {
        Button(action: toggleWalk) {
            HStack(spacing: 14) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 22))
                    .foregroundColor(appState.dailyWalkCompleted ? Theme.sage : Theme.gold)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill((appState.dailyWalkCompleted ? Theme.sage : Theme.gold).opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Long Walk")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(appState.dailyWalkCompleted ? Theme.muted : Theme.text)
                        .strikethrough(appState.dailyWalkCompleted, color: Theme.muted)
                    Text(appState.dailyWalkCompleted ? "Done — that counts." : "30+ minutes outside, sometime today")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                }
                Spacer()
                Image(systemName: appState.dailyWalkCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(appState.dailyWalkCompleted ? Theme.sage : Theme.muted)
                    .font(.system(size: 22))
            }
            .padding(Theme.cardPadding)
            .background(Theme.surface)
            .cornerRadius(Theme.cardRadius)
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
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

    // MARK: - Future You

    /// Calm reminder strip. Copy evolves by week via FutureYouCopy.forWeek
    /// so the same card reads differently in week 1 vs week 8 — quietly
    /// signaling that the app is tracking with the user. Tap → Future tab.
    private var futureYouCard: some View {
        let week = max(1, Int(ceil(Double(appState.currentDay) / 7.0)))
        let weeksLeft = max(1, 12 - (week - 1))
        return Button {
            HapticManager.shared.impact(.light)
            appState.selectedTab = .future
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.sage.opacity(0.08))
                    Text("\(weeksLeft)w")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.sage)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text("FUTURE YOU")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(Theme.gold)
                    Text("This is you in \(weeksLeft) week\(weeksLeft == 1 ? "" : "s").")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.text)
                    Text(FutureYouCopy.forWeek(week))
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.muted)
            }
            .padding(Theme.cardPadding)
            .background(Theme.surface)
            .cornerRadius(Theme.cardRadius)
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
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

    private func toggleMorningAction(_ index: Int) {
        HapticManager.shared.impact(.light)
        // Spring animation so the checkmark fills with a satisfying bounce
        // instead of an instant flip — small thing, big tactile difference
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            appState.morningProtocolActions[index].completed.toggle()
        }

        // Check if all completed
        if appState.morningProtocolActions.allSatisfy({ $0.completed }) {
            HapticManager.shared.notification(.success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appState.morningProtocolCompleted = true
            }
            appState.awardXP(25, reason: "Morning Protocol complete")
        }
    }

    private func toggleWalk() {
        HapticManager.shared.impact(.light)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            appState.dailyWalkCompleted.toggle()
        }
        if appState.dailyWalkCompleted {
            HapticManager.shared.notification(.success)
            appState.awardXP(10, reason: "Long walk")
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

// Note: `Notification.Name.navigateToScreen` is declared in AppDelegate.swift
