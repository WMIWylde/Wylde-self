import Foundation
import SwiftUI
import Supabase

// ════════════════════════════════════════════════════════════════════
//  AuthService — wraps Supabase Auth for the iOS app.
//
//  Replaces the old "isAuthenticated = (name not empty)" pattern in
//  AppState. Use this from sign-in flows; AppState.isAuthenticated is
//  kept in sync via NotificationCenter so existing views don't break.
//
//  Magic-link sign-in:
//      Task { try await AuthService.shared.sendMagicLink(email: ...) }
//  Restore on launch (call from WyldeSelfApp.onAppear):
//      Task { await AuthService.shared.restore() }
// ════════════════════════════════════════════════════════════════════

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()
    private init() {}

    @Published private(set) var userID: String?
    @Published private(set) var email: String?
    @Published private(set) var isSignedIn: Bool = false

    private let supabase = SupabaseService.shared
    private var cachedToken: String?

    /// Restore session on launch; call from app entry.
    func restore() async {
        do {
            let session = try await supabase.auth.session
            userID = session.user.id.uuidString
            email = session.user.email
            cachedToken = session.accessToken
            isSignedIn = true
            postAuthChanged(true)
            print("[AuthService] Session restored, token: \(session.accessToken.prefix(20))...")
        } catch {
            userID = nil
            email = nil
            cachedToken = nil
            isSignedIn = false
            postAuthChanged(false)
            print("[AuthService] No session to restore — will require sign-in")
        }
    }

    /// Whether there's a valid Supabase session (not just a cached flag).
    var hasValidSession: Bool {
        get async {
            return (try? await supabase.auth.session) != nil
        }
    }

    /// Send a magic link to the email. The user taps it on this device,
    /// which opens the app via the URL scheme and finalizes the session.
    func sendMagicLink(email: String) async throws {
        try await supabase.auth.signInWithOTP(
            email: email,
            redirectTo: URL(string: "wyldeself://auth/callback"),
            shouldCreateUser: true
        )
    }

    /// Sign up with email + password.
    func signUp(email: String, password: String) async throws {
        let result = try await supabase.auth.signUp(email: email, password: password)
        userID = result.user.id.uuidString
        self.email = result.user.email
        // Try to get session token after sign up
        if let session = try? await supabase.auth.session {
            cachedToken = session.accessToken
            print("[AuthService] SignUp token: \(session.accessToken.prefix(20))...")
        }
        isSignedIn = true
        postAuthChanged(true)
    }

    /// Sign in with email + password.
    func signIn(email: String, password: String) async throws {
        print("[AuthService] Attempting sign-in for \(email)...")
        let session = try await supabase.auth.signIn(email: email, password: password)
        print("[AuthService] Sign-in succeeded!")
        userID = session.user.id.uuidString
        self.email = session.user.email
        cachedToken = session.accessToken
        print("[AuthService] Token cached: \(session.accessToken.prefix(30))...")
        isSignedIn = true
        postAuthChanged(true)
    }

    /// Handle the deep link callback from the magic-link email.
    /// Call this from WyldeSelfApp's .onOpenURL or AppDelegate.
    func handleCallback(_ url: URL) async {
        do {
            try await supabase.auth.session(from: url)
            await restore()
        } catch {
            isSignedIn = false
            postAuthChanged(false)
        }
    }

    /// Sign out and reset auth state.
    func signOut() async {
        try? await supabase.auth.signOut()
        userID = nil
        email = nil
        isSignedIn = false
        postAuthChanged(false)
    }

    /// Current Supabase access token — used by ClinicalAPI to attach as Bearer.
    var accessToken: String? {
        get async {
            // Try fresh session first, fall back to cached
            if let session = try? await supabase.auth.session {
                cachedToken = session.accessToken
                return session.accessToken
            }
            return cachedToken
        }
    }

    // MARK: - Profile Sync

    /// Syncs local AppState profile data to Supabase profiles table.
    /// Called after sign-in and after onboarding completion.
    func syncProfile(appState: AppState) async {
        guard let uid = userID else { return }

        struct ProfileRow: Encodable {
            let id: String
            let email: String
            let profile_data: ProfileData
        }
        struct ProfileData: Encodable {
            let name: String
            let gender: String
            let goals: String
            let fitness_level: String
            let training_days: String
            let age_range: String
        }

        let row = ProfileRow(
            id: uid,
            email: email ?? "",
            profile_data: ProfileData(
                name: appState.userName,
                gender: appState.gender,
                goals: appState.goals.joined(separator: ","),
                fitness_level: appState.fitnessLevel,
                training_days: appState.trainingDays,
                age_range: appState.ageRange
            )
        )

        do {
            try await supabase
                .from("profiles")
                .upsert(row)
                .execute()
            print("[AuthService] Profile synced to Supabase")
        } catch {
            print("[AuthService] Profile sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Sync to AppState

    /// Posts a notification so AppState (or any other observer) can react
    /// without coupling AuthService to AppState directly.
    private func postAuthChanged(_ signedIn: Bool) {
        NotificationCenter.default.post(
            name: .wyldeAuthChanged,
            object: nil,
            userInfo: ["isSignedIn": signedIn, "userID": userID ?? "", "email": email ?? ""]
        )
    }
}

extension Notification.Name {
    /// Posted by AuthService when the user's auth state changes.
    /// userInfo: ["isSignedIn": Bool, "userID": String, "email": String]
    static let wyldeAuthChanged = Notification.Name("WyldeAuthChanged")
}
