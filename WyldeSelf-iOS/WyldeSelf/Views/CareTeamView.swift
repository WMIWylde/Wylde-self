import SwiftUI

// ════════════════════════════════════════════════════════════════════
//  CareTeamView — patient gives a clinician access to their data.
//
//  Mounted from YouView. Four states driven by CareTeamViewModel.mode:
//      .empty       not connected, no pending invite
//      .generated   patient has an outstanding share code
//      .connected   patient is linked to a clinic
//      .enterCode   patient typing in a code their clinician gave them
//
//  All styling uses WyldeStyles tokens so it stays on-brand.
// ════════════════════════════════════════════════════════════════════

struct CareTeamView: View {
    @StateObject private var vm = CareTeamViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var consentAccepted = false
    @State private var showConsentDetail = false

    var body: some View {
        ZStack {
            WyldeStyles.Colors.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    switch vm.mode {
                    case .empty:     emptyState
                    case .generated: generatedState
                    case .connected: connectedState
                    case .enterCode: enterCodeState
                    }

                    if let err = vm.error {
                        Text(err)
                            .font(WyldeStyles.Typography.Body.small)
                            .foregroundColor(WyldeStyles.Colors.error)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(WyldeStyles.Colors.error.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, WyldeStyles.Spacing.lg)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Care team")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") { dismiss() }
                    .foregroundColor(WyldeStyles.Colors.stone)
            }
        }
        .task { await vm.load() }
    }

    // ────────── header ──────────
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch vm.mode {
            case .empty:
                serifTitle("Share your data with your clinician.")
                bodyText("Once you've established care with a clinician, give them visibility into your daily journey, biometric trends, and progress. You stay in control — revoke any time.")
            case .generated:
                serifTitle("Share this code with your clinician.")
                bodyText("They enter this in their Wylde Self clinical dashboard. As soon as they accept, your daily data begins flowing to them.")
            case .connected:
                serifTitle("You're connected.")
                bodyText("Your daily check-ins and biometric data flow to your clinician's dashboard. They can review your progress and suggest adjustments.")
            case .enterCode:
                serifTitle("Enter your clinician's code.")
                bodyText("Your clinician generated a code for you. Enter it to connect your Wylde Self account to their practice.")
            }
        }
        .padding(.bottom, 4)
    }

    // ────────── empty / initial ──────────
    @ViewBuilder private var emptyState: some View {
        // Soft imagery above the consent so the "before you connect" flow
        // doesn't lead with a wall of legal copy.
        Image.wylde(.emptyStateCalm)
            .aspectRatio(contentMode: .fill)
            .frame(height: 120)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(0.85)
            .padding(.bottom, 4)

        // Consent section — must accept before generating code
        WyldeCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 16))
                        .foregroundColor(WyldeStyles.Colors.sage)
                    Text("DATA SHARING CONSENT")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(WyldeStyles.Colors.sage)
                }

                Text("Before connecting with a clinician, please review what data will be shared.")
                    .font(WyldeStyles.Typography.Body.small)
                    .foregroundColor(WyldeStyles.Colors.stone)
                    .lineSpacing(2)

                VStack(alignment: .leading, spacing: 8) {
                    consentBullet("Your clinician will see:", items: [
                        "Daily check-ins (mood, energy, sleep, weight)",
                        "Protocol adherence and dose logs",
                        "Wylde Score and progress trends",
                        "Messages you exchange"
                    ])
                    consentBullet("Your clinician will NOT see:", items: [
                        "AI coach conversations",
                        "Future vision images",
                        "Personal journal entries",
                        "Workout and nutrition details (unless in check-ins)"
                    ])
                }

                Text("You initiate the connection and can revoke access at any time.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WyldeStyles.Colors.ink)
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    Button { showConsentDetail = true } label: {
                        Text("Full Consent Form")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(WyldeStyles.Colors.sage)
                            .underline()
                    }
                    Text("·")
                        .foregroundColor(WyldeStyles.Colors.stone)
                    Button { showConsentDetail = true } label: {
                        Text("Privacy Policy")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(WyldeStyles.Colors.sage)
                            .underline()
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        consentAccepted.toggle()
                    } label: {
                        Image(systemName: consentAccepted ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22))
                            .foregroundColor(consentAccepted ? WyldeStyles.Colors.sage : WyldeStyles.Colors.stone)
                    }
                    .buttonStyle(.plain)

                    Text("I understand and agree to share my health data with my clinician")
                        .font(.system(size: 13))
                        .foregroundColor(WyldeStyles.Colors.ink)
                }
                .padding(.top, 6)
            }
        }
        .sheet(isPresented: $showConsentDetail) {
            consentWebView
        }

        if consentAccepted {
            WyldeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Generate a code for them")
                        .font(.system(size: 19, weight: .medium, design: .serif))
                        .foregroundColor(WyldeStyles.Colors.ink)
                    Text("Create an 8-character code and share it with your clinician. They enter it in their Wylde Self dashboard to connect.")
                        .font(WyldeStyles.Typography.Body.small)
                        .foregroundColor(WyldeStyles.Colors.stone)
                        .lineSpacing(2)
                    primaryButton("Generate share code", loading: vm.loading) {
                        Task { await vm.generateCode() }
                    }
                    .padding(.top, 4)
                }
            }

            divider("or")

            WyldeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter a code from them")
                        .font(.system(size: 19, weight: .medium, design: .serif))
                        .foregroundColor(WyldeStyles.Colors.ink)
                    Text("Got a code from your clinician? Enter it below to start sharing your data with their practice.")
                        .font(WyldeStyles.Typography.Body.small)
                        .foregroundColor(WyldeStyles.Colors.stone)
                        .lineSpacing(2)
                    ghostButton("I have a code") {
                        vm.enterCode()
                    }
                    .padding(.top, 4)
                }
            }
        }

        disclosure(
            title: "What \"sharing\" means",
            body:  "Your clinician sees your daily check-ins, biometric readings, and progress trajectory. They can suggest protocol adjustments — you stay the decision-maker. You can revoke access from this screen at any time."
        )
    }

    // ────────── generated ──────────
    @ViewBuilder private var generatedState: some View {
        codeBox(code: vm.generatedCode ?? "—", expires: vm.generatedExpiresAt)

        if let share = vm.generatedShareText {
            ShareLink(item: share) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share with your clinician").font(.system(size: 15, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(WyldeStyles.Colors.paper)
                .background(WyldeStyles.Colors.ink)
                .clipShape(Capsule())
            }
        }

        Button {
            UIPasteboard.general.string = vm.generatedCode
            HapticManager.shared.impact(.light)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.doc")
                Text("Copy code").font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundColor(WyldeStyles.Colors.ink)
            .overlay(Capsule().stroke(WyldeStyles.Colors.charcoal.opacity(0.14), lineWidth: 1))
        }

        disclosure(
            title: "One code, one clinician",
            body:  "This code is single-use. Once a clinician accepts, you'll see them listed here. You can revoke access at any time."
        )

        Button {
            vm.backToEmpty()
        } label: {
            Text("← Back to options")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WyldeStyles.Colors.sage)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }

    // ────────── connected ──────────
    @ViewBuilder private var connectedState: some View {
        // Cinematic hero — signals the shift from "empty / setup" to
        // "you're connected to real clinical care." Only renders in the
        // connected state.
        Image.wylde(.careTeamHero)
            .aspectRatio(contentMode: .fill)
            .frame(height: 160)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(WyldeStyles.Colors.charcoal.opacity(0.06), lineWidth: 1)
            )
            .padding(.bottom, 4)

        WyldeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("CURRENTLY SHARING WITH")
                    .font(WyldeStyles.Typography.Label.small)
                    .tracking(2)
                    .foregroundColor(WyldeStyles.Colors.sage)
                Text(vm.clinicName ?? "Your clinic")
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundColor(WyldeStyles.Colors.ink)
                if let linked = vm.linkedDateString {
                    Text("Linked \(linked)")
                        .font(WyldeStyles.Typography.Body.small)
                        .foregroundColor(WyldeStyles.Colors.stone)
                }

                HStack(spacing: 10) {
                    Circle().fill(WyldeStyles.Colors.sage).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active care relationship")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(WyldeStyles.Colors.ink)
                        Text("Data sharing · revokable anytime")
                            .font(.system(size: 12))
                            .foregroundColor(WyldeStyles.Colors.stone)
                    }
                }
                .padding(14)
                .background(WyldeStyles.Colors.sage.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(WyldeStyles.Colors.sage.opacity(0.30), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.top, 6)
            }
        }

        // Messages + Protocol Tracker
        HStack(spacing: 10) {
            Button { vm.showMessages = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 14))
                    Text("Messages")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(WyldeStyles.Colors.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(WyldeStyles.Colors.bone)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button { vm.showProtocol = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 14))
                    Text("Protocol")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(WyldeStyles.Colors.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(WyldeStyles.Colors.bone)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .fullScreenCover(isPresented: $vm.showMessages) {
            CareMessagingView()
        }
        .fullScreenCover(isPresented: $vm.showProtocol) {
            ProtocolTrackerView()
        }

        WyldeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Revoke access")
                    .font(.system(size: 19, weight: .medium, design: .serif))
                    .foregroundColor(WyldeStyles.Colors.ink)
                Text("If you stop seeing this clinician, you can disconnect at any time. They'll keep your historical records but won't receive new data.")
                    .font(WyldeStyles.Typography.Body.small)
                    .foregroundColor(WyldeStyles.Colors.stone)
                Button {
                    Task { await vm.revokeAccess() }
                } label: {
                    Text("Disconnect from \(vm.clinicName ?? "this clinic")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(WyldeStyles.Colors.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .overlay(Capsule().stroke(WyldeStyles.Colors.error.opacity(0.30), lineWidth: 1))
                }
                .disabled(vm.loading)
            }
        }

        disclosure(
            title: "Data sharing is one-direction",
            body:  "Your clinician can see your data and suggest protocol changes. They cannot modify your account, biometric readings, or daily check-ins. You stay the decision-maker."
        )
    }

    // ────────── enter clinic code ──────────
    @ViewBuilder private var enterCodeState: some View {
        WyldeCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("8-character code")
                    .font(WyldeStyles.Typography.Label.large)
                    .foregroundColor(WyldeStyles.Colors.stone)

                TextField("A7K3-X9P2", text: $vm.codeInput)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .tracking(4)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(WyldeStyles.Colors.paper)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(WyldeStyles.Colors.charcoal.opacity(0.08), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                primaryButton("Connect", loading: vm.loading) {
                    Task { await vm.submitClinicCode() }
                }
                .disabled(vm.codeInput.count < 8)
                .opacity(vm.codeInput.count < 8 ? 0.5 : 1)
            }
        }

        Button {
            vm.backToEmpty()
        } label: {
            Text("← Back to options")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WyldeStyles.Colors.sage)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }

    // ════════════ shared small components ════════════
    private func serifTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .regular, design: .serif))
            .foregroundColor(WyldeStyles.Colors.ink)
            .lineSpacing(2)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(WyldeStyles.Typography.Body.medium)
            .foregroundColor(WyldeStyles.Colors.stone)
            .lineSpacing(2)
    }

    private func primaryButton(_ title: String, loading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if loading { ProgressView().tint(WyldeStyles.Colors.paper).scaleEffect(0.8) }
                Text(title).font(.system(size: 15, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(WyldeStyles.Colors.paper)
            .background(WyldeStyles.Colors.ink)
            .clipShape(Capsule())
        }
        .disabled(loading)
    }

    private func ghostButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundColor(WyldeStyles.Colors.ink)
                .overlay(Capsule().stroke(WyldeStyles.Colors.charcoal.opacity(0.14), lineWidth: 1))
        }
    }

    private func codeBox(code: String, expires: String?) -> some View {
        VStack(spacing: 8) {
            Text("YOUR INVITE CODE")
                .font(WyldeStyles.Typography.Label.small)
                .tracking(3)
                .foregroundColor(WyldeStyles.Colors.stone)
            Text(code)
                .font(.system(size: 36, weight: .medium, design: .serif))
                .tracking(6)
                .foregroundColor(WyldeStyles.Colors.gold)
            if let expires {
                Text("Expires \(expires)")
                    .font(.system(size: 12))
                    .foregroundColor(WyldeStyles.Colors.stone)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(WyldeStyles.Colors.paper)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(WyldeStyles.Colors.gold, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func disclosure(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(WyldeStyles.Colors.ink)
            Text(body)
                .font(.system(size: 12))
                .foregroundColor(WyldeStyles.Colors.stone)
                .lineSpacing(2)
        }
        .padding(14)
        .background(WyldeStyles.Colors.bone.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func divider(_ text: String) -> some View {
        HStack(spacing: 14) {
            Rectangle().fill(WyldeStyles.Colors.charcoal.opacity(0.08)).frame(height: 1)
            Text(text.uppercased())
                .font(.system(size: 11.5, weight: .medium))
                .tracking(1.6)
                .foregroundColor(WyldeStyles.Colors.stone)
            Rectangle().fill(WyldeStyles.Colors.charcoal.opacity(0.08)).frame(height: 1)
        }
        .padding(.vertical, 4)
    }

    // ────────── consent helpers ──────────

    private func consentBullet(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(WyldeStyles.Colors.ink)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundColor(WyldeStyles.Colors.stone)
                    Text(item)
                        .font(.system(size: 12))
                        .foregroundColor(WyldeStyles.Colors.stone)
                }
            }
        }
    }

    private var consentWebView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Health Data Sharing Consent")
                        .font(.system(size: 22, weight: .medium, design: .serif))
                        .foregroundColor(WyldeStyles.Colors.ink)

                    Group {
                        consentSection("What is shared", "When you connect with a clinician, they gain visibility into your daily check-ins (mood, energy, sleep, weight), protocol adherence and dose logs, your Wylde Score and progress trends, and any messages you exchange.")

                        consentSection("What is NOT shared", "Your AI coach conversations, future vision images, personal journal entries, and detailed workout/nutrition logs remain private and are never visible to your clinician.")

                        consentSection("Your control", "You initiate every connection by generating a share code. You can revoke access at any time from the Care Team screen. Revoking access immediately stops your clinician from seeing new data.")

                        consentSection("Data security", "All data is encrypted in transit (TLS) and at rest. Clinical data is protected by row-level security policies. Your clinician can only see data for patients who have explicitly connected with them.")

                        consentSection("Not for emergencies", "This platform is not designed for emergency communications. If you are experiencing a medical emergency, call 911 or your local emergency services.")
                    }

                    Text("Last updated: July 2026")
                        .font(.system(size: 11))
                        .foregroundColor(WyldeStyles.Colors.stone)
                        .padding(.top, 8)
                }
                .padding(24)
            }
            .background(WyldeStyles.Colors.paper)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showConsentDetail = false }
                        .foregroundColor(WyldeStyles.Colors.sage)
                }
            }
        }
    }

    private func consentSection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(WyldeStyles.Colors.ink)
            Text(body)
                .font(.system(size: 13))
                .foregroundColor(WyldeStyles.Colors.stone)
                .lineSpacing(3)
        }
    }
}

