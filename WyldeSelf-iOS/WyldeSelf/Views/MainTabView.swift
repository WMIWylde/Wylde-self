import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettingsDrawer = false
    @State private var showWalkthrough = !UserDefaults.standard.bool(forKey: "wylde_walkthrough_seen")

    @State private var xpToast: (amount: Int, reason: String)? = nil
    @State private var xpToastID = 0
    @StateObject private var badgeService = BadgeService.shared
    @StateObject private var coachService = CoachService.shared
    @State private var showCoachChat = false
    @State private var coachCheckin: String? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── The Coach: present on every screen ──
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showCoachChat = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Theme.cardSurface)
                                .frame(width: 52, height: 52)
                                .overlay(Circle().stroke(WyldeStyles.Colors.bronze.opacity(0.35), lineWidth: 1))
                                .shadow(color: .black.opacity(0.22), radius: 14, y: 5)
                            Image(systemName: "circle.hexagongrid.circle")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(WyldeStyles.Colors.bronze)
                            if coachService.pendingOpener != nil {
                                Circle()
                                    .fill(WyldeStyles.Colors.clay)
                                    .frame(width: 10, height: 10)
                                    .offset(x: 18, y: -18)
                            }
                        }
                    }
                    .accessibilityLabel("Coach")
                    .accessibilityHint(coachService.pendingOpener != nil ? "New message from your coach" : "Open the AI coach")
                    .padding(.trailing, 18)
                    .padding(.bottom, 92)
                }
            }
            .zIndex(40)

            // ── Daily check-in card (first open of the day) ──
            if let q = coachCheckin {
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(appState.userName.isEmpty ? "FUTURE YOU" : "FUTURE \(appState.userName.uppercased())") CHECKED IN")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2)
                            .foregroundColor(WyldeStyles.Colors.bronze)
                        Text(q)
                            .font(.system(size: 15, design: .serif))
                            .foregroundColor(WyldeStyles.Colors.ink)
                            .lineSpacing(3)
                        HStack(spacing: 10) {
                            Button("Not now") {
                                // Clear the daily flag so it reappears next app open
                                let key = "wylde_coach_checkin_" + ISO8601DateFormatter().string(from: Date()).prefix(10)
                                UserDefaults.standard.removeObject(forKey: String(key))
                                withAnimation { coachCheckin = nil }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(WyldeStyles.Colors.stone)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(WyldeStyles.Colors.bone)
                            .clipShape(Capsule())
                            Button("Answer") {
                                coachService.pendingOpener = q
                                withAnimation { coachCheckin = nil }
                                showCoachChat = true
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(WyldeStyles.Colors.paper)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(WyldeStyles.Colors.ink)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(18)
                    .background(Theme.cardSurface)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(WyldeStyles.Colors.bronze.opacity(0.25), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Daily coach check-in")
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(45)
            }

            // XP earn toast — rises above everything, auto-dismisses
            if let toast = xpToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Text("+\(toast.amount)")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(WyldeStyles.Colors.bronze)
                        Text(toast.reason)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(WyldeStyles.Colors.ink)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.cardSurface)
                    .overlay(Capsule().stroke(WyldeStyles.Colors.bronze.opacity(0.35), lineWidth: 1))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                    .padding(.bottom, 96)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                .zIndex(50)
                .allowsHitTesting(false)
            }

            Color.clear
                .frame(width: 0, height: 0)
                .onAppear {
                    badgeService.start(appState: appState)
                    maybeCoachCheckin()
                }
                .fullScreenCover(isPresented: $showCoachChat) {
                    CoachChatView().environmentObject(appState)
                }
                .fullScreenCover(item: Binding(
                    get: { badgeService.pendingCeremony.map { CeremonyBadge(badge: $0) } },
                    set: { if $0 == nil { badgeService.pendingCeremony = nil } }
                )) { wrapped in
                    BadgeCeremonyView(badge: wrapped.badge) { badgeService.pendingCeremony = nil }
                }
                .onReceive(NotificationCenter.default.publisher(for: .wyldeXPAwarded)) { note in
                    guard let amount = note.userInfo?["amount"] as? Int,
                          let reason = note.userInfo?["reason"] as? String else { return }
                    xpToastID += 1
                    let myID = xpToastID
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        xpToast = (amount, reason)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                        if xpToastID == myID {
                            withAnimation(.easeOut(duration: 0.3)) { xpToast = nil }
                        }
                    }
                }

            // All 4 tab views stay mounted simultaneously. We toggle which
            // one is visible/interactive so WKWebViews don't reload, local
            // @State doesn't reset, and scroll positions are preserved when
            // the user switches tabs.
            ZStack {
                tabContent(.today) { TodayView() }
                tabContent(.nutrition) { NutritionTabView() }
                tabContent(.future) { FutureTabView() }
                tabContent(.settings) { YouView() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            BottomTabBar()
        }
        .background(Theme.background)
        // ─── Hamburger overlay — global on every tab ──────────────
        // Sits above all tab content via the parent ZStack. Tapping
        // opens the native SettingsDrawer. Suppressed in WebView tabs
        // by hideNavScript so we don't get duplicate hamburgers.
        .overlay(alignment: .topLeading) {
            HamburgerButton {
                showSettingsDrawer = true
            }
            .padding(.leading, 16)
            .padding(.top, 12)
        }
        // Left-side slide drawer (NOT a bottom sheet). Lives inside the
        // ZStack so it can overlay every tab without being modal-stacked
        // beneath the system nav. Backdrop tap dismisses.
        .overlay(alignment: .leading) {
            if showSettingsDrawer {
                ZStack(alignment: .leading) {
                    // Backdrop — tap to close
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.25)) { showSettingsDrawer = false } }
                        .transition(.opacity)
                    // The drawer panel itself — slides from leading edge
                    SettingsDrawer(onClose: {
                        withAnimation(.easeInOut(duration: 0.25)) { showSettingsDrawer = false }
                    })
                    .environmentObject(appState)
                    .frame(width: 320, alignment: .leading)
                    .frame(maxHeight: .infinity)
                    .shadow(color: .black.opacity(0.5), radius: 24, x: 8, y: 0)
                    .transition(.move(edge: .leading))
                }
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: showSettingsDrawer)
        .overlay {
            if showWalkthrough {
                WalkthroughOverlay(isShowing: $showWalkthrough)
                    .zIndex(200)
            }
        }
    }

    /// Wraps a tab view so it stays in the hierarchy even when not selected.
    /// Hidden tabs are made fully transparent and ignore touches, but the
    /// view (and any WKWebView it contains) is preserved in memory.
    @ViewBuilder
    private func tabContent<Content: View>(_ tab: AppState.Tab, @ViewBuilder content: () -> Content) -> some View {
        let isActive = appState.selectedTab == tab
        content()
            .frame(maxWidth: .infinity)
            .clipped()
            .opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            // Don't expose hidden tabs to VoiceOver
            .accessibilityHidden(!isActive)
    }
}

