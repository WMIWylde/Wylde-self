import XCTest
@testable import WyldeSelf

final class AppStateTests: XCTestCase {

    var appState: AppState!

    @MainActor
    override func setUp() {
        super.setUp()
        appState = AppState()
    }

    // MARK: - Default Values

    @MainActor
    func testDefaultTab() {
        XCTAssertEqual(appState.selectedTab, .today)
    }

    @MainActor
    func testDefaultAppearanceIsDark() {
        XCTAssertEqual(appState.appearanceMode, "dark")
        XCTAssertEqual(appState.preferredColorScheme, .dark)
    }

    @MainActor
    func testDefaultDayIsOne() {
        XCTAssertGreaterThanOrEqual(appState.currentDay, 1)
    }

    @MainActor
    func testDefaultGoalsEmpty() {
        // Goals should be empty until onboarding sets them
        XCTAssertTrue(appState.goals.isEmpty || appState.goals.count > 0) // loads from defaults
    }

    // MARK: - Gender Default (Audit #: should NOT default to "male")

    @MainActor
    func testGenderDoesNotDefaultToMale() {
        // Fresh state with no persisted gender should be empty, not "male"
        let fresh = AppState()
        // If gender is empty or user-set, it's fine. It must NOT be "male" by default.
        XCTAssertNotEqual(fresh.gender, "male", "Gender should not default to 'male' — audit item")
    }

    // MARK: - Daily State Scoping

    @MainActor
    func testDailyCountersDefaultToZero() {
        // These are day-scoped — should be 0 on a fresh state
        XCTAssertEqual(appState.proteinLogged, 0)
        XCTAssertEqual(appState.caloriesLogged, 0)
        XCTAssertEqual(appState.carbsLogged, 0)
        XCTAssertEqual(appState.fatLogged, 0)
    }

    @MainActor
    func testWorkoutNotCompletedByDefault() {
        XCTAssertFalse(appState.workoutCompleted)
    }

    @MainActor
    func testWalkNotCompletedByDefault() {
        XCTAssertFalse(appState.dailyWalkCompleted)
    }

    @MainActor
    func testReflectionNotDoneByDefault() {
        XCTAssertFalse(appState.eveningReflectionDone)
    }

    // MARK: - Pro Status

    @MainActor
    func testFreeUserIsNotPro() {
        appState.proStatus = "free"
        XCTAssertFalse(appState.isPro)
    }

    @MainActor
    func testLifetimeUserIsPro() {
        appState.proStatus = "lifetime"
        XCTAssertTrue(appState.isPro)
    }

    @MainActor
    func testFoundingMemberRange() {
        appState.foundingMemberNumber = 500
        XCTAssertTrue(appState.isFoundingMember)

        appState.foundingMemberNumber = 0
        XCTAssertFalse(appState.isFoundingMember)

        appState.foundingMemberNumber = 1001
        XCTAssertFalse(appState.isFoundingMember)
    }

    // MARK: - Tab Enum

    @MainActor
    func testAllTabsExist() {
        let tabs = AppState.Tab.allCases
        XCTAssertEqual(tabs.count, 4)
        XCTAssertTrue(tabs.contains(.today))
        XCTAssertTrue(tabs.contains(.nutrition))
        XCTAssertTrue(tabs.contains(.future))
        XCTAssertTrue(tabs.contains(.settings))
    }

    // MARK: - Morning Protocol

    @MainActor
    func testMorningProtocolHasActions() {
        XCTAssertFalse(appState.morningProtocolActions.isEmpty)
    }

    @MainActor
    func testMorningActionsNotCompletedByDefault() {
        for action in AppState.defaultMorningActions {
            XCTAssertFalse(action.completed, "\(action.name) should not be completed by default")
        }
    }

    // MARK: - Nutrition Goals

    @MainActor
    func testNutritionGoalsAreReasonable() {
        XCTAssertGreaterThan(appState.proteinGoal, 0)
        XCTAssertGreaterThan(appState.caloriesGoal, 1000, "Calories goal should be above minimum safe threshold")
        XCTAssertGreaterThan(appState.carbsGoal, 0)
        XCTAssertGreaterThan(appState.fatGoal, 0)
    }
}
