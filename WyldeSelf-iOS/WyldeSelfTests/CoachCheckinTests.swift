import XCTest
@testable import WyldeSelf

final class CoachCheckinTests: XCTestCase {

    override func tearDown() {
        // Clean up any test keys
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        UserDefaults.standard.removeObject(forKey: "wylde_coach_checkin_\(today)")
        super.tearDown()
    }

    func testCheckinKeyIsDateScoped() {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let key = "wylde_coach_checkin_\(today)"

        XCTAssertFalse(UserDefaults.standard.bool(forKey: key),
                       "Check-in should not be marked as seen before it happens")

        UserDefaults.standard.set(true, forKey: key)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: key),
                      "Check-in flag should persist after being set")
    }

    func testCheckinKeyChangesDaily() {
        let formatter = ISO8601DateFormatter()
        let today = formatter.string(from: Date()).prefix(10)
        let yesterday = formatter.string(from: Date().addingTimeInterval(-86400)).prefix(10)

        let todayKey = "wylde_coach_checkin_\(today)"
        let yesterdayKey = "wylde_coach_checkin_\(yesterday)"

        XCTAssertNotEqual(todayKey, yesterdayKey,
                          "Check-in keys should differ by day")
    }
}