// MARK: - Bottom Tab Bar

struct BottomTabBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppState.Tab.allCases, id: \.self) { tab in
                TabButton(tab: tab, isActive: appState.selectedTab == tab) {
                    #if DEBUG
                    print("[Tab] Tapped: \(tab.rawValue)")
                    #endif
                    HapticManager.shared.impact(.light)
                    withAnimation(.easeInOut(duration: 0.15)) {
                        appState.selectedTab = tab
                    }
                }
            }
        }
        .frame(height: 72)
        .padding(.bottom, Self.safeAreaBottom)
        .background(
            BlurredTabBarBackground()
                .ignoresSafeArea(edges: .bottom)
        )
    }

    /// Safe-area bottom inset — uses the key window from the foreground scene,
    /// which is more reliable than grabbing the first connected scene.
    private static var safeAreaBottom: CGFloat {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.keyWindow else {
            return 0
        }
        return window.safeAreaInsets.bottom
    }
}

struct TabButton: View {
    let tab: AppState.Tab
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Active indicator pill
                Capsule()
                    .fill(isActive ? Theme.sage : .clear)
                    .frame(width: 20, height: 2)

                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? Theme.sage : WyldeStyles.Colors.stone)

                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isActive ? .semibold : .medium))
                    .foregroundColor(isActive ? Theme.sage : WyldeStyles.Colors.stone)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Hamburger button — top-left, fixed, available on every screen

struct HamburgerButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.primaryText)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(Theme.elevatedBG.opacity(0.85))
                        .overlay(
                            Circle()
                                .stroke(Theme.primaryText.opacity(0.06), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Menu")
        .accessibilityHint("Open settings drawer")
    }
}


extension MainTabView {
    /// Once per day, on first open: the coach asks one question.
    /// The seen-flag is only set after the question is actually presented,
    /// so failures or backgrounding won't silently consume the check-in.
    fileprivate func maybeCoachCheckin() {
        let key = "wylde_coach_checkin_" + ISO8601DateFormatter().string(from: Date()).prefix(10)
        guard !UserDefaults.standard.bool(forKey: String(key)) else { return }

        let fallbacks = [
            "What would make today feel like a win — not a perfect day, just a won one?",
            "What's the one thing you're most likely to skip today — and what would it take not to?",
            "Who are you building all this for? Say it plainly.",
            "What did yesterday teach you that today should use?",
            "Where's your energy actually at right now — and what does today need from it?",
        ]
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0

        Task {
            var question = fallbacks[dayIndex % fallbacks.count]
            if let generated = await CoachService.shared.generateCheckinQuestion(appState: appState) {
                question = generated
            }
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    coachCheckin = question
                }
                // Mark seen only after the question is actually shown
                UserDefaults.standard.set(true, forKey: String(key))
            }
        }
    }
}

/// Identifiable wrapper so fullScreenCover(item:) can present a badge.
struct CeremonyBadge: Identifiable {
    let badge: WyldeBadge
    var id: String { badge.id }
}