// ─────────────── reusable card ───────────────
private struct WyldeCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(22)
            .background(Theme.cardSurface)
            .overlay(RoundedRectangle(cornerRadius: WyldeStyles.Layout.cardCornerRadius)
                .stroke(WyldeStyles.Colors.charcoal.opacity(0.06), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: WyldeStyles.Layout.cardCornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
    }
}

// ════════════════════════════════════════════════════════════════════
//  View model
// ════════════════════════════════════════════════════════════════════

@MainActor
final class CareTeamViewModel: ObservableObject {

    enum Mode: Equatable { case empty, generated, connected, enterCode }

    @Published var mode: Mode = .empty
    @Published var loading: Bool = false
    @Published var error: String?

    @Published var generatedCode: String?
    @Published var generatedExpiresAt: String?
    @Published var generatedShareText: String?

    @Published var clinicName: String?
    @Published var linkedDateString: String?

    @Published var codeInput: String = ""
    @Published var showMessages: Bool = false
    @Published var showProtocol: Bool = false

    func load() async {
        loading = true; defer { loading = false }
        error = nil
        do {
            let r = try await ClinicalAPI.careRelationships()
            if let active = r.active_relationship {
                clinicName = active.clinic?.name ?? "Your clinic"
                linkedDateString = formatDate(active.linked_at)
                mode = .connected
                // Refresh CheckinSync so it starts syncing
                await CheckinSync.shared.refreshRelationshipFlag()
            } else if let pending = r.pending_invites.first(where: { $0.status == "pending" }) {
                generatedCode = pending.code
                generatedExpiresAt = formatDate(pending.expires_at)
                mode = .generated
            } else {
                mode = .empty
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func generateCode(note: String? = nil) async {
        loading = true; defer { loading = false }
        error = nil
        #if DEBUG
        print("[CareTeam] Generating code...")
        #endif
        do {
            let r = try await ClinicalAPI.generateCareInvite(message: note)
            #if DEBUG
            print("[CareTeam] Code generated: \(r.code)")
            #endif
            generatedCode = r.code
            generatedExpiresAt = formatDate(r.expires_at)
            generatedShareText = r.share_text
            mode = .generated
        } catch {
            #if DEBUG
            print("[CareTeam] Error: \(error)")
            #endif
            self.error = error.localizedDescription
        }
    }

    func enterCode() {
        mode = .enterCode
        codeInput = ""
        error = nil
    }

    func submitClinicCode() async {
        loading = true; defer { loading = false }
        error = nil
        do {
            _ = try await ClinicalAPI.acceptClinicCode(codeInput.trimmingCharacters(in: .whitespaces))
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func revokeAccess() async {
        loading = true; defer { loading = false }
        error = nil
        do {
            try await ClinicalAPI.revokeAccess()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func backToEmpty() {
        mode = .empty
        codeInput = ""
        error = nil
    }

    private func formatDate(_ iso: String) -> String {
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso8601.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) ?? Date()
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .none
        return out.string(from: date)
    }
}
