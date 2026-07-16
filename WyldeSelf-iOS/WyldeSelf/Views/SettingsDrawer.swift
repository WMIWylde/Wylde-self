import SwiftUI

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
    @State private var showExercises = false

    /// Centralized dismiss — calls custom onClose if provided, otherwise
    /// falls back to SwiftUI sheet dismiss.
    private func dismiss() {
        if let onClose = onClose { onClose() } else { dismissEnv() }
    }

    var body: some View {
        // Plain top-down VStack — no ScrollView wrapping, no nested ZStack.
        // The drawer fits 8 short items easily on any device, so the
        // earlier ScrollView was overkill and introduced layout bugs.
        // Background applied at the panel boundary in MainTabView.
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                // Bundled brand logo from Assets.xcassets/LogoMark.imageset
                Image("LogoMark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("WYLDE SELF")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(Color(hex: "C8A96E"))
                    Text(appState.userName.isEmpty ? "Your account" : appState.userName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Theme.primaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.secondaryText)
                        .frame(width: 36, height: 36)
                        .background(Theme.chipBG)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)

            // ── Founder CTA (or badge if Pro) ───────────────────
            // HIDDEN for TestFlight — no purchase entry points until IAP is approved
            // if !appState.isPro {
            //     founderCTA
            // } else if appState.isFoundingMember {
            //     founderBadge
            // }

            // ── Nav links — flat list ──────────────────────────
            DrawerLink(icon: "books.vertical.fill",     label: "Exercise Library",   action: {
                HapticManager.shared.impact(.light)
                showExercises = true
            })
            DrawerLink(icon: "fork.knife",              label: "Nutrition",          action: openNutritionTab)
            DrawerLink(icon: "brain.head.profile",      label: "Identity Import",    action: {
                HapticManager.shared.impact(.light)
                showIdentityImport = true
            })
            // TODO: Wire up native Edit Profile and Rebuild My Program screens
            // (Previously routed through the WebView bridge which has been removed.)

            // ── Appearance ─────────────────────────────────────
            appearanceControl

            // ── Divider ────────────────────────────────────────
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            // ── Destructive actions ────────────────────────────
            DrawerLink(icon: "trash",                              label: "Reset Profile", action: { showResetConfirm = true })
            DrawerLink(icon: "rectangle.portrait.and.arrow.right", label: "Sign Out",      destructive: true, action: signOutAndDismiss)

            // Push everything to the top
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.appBG)
        // Sheets bubble up over the entire app — not constrained inside
        // the drawer's narrow column.
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(appState)
        }
        .sheet(isPresented: $showIdentityImport) {
            IdentityImportView().environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showExercises) {
            NavigationStack { ExercisesView() }
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

    // MARK: - Appearance

    /// Light / dark / system toggle. Binds to `appState.appearanceMode`,
    /// which persists to UserDefaults and drives `.preferredColorScheme`
    /// on the root in WyldeSelfApp. Never tied to any other signal —
    /// pure user preference.
    private var appearanceControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("APPEARANCE")
                .font(.system(size: 9, weight: .bold))
                .tracking(2.2)
                .foregroundColor(Theme.tertiaryText)
            Picker("Appearance", selection: Binding(
                get: { appState.appearanceMode },
                set: { newValue in
                    HapticManager.shared.impact(.light)
                    appState.appearanceMode = newValue
                }
            )) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 2)
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
                    .foregroundColor(Theme.primaryText)
                    .multilineTextAlignment(.leading)
                Text("First 1,000 members. Founder pricing forever.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.secondaryText)
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
                    .fill(Theme.elevatedBG)
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
                    .foregroundColor(Theme.secondaryText)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.elevatedBG)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "C8A96E").opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Actions

    /// Switches to the Nutrition tab. Previously this went through
    /// `openWebScreen("nutrition")`, which unrecognized-fell-through to
    /// the Future tab (bug). Now it routes directly.
    private func openNutritionTab() {
        HapticManager.shared.impact(.light)
        appState.selectedTab = .nutrition
        dismiss()
    }

    private func signOutAndDismiss() {
        HapticManager.shared.notification(.warning)
        Task { await AuthService.shared.signOut() }
        appState.isAuthenticated = false
        appState.resetAllData()
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
                    .foregroundColor(destructive ? Color(hex: "C26B5A") : Theme.secondaryText)
                    .frame(width: 22)
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(destructive ? Color(hex: "C26B5A") : Theme.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.tertiaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

