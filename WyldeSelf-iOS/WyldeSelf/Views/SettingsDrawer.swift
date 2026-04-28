import SwiftUI
import WebKit

// ════════════════════════════════════════════════════════════════════
//  SettingsDrawer — native SwiftUI version of the web settings drawer.
//  Mirrors the same links so iOS feels consistent with the web app:
//      Founding Member CTA (only if !isPro)
//      Exercise Library
//      Nutrition
//      Edit Profile
//      Rebuild My Program
//      Reset Profile
//      Sign Out
//
//  Presented as a native sheet from MainTabView so it overlays every
//  tab identically. Matches the dark brand palette.
// ════════════════════════════════════════════════════════════════════

struct SettingsDrawer: View {
    @EnvironmentObject var appState: AppState
    /// Optional close callback — used when the drawer is presented as a
    /// custom side overlay (no sheet `.dismiss` available). Falls back to
    /// SwiftUI's environment dismiss when called from a sheet.
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismissEnv

    @State private var showPaywall = false
    @State private var showResetConfirm = false
    @State private var showIdentityImport = false

    /// Centralized dismiss — calls custom onClose if provided, otherwise
    /// falls back to SwiftUI sheet dismiss.
    private func dismiss() {
        if let onClose = onClose { onClose() } else { dismissEnv() }
    }

    var body: some View {
        // Defensive structure: a ZStack with the drawer panel's own opaque
        // dark background, ensuring the panel is fully self-contained
        // regardless of how it's presented (sheet OR side overlay).
        // VStack inside fills the panel; ScrollView holds the link list
        // so long lists scroll properly without breaking layout.
        ZStack {
            Color(hex: "0B0B0B")
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // ── Header (fixed at top) ──────────────────────────
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WYLDE SELF")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2.5)
                            .foregroundColor(Color(hex: "C8A96E"))
                        Text(appState.userName.isEmpty ? "Your account" : appState.userName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(hex: "F4F1E8"))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "A6A29A"))
                            .frame(width: 36, height: 36)
                            .background(Color(hex: "161616"))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 22)

                // ── Scrollable middle: founder CTA + nav links ────
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Founding Member CTA (only if not Pro)
                        if !appState.isPro {
                            founderCTA
                        } else if appState.isFoundingMember {
                            founderBadge
                        }

                        // Primary nav links — all stacked vertically
                        VStack(alignment: .leading, spacing: 2) {
                            DrawerLink(
                                icon: "books.vertical.fill",
                                label: "Exercise Library",
                                action: { openWebScreen("library") }
                            )
                            DrawerLink(
                                icon: "fork.knife",
                                label: "Nutrition",
                                action: { openWebScreen("nutrition") }
                            )
                            DrawerLink(
                                icon: "brain.head.profile",
                                label: "Identity Import",
                                action: {
                                    HapticManager.shared.impact(.light)
                                    showIdentityImport = true
                                }
                            )
                            DrawerLink(
                                icon: "person.fill",
                                label: "Edit Profile",
                                action: { openWebFunction("openEditProfile") }
                            )
                            DrawerLink(
                                icon: "arrow.triangle.2.circlepath",
                                label: "Rebuild My Program",
                                action: { openWebFunction("regenerateProgram") }
                            )
                        }
                        .padding(.horizontal, 14)

                        // Divider
                        Rectangle()
                            .fill(Color(hex: "F4F1E8").opacity(0.06))
                            .frame(height: 1)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)

                        // Destructive actions
                        VStack(alignment: .leading, spacing: 2) {
                            DrawerLink(
                                icon: "trash",
                                label: "Reset Profile",
                                destructive: false,
                                action: { showResetConfirm = true }
                            )
                            DrawerLink(
                                icon: "rectangle.portrait.and.arrow.right",
                                label: "Sign Out",
                                destructive: true,
                                action: signOutAndDismiss
                            )
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 32)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        // Sheets bubble up over the entire app — not constrained inside
        // the drawer's narrow column.
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(appState)
        }
        .sheet(isPresented: $showIdentityImport) {
            IdentityImportView().environmentObject(appState)
        }
        .alert("Reset profile?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                appState.resetAllData()
                dismiss()
            }
        } message: {
            Text("Wipes your local data. You'll redo onboarding. Cloud data on your account stays.")
        }
    }

    // MARK: - Founder CTA / badge

    private var founderCTA: some View {
        Button {
            HapticManager.shared.impact(.light)
            showPaywall = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: "C8A96E")).frame(width: 5, height: 5)
                    Text("FOUNDING MEMBER")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2.2)
                        .foregroundColor(Color(hex: "C8A96E"))
                }
                Text("Sponsor the work. Lock in lifetime.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "F4F1E8"))
                    .multilineTextAlignment(.leading)
                Text("First 1,000 members. Founder pricing forever.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "A6A29A"))
                HStack(spacing: 4) {
                    Text("See the offer")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(Color(hex: "C8A96E"))
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "111111"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "C8A96E").opacity(0.30), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var founderBadge: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundColor(Color(hex: "C8A96E"))
            VStack(alignment: .leading, spacing: 2) {
                Text("FOUNDING MEMBER #\(appState.foundingMemberNumber)")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "C8A96E"))
                Text("Lifetime access locked.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "A6A29A"))
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "111111"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "C8A96E").opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Actions

    /// Switches the active tab to a WebView tab and asks the web app to
    /// route to the given screen. Nutrition/Library aren't tabs in the
    /// reduced 4-tab nav, so they go through the Coach WebView with a
    /// showScreen() call. (Future enhancement: dedicated routing.)
    private func openWebScreen(_ screenId: String) {
        HapticManager.shared.impact(.light)
        // For now, library has its own native tab — switch to it directly
        if screenId == "library" {
            appState.selectedTab = .exercises
            dismiss()
            return
        }
        // Other web screens — switch to Future tab + post navigate notification
        appState.selectedTab = .future
        NotificationCenter.default.post(
            name: .navigateToScreen,
            object: nil,
            userInfo: ["screen": screenId]
        )
        dismiss()
    }

    /// Triggers a web JS function in the active WebView (Edit Profile,
    /// Regenerate Program both live in the web layer for now).
    private func openWebFunction(_ jsFunction: String) {
        HapticManager.shared.impact(.light)
        appState.selectedTab = .future
        NotificationCenter.default.post(
            name: .invokeWebFunction,
            object: nil,
            userInfo: ["function": jsFunction]
        )
        dismiss()
    }

    private func signOutAndDismiss() {
        HapticManager.shared.notification(.warning)
        appState.isAuthenticated = false
        appState.resetAllData()
        // Tell the embedded web layer to sign out of Supabase too
        NotificationCenter.default.post(
            name: .invokeWebFunction,
            object: nil,
            userInfo: ["function": "signOutUser"]
        )
        dismiss()
    }
}

// MARK: - Single drawer link row

private struct DrawerLink: View {
    let icon: String
    let label: String
    var destructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(destructive ? Color(hex: "C26B5A") : Color(hex: "A6A29A"))
                    .frame(width: 22)
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(destructive ? Color(hex: "C26B5A") : Color(hex: "F4F1E8"))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "6E6B65"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension Notification.Name {
    static let invokeWebFunction = Notification.Name("invokeWebFunction")
}
