import SwiftUI

struct TodayView: View {
    @EnvironmentObject var appState: AppState
    @State private var showGreeting = true
    @State private var healthSteps: Int = 0
    @State private var healthCalories: Int = 0
    @State private var showPaywall = false
    @State private var showStartToday = false
    @State private var showWorkout = false
    @State private var showQiGong = false
    @State private var showMeditation = false
    @State private var showCoach = false
    @State private var showFoodScanner = false
    @State private var showMealPlan = false
    @State private var showProtocolTracker = false
    @StateObject private var scoreService = WyldeScoreService.shared
    @State private var ritualExpanded = true
    @State private var showJournaling = false
    @State private var showSchedule = false
    @StateObject private var walkTimer = BackgroundTimer(persistKey: "wylde_walk_start")

    @State private var expandedActionID: String?
    @State private var didAppear = false
    @State private var showReflection = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // ─── Today Hero (cinematic, rotates by time of day) ────
                // Photographic banner that shifts morning → midday →
                // evening → night so the surface breathes with the day.
                todayHero
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 10)
                    .animation(.easeOut(duration: 0.5), value: didAppear)

                // ─── Future Self Identity Hero ─────────────────────────
                // The emotional center of the app. Shows who you're
                // becoming, today's day count, and the Start Today CTA.
                identityHero
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 10)
                    .animation(.easeOut(duration: 0.55), value: didAppear)

                // ─── Today's Evidence ──────────────────────────────────
                // Each card is framed as evidence of identity change,
                // not a generic tracker.

                // Wylde Score
                WyldeScoreCard(score: scoreService.todayScore)
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.08), value: didAppear)

                // Morning Ritual — identity reps
                morningProtocolCard
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.10), value: didAppear)

                workoutCard
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.15), value: didAppear)

                walkCard
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.15), value: didAppear)

                nutritionCard
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.20), value: didAppear)

                waterCard
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.22), value: didAppear)

                // Protocol Tracker — only shows when connected to a clinic
                if CheckinSync.shared.hasActiveCareRelationship {
                Button { showProtocolTracker = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "pills.fill")
                            .font(.system(size: 18))
                            .foregroundColor(WyldeStyles.Colors.vitalPurple)
                            .frame(width: 44, height: 44)
                            .background(WyldeStyles.Colors.vitalPurple.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("PROTOCOL TRACKER")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.6)
                                .foregroundColor(WyldeStyles.Colors.vitalPurple)
                            Text("View prescriptions and log doses")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.tertiaryText)
                    }
                    .padding(16)
                    .background(Theme.elevatedBG)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(WyldeStyles.Colors.vitalPurple.opacity(0.15), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .opacity(didAppear ? 1 : 0)
                .offset(y: didAppear ? 0 : 12)
                .animation(.easeOut(duration: 0.6).delay(0.28), value: didAppear)
                } // if hasActiveCareRelationship

                // Coach — talk to your future self
                coachCard
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.30), value: didAppear)

                // Close the Day — always visible until completed
                if !appState.eveningReflectionDone {
                    reflectionCard
                        .opacity(didAppear ? 1 : 0)
                        .offset(y: didAppear ? 0 : 12)
                        .animation(.easeOut(duration: 0.6).delay(0.33), value: didAppear)
                }

                healthCard
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.35), value: didAppear)

                // Founding Member offer — hidden until purchases are wired.
                // Stub PurchaseManager simulates success; showing a paywall
                // CTA with no real products will confuse testers and fail
                // App Review. Re-enable once RevenueCat is integrated.
                // if !appState.isPro {
                //     foundingMemberCard
                // }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 60)
        }
        .background(
            ZStack {
                Theme.background
                AmbientBackground(
                    glowColor: WyldeStyles.Colors.bronze,
                    secondaryGlow: WyldeStyles.Colors.sage
                ).opacity(0.6)
            }
            .clipped()
        )
        .onAppear {
            loadHealthData()
            if !didAppear { didAppear = true }
            Task { await scoreService.updateScore(appState: appState) }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showProtocolTracker) {
            ProtocolTrackerView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showFoodScanner) {
            FoodScannerView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showMealPlan) {
            MealPlanView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showCoach) {
            CoachChatView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showReflection) {
            EveningReflectionView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showQiGong) {
            QiGongFlowView()
        }
        .fullScreenCover(isPresented: $showMeditation) {
            GuidedMeditationView()
        }
        .sheet(isPresented: $showSchedule) {
            WorkoutCalendarView().environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showJournaling) {
            JournalingTimerView()
        }
        .fullScreenCover(isPresented: $showWorkout) {
            workoutDestination
                .environmentObject(appState)
        }
        .sheet(isPresented: $showStartToday) {
            StartTodayFlow(isPresented: $showStartToday)
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToScreen)) { note in
            if let screen = note.userInfo?["screen"] as? String, screen == "workout" {
                showWorkout = true
            }
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

    // MARK: - Today Hero (hourly rotation)

    /// Cinematic photo hero that rotates 4×/day. Uses `TodayHero.current`
    /// to select morning / midday / evening / night, so the app "breathes"
    /// with the user's day instead of feeling static.
    private var todayHero: some View {
        ZStack(alignment: .bottomLeading) {
            Image.wylde(TodayHero.current)
                .aspectRatio(contentMode: .fill)
                .frame(height: 180)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18))
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.5)
                    .foregroundColor(WyldeStyles.Colors.bronze)
                Text(appState.userName.isEmpty ? "Today, presence." : "Today, \(appState.userName).")
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .foregroundColor(.white)
            }
            .padding(20)
        }
        .frame(height: 180)
    }

    // MARK: - Future Self Mirror

    /// Daily progress: how many of today's 5 core actions are done
    private var mirrorProgress: CGFloat {
        var done: CGFloat = 0
        let total: CGFloat = 5
        if appState.morningProtocolCompleted { done += 1 }
        if appState.workoutCompleted { done += 1 }
        if appState.dailyWalkCompleted { done += 1 }
        if appState.proteinLogged > 0 || appState.caloriesLogged > 0 { done += 1 }
        if appState.eveningReflectionDone { done += 1 }
        return done / total
    }

    private var identityHero: some View {
        VStack(spacing: 16) {
            // ── Future Self Mirror ──
            HStack(spacing: 18) {
                // Progress ring around the future self image
                ZStack {
                    // Track
                    Circle()
                        .stroke(WyldeStyles.Colors.bronze.opacity(0.12), lineWidth: 3.5)
                        .frame(width: 90, height: 90)
                    // Fill — glows as actions complete
                    Circle()
                        .trim(from: 0, to: mirrorProgress)
                        .stroke(
                            LinearGradient(
                                colors: [WyldeStyles.Colors.bronze, WyldeStyles.Colors.gold],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: mirrorProgress)

                    // Image
                    if let img = futureSelfImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(WyldeStyles.Colors.bronze.opacity(0.10))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(WyldeStyles.Colors.bronze.opacity(0.4))
                            )
                    }
                }

                // Identity text
                VStack(alignment: .leading, spacing: 6) {
                    Text("Day \(appState.currentDay)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(WyldeStyles.Colors.bronze)

                    let identity = appState.identityStatement.isEmpty ? derivedIdentity : appState.identityStatement
                    Text(identity)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundColor(Theme.text)
                        .lineSpacing(2)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // Streak
                    if appState.streak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                            Text("\(appState.streak) day streak")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(Theme.sage)
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(WyldeStyles.Colors.bronze.opacity(0.10), lineWidth: 1)
                    )
            )

            // ── Today's proof ──
            let todayActions = todayProofText
            Text(todayActions)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WyldeStyles.Colors.charcoal)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Start Today CTA
            Button {
                HapticManager.shared.impact(.medium)
                showStartToday = true
            } label: {
                HStack(spacing: 8) {
                    Text("Start Today")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(0.5)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(WyldeStyles.Colors.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [WyldeStyles.Colors.gold, Color(hex: "A6834A")],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
    }

    /// Contextual proof text that changes as the user completes actions
    private var todayProofText: String {
        let done = [
            appState.morningProtocolCompleted ? "ritual" : nil,
            appState.workoutCompleted ? "training" : nil,
            appState.dailyWalkCompleted ? "walk" : nil,
            (appState.proteinLogged > 0 || appState.caloriesLogged > 0) ? "nutrition" : nil,
            appState.eveningReflectionDone ? "reflection" : nil,
        ].compactMap { $0 }

        if done.isEmpty {
            return "Today, prove it with: ritual, training, walk, nutrition, close the loop."
        } else if done.count >= 5 {
            return "All actions complete. This is who you are now."
        } else {
            let remaining = ["ritual", "training", "walk", "nutrition", "reflection"].filter { !done.contains($0) }
            return "Evidence so far: \(done.joined(separator: ", ")). Still ahead: \(remaining.joined(separator: ", "))."
        }
    }

    /// Derive an identity statement from the user's goals when they haven't
    /// written a custom one. Keeps the hero from feeling empty.
    private var derivedIdentity: String {
        let goals = appState.goals
        if goals.isEmpty {
            return "The person who shows up every day."
        }
        // Map fitness goals to identity language
        let phrases: [String: String] = [
            "Burn fat": "Someone who moves with power and eats with purpose.",
            "Build muscle": "Someone who trains deliberately and grows stronger.",
            "Get lean & athletic": "Someone who is lean, capable, and built for life.",
            "Build confidence": "Someone who trusts themselves because they keep promises.",
            "Improve endurance": "Someone who doesn't quit — in the gym or in life.",
            "Increase flexibility": "Someone who moves freely and recovers fully.",
        ]
        if let first = goals.first, let phrase = phrases[first] {
            return phrase
        }
        return "Someone who follows through on what they said they'd do."
    }

    private var futureSelfImage: UIImage? {
        guard let base64 = UserDefaults.standard.string(forKey: "wylde_future_rendering"),
              let data = Data(base64Encoded: base64),
              let img = UIImage(data: data) else { return nil }
        return img
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            // Profile photo — future self rendering
            if let img = futureSelfImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(WyldeStyles.Colors.bronze.opacity(0.4), lineWidth: 1.5))
                    .fixedSize()
            } else {
                Circle()
                    .fill(WyldeStyles.Colors.bronze.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String((appState.userName.first ?? "W").uppercased()))
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundColor(WyldeStyles.Colors.bronze)
                    )
                    .fixedSize()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.muted)
                Text(appState.userName.isEmpty ? "Welcome" : appState.userName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.text)
            }
            Spacer()
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
        ZStack(alignment: .bottomLeading) {
            // Hero background image
            GeometryReader { geo in
                Image("HeroBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }

            // Gradient overlays matching web's .ov-hero::before
            LinearGradient(
                colors: [
                    Color(hex: "20241C").opacity(0.52),
                    Color(hex: "20241C").opacity(0.25),
                    Color(hex: "20241C").opacity(0.08),
                    Color(hex: "20241C").opacity(0.02)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            LinearGradient(
                colors: [.clear, .clear, Color(hex: "20241C").opacity(0.50)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                Text("DAY \(appState.currentDay)")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)

                // "X of N closed" — the honest progress meter. `completedDays`
                // increments only when the user submits their Evening
                // Reflection (per markLoopClosed()), so this reads as
                // adherence, not just calendar drift.
                Text("\(appState.completedDays) of \(appState.currentDay) closed")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(WyldeStyles.Colors.gold)

                Text("of becoming who you said you'd be")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))

                // Primary CTA
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
                    .foregroundColor(WyldeStyles.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [WyldeStyles.Colors.gold, Color(hex: "A6834A")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(24)
        }
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
    }

    // MARK: - Morning Protocol

    private var morningProtocolCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { ritualExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "sunrise.fill")
                        .foregroundColor(Theme.gold)
                    Text("Morning Ritual")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Text("\(completedActionsCount)/\(appState.morningProtocolActions.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.muted)
                    Image(systemName: ritualExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.muted)
                }
            }
            .buttonStyle(.plain)

            if ritualExpanded {
            ForEach(Array(appState.morningProtocolActions.enumerated()), id: \.element.id) { index, action in
                let isExpanded = expandedActionID == action.id
                let hasActivity = ["qigong", "meditation", "journaling"].contains(action.id)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        Image(systemName: action.completed ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(action.completed ? Theme.sage : Theme.muted)
                            .font(.system(size: 22))
                            .scaleEffect(action.completed ? 1.0 : 0.92)
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: action.completed)
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
                                .lineLimit(isExpanded ? nil : 1)
                                .animation(.easeInOut(duration: 0.2), value: isExpanded)
                        }
                        Spacer()

                        HStack(spacing: 8) {
                            Text("\(action.dur)m")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.muted)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.muted)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedActionID = isExpanded ? nil : action.id
                        }
                    }

                    // Expanded: show Start button for actions with a dedicated view
                    if isExpanded && hasActivity && !action.completed {
                        Button {
                            if action.id == "qigong" {
                                showQiGong = true
                            } else if action.id == "meditation" {
                                showMeditation = true
                            } else if action.id == "journaling" {
                                showJournaling = true
                            }
                            toggleMorningAction(index)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                Text("Start \(action.name)")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(Theme.gold)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Theme.gold.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.leading, 36)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Reading tracker — shows under the reading action
                    if action.id == "reading" {
                        readingTracker
                            .padding(.leading, 36)
                            .padding(.top, 8)
                    }
                }
            }
            } // if ritualExpanded
        }
        .padding(Theme.cardPadding)
        .background(Theme.surface)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private var readingTracker: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Current book
            if appState.currentBook.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.gold)
                    TextField("What are you reading?", text: $appState.currentBook)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.text)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.gold)
                    Text(appState.currentBook)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        appState.currentBook = ""
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.muted)
                    }
                }

                // Pages read
                HStack(spacing: 8) {
                    Text("Pages today:")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.muted)
                    Button { if appState.pagesReadToday > 0 { appState.pagesReadToday -= 5 } } label: {
                        Text("−")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.muted)
                            .frame(width: 24, height: 24)
                            .background(Theme.surface)
                            .clipShape(Circle())
                    }
                    Text("\(appState.pagesReadToday)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.text)
                        .frame(width: 32)
                    Button { appState.pagesReadToday += 5 } label: {
                        Text("+")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.muted)
                            .frame(width: 24, height: 24)
                            .background(Theme.surface)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private var completedActionsCount: Int {
        appState.morningProtocolActions.filter { $0.completed }.count
    }

    // MARK: - Workout

    private var workoutCard: some View {
        let service = WorkoutService.shared
        let todayDay = service.todaysWorkout(day: appState.currentDay)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(Theme.gold)
                Text("Today's Workout")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
                Button { showSchedule = true } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.muted)
                }
                if appState.workoutCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.sage)
                }
            }

            if appState.workoutCompleted {
                Text("Workout complete. Nice work.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.muted)
            } else if let day = todayDay {
                // Show today's focus
                Text(day.focus)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.text)
                Text("\(day.exercises.count) exercises")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.muted)

                Button { showWorkout = true } label: {
                    HStack(spacing: 8) {
                        Text("Start Workout")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(0.5)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(WyldeStyles.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [WyldeStyles.Colors.gold, Color(hex: "A6834A")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                }
            } else {
                // No program yet
                Button { showWorkout = true } label: {
                    HStack(spacing: 8) {
                        Text("Generate Program")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(0.5)
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(WyldeStyles.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [WyldeStyles.Colors.gold, Color(hex: "A6834A")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 22))
                    .foregroundColor(appState.dailyWalkCompleted ? Theme.sage : WyldeStyles.Colors.vitalBlue)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill((appState.dailyWalkCompleted ? Theme.sage : WyldeStyles.Colors.vitalBlue).opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Long Walk")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(appState.dailyWalkCompleted ? Theme.muted : Theme.text)
                        .strikethrough(appState.dailyWalkCompleted, color: Theme.muted)
                    if walkTimer.isRunning {
                        Text(walkTimeString)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(WyldeStyles.Colors.vitalBlue)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.3), value: walkTimer.elapsed)
                    } else {
                        Text(appState.dailyWalkCompleted ? "Done — that counts." : "30+ minutes outside")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.muted)
                    }
                }
                Spacer()

                if appState.dailyWalkCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.sage)
                        .font(.system(size: 22))
                }
            }

            if !appState.dailyWalkCompleted {
                HStack(spacing: 8) {
                    if walkTimer.isRunning {
                        // Stop + Complete
                        Button {
                            let seconds = walkTimer.elapsed
                            let startDate = walkTimer.startDate
                            let _ = walkTimer.stop()
                            if seconds >= 1800 { // 30 min
                                toggleWalk()
                            }
                            // Save walk to HealthKit
                            if let start = startDate {
                                Task { await HealthKitManager.shared.saveWalkWorkout(start: start, end: Date()) }
                            }
                        } label: {
                            Text(walkTimer.elapsed >= 1800 ? "Complete Walk" : "End (\(walkTimer.elapsed / 60)m)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(walkTimer.elapsed >= 1800 ? WyldeStyles.Colors.ink : WyldeStyles.Colors.vitalBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(walkTimer.elapsed >= 1800 ? WyldeStyles.Colors.vitalBlue : WyldeStyles.Colors.vitalBlue.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    } else {
                        // Start timer
                        Button {
                            walkTimer.start()
                            HealthKitManager.shared.startWorkoutSession(activityType: .walking)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11))
                                Text("Start Walk")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(WyldeStyles.Colors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(WyldeStyles.Colors.vitalBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Manual complete
                        Button { toggleWalk() } label: {
                            Text("Done")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.surface)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.surface)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private var walkTimeString: String {
        let m = walkTimer.elapsed / 60
        let s = walkTimer.elapsed % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Nutrition

    private var nutritionCard: some View {
        Button { appState.selectedTab = .nutrition } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(Theme.sage)
                    Text("Nutrition")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Text("\(appState.proteinLogged)g P · \(appState.caloriesLogged) cal")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.muted)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                }

                HStack(spacing: 12) {
                    macroColumn(label: "Protein", current: appState.proteinLogged, goal: appState.proteinGoal, unit: "g")
                    macroColumn(label: "Calories", current: appState.caloriesLogged, goal: appState.caloriesGoal, unit: "")
                    macroColumn(label: "Carbs", current: appState.carbsLogged, goal: appState.carbsGoal, unit: "g")
                    macroColumn(label: "Fat", current: appState.fatLogged, goal: appState.fatGoal, unit: "g")
                }
            }
            .padding(Theme.cardPadding)
            .background(Theme.surface)
            .cornerRadius(Theme.cardRadius)
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func macroColumn(label: String, current: Int, goal: Int, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(current)\(unit)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.text)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: current)
                Text(" / \(goal)\(unit)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.muted)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.sage)
                        .frame(width: min(geo.size.width, geo.size.width * CGFloat(current) / CGFloat(max(1, goal))), height: 4)
                        .animation(.easeOut(duration: 0.5), value: current)
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
        let silhouette = appState.gender.lowercased() == "female" ? "FutureSelfWoman" : "FutureSelfMan"
        return Button {
            HapticManager.shared.impact(.light)
            appState.selectedTab = .future
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Dark forest background
                LinearGradient(
                    colors: [Color(hex: "0E130E"), Color(hex: "222A20"), Color(hex: "0E130E")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Silhouette on the right
                HStack {
                    Spacer()
                    Image(silhouette)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 140)
                        .opacity(0.3)
                        .offset(x: 10, y: -5)
                }

                // Radial glow
                RadialGlowOverlay(color: Color(hex: "C8A96E"), opacity: 0.12, position: .init(x: 0.85, y: 0.2), radius: 120)

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text("FUTURE YOU")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(Color(hex: "C8A96E"))
                    Text("This is you in \(weeksLeft) week\(weeksLeft == 1 ? "" : "s").")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "F4F1E8"))
                    Text(FutureYouCopy.forWeek(week))
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "A6A29A"))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Text("See your transformation")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "C8A96E"))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "C8A96E"))
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(hex: "C8A96E").opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Health

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            // Activity Rings
            HStack(spacing: 16) {
                // Move ring
                activityRing(
                    label: "Move",
                    current: healthCalories,
                    goal: 500,
                    color: .red.opacity(0.8),
                    icon: "flame.fill"
                )
                // Exercise ring
                activityRing(
                    label: "Exercise",
                    current: appState.workoutCompleted ? 30 : (walkTimer.isRunning ? walkTimer.elapsed / 60 : 0),
                    goal: 30,
                    color: WyldeStyles.Colors.vitalTeal,
                    icon: "figure.run"
                )
                // Stand/Steps ring
                activityRing(
                    label: "Steps",
                    current: healthSteps,
                    goal: 10000,
                    color: WyldeStyles.Colors.vitalBlue,
                    icon: "figure.walk"
                )
            }

            // Stats row
            HStack(spacing: 16) {
                healthStat(value: "\(healthSteps)", label: "steps")
                healthStat(value: "\(healthCalories)", label: "kcal")
                healthStat(value: appState.workoutCompleted ? "✓" : "—", label: "workout")
                healthStat(value: appState.dailyWalkCompleted ? "✓" : "—", label: "walk")
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.surface)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private func activityRing(label: String, current: Int, goal: Int, color: Color, icon: String) -> some View {
        let progress = goal > 0 ? min(1.0, CGFloat(current) / CGFloat(goal)) : 0
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 6)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: current)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func healthStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.text)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Theme.muted)
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            appState.morningProtocolActions[index].completed.toggle()
        }

        // Check if all completed
        if appState.morningProtocolActions.allSatisfy({ $0.completed }) {
            HapticManager.shared.notification(.success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                appState.morningProtocolCompleted = true
            }
            appState.awardXP(25, reason: "Morning Protocol complete")
        }
    }

    private func toggleWalk() {
        HapticManager.shared.impact(.light)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            appState.dailyWalkCompleted.toggle()
        }
        if appState.dailyWalkCompleted {
            HapticManager.shared.notification(.success)
            appState.awardXP(10, reason: "Long walk")
        }
    }

    // MARK: - Coach Card

    private var coachCard: some View {
        let name = appState.userName.isEmpty ? "Future Self" : "Future \(appState.userName)"
        return Button {
            showCoach = true
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(WyldeStyles.Colors.bronze.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundColor(WyldeStyles.Colors.bronze)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("TALK TO \(name.uppercased())")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(WyldeStyles.Colors.bronze)
                    Text("The version of you that already did it.")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.tertiaryText)
            }
            .padding(16)
            .background(Theme.elevatedBG)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(WyldeStyles.Colors.bronze.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var workoutDestination: some View {
        WorkoutContainerView()
    }

    private func startWorkout() {
        HapticManager.shared.impact(.medium)
        showWorkout = true
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
        appState.caloriesBurned = healthCalories
    }

    // MARK: - Water

    private var waterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(WyldeStyles.Colors.vitalBlue)
                Text("Water")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
                Text("\(appState.waterLogged) / \(appState.waterGoal) glasses")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.muted)
            }

            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<appState.waterGoal, id: \.self) { i in
                    Circle()
                        .fill(i < appState.waterLogged ? WyldeStyles.Colors.vitalBlue : WyldeStyles.Colors.vitalBlue.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "drop.fill")
                                .font(.system(size: 11))
                                .foregroundColor(i < appState.waterLogged ? .white : WyldeStyles.Colors.vitalBlue.opacity(0.3))
                        )
                        .onTapGesture {
                            HapticManager.shared.impact(.light)
                            if appState.waterLogged == i + 1 {
                                appState.waterLogged = i
                            } else {
                                appState.waterLogged = i + 1
                            }
                        }
                }
                Spacer()
            }

            // Quick add buttons
            HStack(spacing: 8) {
                Button {
                    HapticManager.shared.impact(.light)
                    if appState.waterLogged < appState.waterGoal {
                        appState.waterLogged += 1
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                        Text("Add glass")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(WyldeStyles.Colors.vitalBlue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(WyldeStyles.Colors.vitalBlue.opacity(0.10))
                    .clipShape(Capsule())
                }

                if appState.waterLogged >= appState.waterGoal {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Goal reached")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Theme.sage)
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.surface)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Evening Reflection

    private var isEveningTime: Bool {
        Calendar.current.component(.hour, from: Date()) >= 17
    }

    private var reflectionCard: some View {
        Button { showReflection = true } label: {
            HStack(spacing: 14) {
                Image(systemName: isEveningTime ? "moon.stars.fill" : "checkmark.circle")
                    .font(.system(size: 18))
                    .foregroundColor(WyldeStyles.Colors.vitalPurple)
                    .frame(width: 44, height: 44)
                    .background(WyldeStyles.Colors.vitalPurple.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("CLOSE THE DAY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(WyldeStyles.Colors.vitalPurple)
                    Text("Reflect, reset, and close the loop")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.tertiaryText)
            }
            .padding(16)
            .background(Theme.elevatedBG)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(WyldeStyles.Colors.vitalPurple.opacity(0.15), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// Note: `Notification.Name.navigateToScreen` is declared in AppDelegate.swift
