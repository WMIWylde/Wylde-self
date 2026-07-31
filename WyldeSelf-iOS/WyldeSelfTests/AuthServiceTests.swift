import XCTest
@testable import WyldeSelf

final class AuthServiceTests: XCTestCase {

    // MARK: - Initial State

    @MainActor
    func testInitialStateIsSignedOut() {
        let auth = AuthService.shared
        // Without a persisted session, the initial state should not be signed in
        // (This tests the default — restore() hasn't been called)
        XCTAssertFalse(auth.isSignedIn, "AuthService should not start as signed in without a session")
    }

    @MainActor
    func testSignOutClearsState() async {
        let auth = AuthService.shared
        await auth.signOut()
        XCTAssertNil(auth.userID, "userID should be nil after sign out")
        XCTAssertNil(auth.email, "email should be nil after sign out")
        XCTAssertFalse(auth.isSignedIn, "isSignedIn should be false after sign out")
    }

    // MARK: - Account Deletion Error Cases

    @MainActor
    func testDeleteAccountRequiresAuthentication() async {
        let auth = AuthService.shared
        await auth.signOut()
        let appState = AppState()

        do {
            try await auth.deleteAccount(appState: appState)
            XCTFail("deleteAccount should throw when not authenticated")
        } catch let error as AuthService.AccountError {
            switch error {
            case .notAuthenticated:
                break // expected
            default:
                XCTFail("Expected notAuthenticated error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Token Access

    @MainActor
    func testAccessTokenIsNilWhenSignedOut() async {
        let auth = AuthService.shared
        await auth.signOut()
        let token = await auth.accessToken
        XCTAssertNil(token, "Access token should be nil when signed out")
    }
}
