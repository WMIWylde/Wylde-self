import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettingsDrawer = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // All 5 tab views stay mounted simultaneously. We toggle which
            // one is visible/interactive so WKWebViews don't reload, local
            // @State doesn't reset, and scroll positions are preserved when
            // the user switches tabs.
            ZStack {
                tabContent(.today) { TodayView() }
                tabContent(.exercises) { ExercisesView() }
                tabContent(.future) { WebViewScreen(path: "#future") }
                tabContent(.coach) { WebViewScreen(path: "#coach") }
                tabContent(.settings) { WebViewScreen(path: "#progress") }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            BottomTabBar()
        }
        .background(Theme.background)
        .ignoresSafeArea(.keyboard)
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
    }

    /// Wraps a tab view so it stays in the hierarchy even when not selected.
    /// Hidden tabs are made fully transparent and ignore touches, but the
    /// view (and any WKWebView it contains) is preserved in memory.
    @ViewBuilder
    private func tabContent<Content: View>(_ tab: AppState.Tab, @ViewBuilder content: () -> Content) -> some View {
        let isActive = appState.selectedTab == tab
        content()
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
                    HapticManager.shared.impact(.light)
                    withAnimation(.easeInOut(duration: 0.15)) {
                        appState.selectedTab = tab
                    }
                }
            }
        }
        .frame(height: 72)
        .padding(.bottom, safeAreaBottom)
        .background(
            Rectangle()
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var safeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
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
                    .foregroundColor(isActive ? Theme.sage : Color(hex: "999999"))

                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isActive ? .semibold : .medium))
                    .foregroundColor(isActive ? Theme.sage : Color(hex: "999999"))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
                .foregroundColor(Color(hex: "F4F1E8"))
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(Color(hex: "111111").opacity(0.85))
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "F4F1E8").opacity(0.06), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
