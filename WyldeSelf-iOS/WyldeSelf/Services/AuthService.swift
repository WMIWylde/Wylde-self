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
            #if DEBUG
            print("[AuthService] Session restored for user \(session.user.id.uuidString.prefix(8))…")
            #endif
        } catch {
            userID = nil
            email = nil
            cachedToken = nil
            isSignedIn = false
            postAuthChanged(false)
            #if DEBUG
            print("[AuthService] No session to restore — will require sign-in")
            #endif
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
    /// Only transitions to signed-in state when a valid session exists.
    /// If Supabase email confirmation is enabled, signup returns a user
    /// but no session — the user must confirm before they can sign in.
    func signUp(email: String, password: String) async throws {
        let result = try await supabase.auth.signUp(email: email, password: password)
        userID = result.user.id.uuidString
        self.email = result.user.email

        // Only mark signed in if we actually have a session
        if let session = try? await supabase.auth.session {
            cachedToken = session.accessToken
            isSignedIn = true
            postAuthChanged(true)
            #if DEBUG
            print("[AuthService] SignUp completed with active session")
            #endif
        } else {
            // User created but needs email confirmation — don't set signed in
            isSignedIn = false
            postAuthChanged(false)
            #if DEBUG
            print("[AuthService] SignUp completed — email confirmation required")
            #endif
        }
    }

    /// Sign in with email + password.
    func signIn(email: String, password: String) async throws {
        #if DEBUG
        print("[AuthService] Attempting sign-in…")
        #endif
        let session = try await supabase.auth.signIn(email: email, password: password)
        userID = session.user.id.uuidString
        self.email = session.user.email
        cachedToken = session.accessToken
        #if DEBUG
        print("[AuthService] Sign-in succeeded for user \(session.user.id.uuidString.prefix(8))…")
        #endif
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
        cachedToken = nil
        isSignedIn = false
        postAuthChanged(false)
    }

    /// Permanently delete the user's account and all server-side data.
    /// Calls /api/account/delete then clears local state.
    func deleteAccount(appState: AppState) async throws {
        guard let token = await accessToken else {
            throw AccountError.notAuthenticated
        }

        let url = URL(string: "https://www.wyldeself.com/api/account/delete")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard status == 200 else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Failed"
            throw AccountError.serverError(msg)
        }

        // Wipe all local data
        appState.resetAllData()

        // Clear keychain
        SecureStorage.shared.deleteAllUserData()

        // Sign out locally
        await signOut()

        #if DEBUG
        print("[AuthService] Account deleted and local data wiped")
        #endif
    }

    enum AccountError: LocalizedError {
        case notAuthenticated
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "You must be signed in to delete your account."
            case .serverError(let msg): return msg
            }
        }
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
            #if DEBUG
            print("[AuthService] Profile synced to Supabase")
            #endif
        } catch {
            #if DEBUG
            print("[AuthService] Profile sync failed: \(error.localizedDescription)")
            #endif
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
