import SwiftUI

// ════════════════════════════════════════════════════════════════════
//  SignInView — magic-link sign-in.
//
//  Shown by ContentView when AppState.isAuthenticated == false.
//  Calls AuthService.shared.sendMagicLink(...). The Supabase email
//  redirect URL is `wyldeself://auth/callback` — handled by
//  WyldeSelfApp's .onOpenURL hook which forwards to
//  AuthService.handleCallback(_:).
// ════════════════════════════════════════════════════════════════════

struct SignInView: View {
    enum AuthMode { case signIn, signUp, magicLink }

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var mode: AuthMode = .signIn
    @State private var sending: Bool = false
    @State private var sent: Bool = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            // Backdrop — cinematic hero with scrim
            GeometryReader { geo in
                Image.wylde(.signInHero)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            LinearGradient(
                colors: [.clear, WyldeStyles.Colors.paper.opacity(0.95), WyldeStyles.Colors.paper],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 80)

                    // Brand mark
                    HStack(spacing: 10) {
                        Image("LogoMark")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text("WYLDE SELF")
                            .font(.system(size: 11.5, weight: .semibold))
                            .tracking(2.6)
                            .foregroundColor(WyldeStyles.Colors.ink)
                    }
                    .padding(.horizontal, 28)

                    Spacer().frame(height: 60)

                    Text("Become the version of you that already followed through.")
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .foregroundColor(WyldeStyles.Colors.ink)
                        .lineSpacing(2)
                        .padding(.horizontal, 28)

                    Text(mode == .magicLink ? "Sign in with your email. We'll send you a one-tap link." : "Sign in with your email and password.")
                        .font(.system(size: 15))
                        .foregroundColor(WyldeStyles.Colors.stone)
                        .padding(.horizontal, 28)
                        .padding(.top, 12)

                    Spacer().frame(height: 28)

                    card
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 28)

                    Text("Considered. Clinical. Calm.")
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .italic()
                        .tracking(0.6)
                        .foregroundColor(WyldeStyles.Colors.stone)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 28)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .wyldeAuthChanged)) { _ in
            // AuthService finished a sign-in via deep-link — UI flips automatically
            // because ContentView reads AppState.isAuthenticated, which observes
            // .wyldeAuthChanged.
        }
    }

    // ─────────────── form / sent card ───────────────
    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            if sent {
                HStack(spacing: 10) {
                    Image(systemName: "envelope.badge.fill")
                        .foregroundColor(WyldeStyles.Colors.sage)
                    Text("Check your email")
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundColor(WyldeStyles.Colors.ink)
                }
                Text("We sent a one-tap sign-in link to **\(email)**. Tap it on this device.")
                    .font(.system(size: 13.5))
                    .foregroundColor(WyldeStyles.Colors.stone)
                    .lineSpacing(2)
                Button("Use a different email") {
                    sent = false
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WyldeStyles.Colors.sage)
                .padding(.top, 4)
            } else {
                // Email field
                Text("Email")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(WyldeStyles.Colors.stone)
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(WyldeStyles.Colors.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(WyldeStyles.Colors.charcoal.opacity(0.10), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .font(.system(size: 15))
                    .foregroundColor(WyldeStyles.Colors.ink)

                // Password field (hidden in magic link mode)
                if mode != .magicLink {
                    Text("Password")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(WyldeStyles.Colors.stone)
                    SecureField("Password", text: $password)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(WyldeStyles.Colors.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(WyldeStyles.Colors.charcoal.opacity(0.10), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .font(.system(size: 15))
                        .foregroundColor(WyldeStyles.Colors.ink)
                }

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 12.5))
                        .foregroundColor(WyldeStyles.Colors.error)
                }

                // Primary action button
                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 8) {
                        if sending {
                            ProgressView().tint(WyldeStyles.Colors.paper).scaleEffect(0.85)
                        }
                        Text(submitLabel)
                            .font(.system(size: 15, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(WyldeStyles.Colors.ink)
                    .foregroundColor(WyldeStyles.Colors.paper)
                    .clipShape(Capsule())
                }
                .disabled(sending || email.isEmpty || (mode != .magicLink && password.isEmpty))
                .opacity((email.isEmpty || (mode != .magicLink && password.isEmpty)) ? 0.5 : 1)
                .padding(.top, 4)

                // Mode switcher
                HStack(spacing: 0) {
                    if mode == .signIn {
                        Button("Create account") { mode = .signUp; errorText = nil }
                        Text(" · ")
                        Button("Use magic link") { mode = .magicLink; errorText = nil }
                    } else if mode == .signUp {
                        Button("Already have an account? Sign in") { mode = .signIn; errorText = nil }
                    } else {
                        Button("Sign in with password") { mode = .signIn; errorText = nil }
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WyldeStyles.Colors.sage)
                .padding(.top, 4)
            }
        }
        .padding(22)
        .background(Theme.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: WyldeStyles.Layout.cardCornerRadius)
                .stroke(WyldeStyles.Colors.charcoal.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WyldeStyles.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
    }

    private var submitLabel: String {
        switch mode {
        case .signIn: return "Sign in"
        case .signUp: return "Create account"
        case .magicLink: return "Send sign-in link"
        }
    }

    @MainActor
    private func submit() async {
        sending = true; errorText = nil
        defer { sending = false }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            switch mode {
            case .signIn:
                try await AuthService.shared.signIn(email: trimmedEmail, password: password)
            case .signUp:
                try await AuthService.shared.signUp(email: trimmedEmail, password: password)
            case .magicLink:
                try await AuthService.shared.sendMagicLink(email: trimmedEmail)
                sent = true
            }
        } catch {
            #if DEBUG
            print("[SignIn] ERROR: \(error)")
            #endif
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    SignInView()
}
