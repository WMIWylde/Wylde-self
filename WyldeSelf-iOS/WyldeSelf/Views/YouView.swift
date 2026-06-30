import SwiftUI

// ════════════════════════════════════════════════════════════════════
//  YouView — the You tab destination.
//
//  Hosts what used to live behind the WebView "progress" screen:
//  identity, care team, profile shortcuts, founder badge, settings.
//
//  Visual structure (top → bottom):
//      • Hero strip (curated photo + tier ladder)
//      • Profile card (name, day, streak)
//      • Identity Anchor (current phrase)
//      • Care Team card (connect with clinician)
//      • Founder badge / CTA
//      • Quick links: Identity Import, Edit Profile, Rebuild Program
//      • Destructive: Reset, Sign Out
// ════════════════════════════════════════════════════════════════════

struct YouView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCareTeam = false
    @State private var showIdentityImport = false
    @State private var showPaywall = false
    @State private var showResetConfirm = false
    @State private var showCoach = false
    @State private var showProtocol = false
    @State private var showExercises = false
    @State private var showTherapyLibrary = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    hero
                    profileCard
                    identityCard
                    careTeamCard
                    if !appState.isPro { founderCTA }
                    if appState.isFoundingMember { founderBadge }
                    quickLinks
                    destructiveLinks
                    Spacer().frame(height: 96)  // breathing room above tab bar
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(WyldeStyles.Colors.paper.ignoresSafeArea())
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showCareTeam)        { NavigationStack { CareTeamView() } }
            .sheet(isPresented: $showIdentityImport)  { IdentityImportView().environmentObject(appState) }
            .sheet(isPresented: $showPaywall)         { PaywallView().environmentObject(appState) }
            .fullScreenCover(isPresented: $showCoach)  { CoachChatView().environmentObject(appState) }
            .fullScreenCover(isPresented: $showProtocol) { ProtocolTrackerView().environmentObject(appState) }
            .sheet(isPresented: $showExercises)        { NavigationStack { ExercisesView() } }
            .fullScreenCover(isPresented: $showTherapyLibrary) { TherapyLibraryView() }
            .alert("Reset profile?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { appState.resetAllData() }
            } message: {
                Text("Wipes your local data. You'll redo onboarding. Cloud data on your account stays.")
            }
        }
    }

    // ─────────────── Hero ───────────────
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image.wylde(.youHero)
                .aspectRatio(contentMode: .fill)
                .frame(height: 180)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18))

            LinearGradient(
                colors: [.clear, .black.opacity(0.45)],
                startPoint: .top, endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 4) {
                Text(currentTier.uppercased())
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(2.5)
                    .foregroundColor(WyldeStyles.Colors.gold)
                Text(appState.userName.isEmpty ? "Your higher self" : appState.userName)
                    .font(.system(size: 26, weight: .medium, design: .serif))
                    .foregroundColor(.white)
            }
            .padding(20)
        }
        .frame(height: 180)
    }

    private var currentTier: String {
        // Ember / Forge / Steel / Wylde per CLAUDE.md
        switch appState.currentDay {
        case ..<14:   return "Ember"
        case 14..<60: return "Forge"
        case 60..<180:return "Steel"
        default:      return "Wylde"
        }
    }

    // ─────────────── Profile card ───────────────
    private var profileCard: some View {
        SurfaceCard {
            HStack(spacing: 14) {
                avatar(letter: avatarLetter)
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.userName.isEmpty ? "Wylde Self" : appState.userName)
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundColor(WyldeStyles.Colors.ink)
                    HStack(spacing: 6) {
                        statChip("Day \(appState.currentDay)")
                        statChip("\(appState.streak)-day streak", muted: appState.streak == 0)
                    }
                }
                Spacer()
                NavigationLink {
                    EmptyView()  // placeholder — wire to your Edit Profile flow
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(WyldeStyles.Colors.stone)
                }
            }
        }
    }

    private var avatarLetter: String {
        let trimmed = appState.userName.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "W" }
        return String(first).uppercased()
    }

    private func avatar(letter: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(
                    colors: [WyldeStyles.Colors.bone, WyldeStyles.Colors.sand.opacity(0.6)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(WyldeStyles.Colors.charcoal.opacity(0.10), lineWidth: 1)
                )
                .frame(width: 50, height: 50)
            Text(letter)
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundColor(WyldeStyles.Colors.ink)
        }
    }

    private func statChip(_ text: String, muted: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(muted ? WyldeStyles.Colors.stone : WyldeStyles.Colors.charcoal)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(muted ? WyldeStyles.Colors.bone.opacity(0.4) : WyldeStyles.Colors.bone.opacity(0.8))
            .clipShape(Capsule())
    }

    // ─────────────── Identity card ───────────────
    private var identityCard: some View {
        Button {
            showIdentityImport = true
            HapticManager.shared.impact(.light)
        } label: {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("IDENTITY ANCHOR")
                    Text(appState.hasIdentityProfile ? "You are becoming."
                                                     : "Tell us who you're becoming.")
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundColor(WyldeStyles.Colors.ink)
                        .multilineTextAlignment(.leading)
                    Text(appState.hasIdentityProfile
                         ? "Review or refresh how your guide reads you."
                         : "Paste a few links + a paragraph. Your guide adapts to who you actually are.")
                        .font(.system(size: 13.5))
                        .foregroundColor(WyldeStyles.Colors.stone)
                        .lineSpacing(2)
                    HStack(spacing: 6) {
                        Text(appState.hasIdentityProfile ? "Refresh" : "Start now")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(WyldeStyles.Colors.bronze)
                    .padding(.top, 4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // ─────────────── Care Team card (THE BRIDGE TO CLINICAL) ───────────────
    private var careTeamCard: some View {
        Button {
            showCareTeam = true
            HapticManager.shared.impact(.light)
        } label: {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(WyldeStyles.Colors.sage)
                        Text("CARE TEAM")
                            .font(.system(size: 10.5, weight: .bold))
                            .tracking(2)
                            .foregroundColor(WyldeStyles.Colors.sage)
                    }
                    Text("Share your data with your clinician.")
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundColor(WyldeStyles.Colors.ink)
                    Text("Once you've established care, give them visibility into your daily journey, biometric trends, and progress. You stay in control.")
                        .font(.system(size: 13.5))
                        .foregroundColor(WyldeStyles.Colors.stone)
                        .lineSpacing(2)
                    HStack(spacing: 6) {
                        Text("Connect with clinician")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(WyldeStyles.Colors.sage)
                    .padding(.top, 4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // ─────────────── Founder CTA / badge ───────────────
    private var founderCTA: some View {
        Button {
            showPaywall = true
            HapticManager.shared.impact(.light)
        } label: {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle().fill(WyldeStyles.Colors.gold).frame(width: 5, height: 5)
                        Text("FOUNDING MEMBER")
                            .font(.system(size: 9.5, weight: .bold))
                            .tracking(2.2)
                            .foregroundColor(WyldeStyles.Colors.gold)
                    }
                    Text("Sponsor the work. Lock in lifetime.")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundColor(WyldeStyles.Colors.ink)
                    Text("First 1,000 members. Founder pricing forever.")
                        .font(.system(size: 12.5))
                        .foregroundColor(WyldeStyles.Colors.stone)
                    HStack(spacing: 4) {
                        Text("See the offer")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(WyldeStyles.Colors.gold)
                    .padding(.top, 4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var founderBadge: some View {
        SurfaceCard {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22))
                    .foregroundColor(WyldeStyles.Colors.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("FOUNDING MEMBER #\(appState.foundingMemberNumber)")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(WyldeStyles.Colors.gold)
                    Text("Lifetime access locked.")
                        .font(.system(size: 13))
                        .foregroundColor(WyldeStyles.Colors.stone)
                }
                Spacer()
            }
        }
    }

    // ─────────────── Quick links ───────────────
    private var quickLinks: some View {
        VStack(spacing: 0) {
            row(icon: "brain.head.profile",      label: "AI Coach")                { showCoach = true }
            divider
            row(icon: "pills.fill",              label: "Protocol Tracker")         { showProtocol = true }
            divider
            row(icon: "heart.text.square",       label: "Health Data")              { /* wire to HealthKit view */ }
            divider
            row(icon: "person.2.fill",           label: "Care Team")               { showCareTeam = true }
            divider
            row(icon: "book.fill",               label: "Therapy Library")           { showTherapyLibrary = true }
            divider
            row(icon: "books.vertical.fill",     label: "Exercise Library")         { showExercises = true }
            divider
            row(icon: "person.fill",             label: "Edit Profile")             { /* wire to edit profile */ }
        }
        .background(Theme.cardSurface)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(WyldeStyles.Colors.charcoal.opacity(0.06), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }

    private var destructiveLinks: some View {
        VStack(spacing: 0) {
            row(icon: "trash", label: "Reset profile", destructive: false) { showResetConfirm = true }
            divider
            row(icon: "rectangle.portrait.and.arrow.right", label: "Sign out", destructive: true) {
                Task { await AuthService.shared.signOut() }
                appState.isAuthenticated = false
            }
        }
        .background(Theme.cardSurface)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(WyldeStyles.Colors.charcoal.opacity(0.06), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }

    private func row(icon: String, label: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(destructive ? WyldeStyles.Colors.error : WyldeStyles.Colors.charcoal)
                    .frame(width: 22)
                Text(label)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(destructive ? WyldeStyles.Colors.error : WyldeStyles.Colors.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WyldeStyles.Colors.stone)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(WyldeStyles.Colors.charcoal.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 54)
    }
}

// ─────────────── small reusable bits used in YouView ───────────────

private struct SurfaceCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardSurface)
            .overlay(RoundedRectangle(cornerRadius: WyldeStyles.Layout.cardCornerRadius)
                .stroke(WyldeStyles.Colors.charcoal.opacity(0.06), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: WyldeStyles.Layout.cardCornerRadius))
            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold))
            .tracking(2)
            .foregroundColor(WyldeStyles.Colors.bronze)
    }
}

#Preview {
    YouView()
        .environmentObject(AppState())
}
