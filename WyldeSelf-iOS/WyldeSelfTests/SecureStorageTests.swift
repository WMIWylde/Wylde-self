import XCTest
@testable import WyldeSelf

final class SecureStorageTests: XCTestCase {

    let storage = SecureStorage.shared
    let testKey = "test_secure_key_\(UUID().uuidString)"

    override func tearDown() {
        storage.remove(forKey: testKey)
        super.tearDown()
    }

    // MARK: - Basic Operations

    func testSetAndGet() {
        storage.set("hello_world", forKey: testKey)
        XCTAssertEqual(storage.get(forKey: testKey), "hello_world")
    }

    func testGetReturnsNilForMissingKey() {
        XCTAssertNil(storage.get(forKey: "nonexistent_key_\(UUID().uuidString)"))
    }

    func testRemove() {
        storage.set("to_delete", forKey: testKey)
        storage.remove(forKey: testKey)
        XCTAssertNil(storage.get(forKey: testKey))
    }

    func testOverwrite() {
        storage.set("first", forKey: testKey)
        storage.set("second", forKey: testKey)
        XCTAssertEqual(storage.get(forKey: testKey), "second")
    }

    // MARK: - Codable

    func testCodableRoundTrip() {
        let values = ["one", "two", "three"]
        storage.setCodable(values, forKey: testKey)
        let result = storage.getCodable([String].self, forKey: testKey)
        XCTAssertEqual(result, values)
    }

    // MARK: - Empty/Edge Cases

    func testEmptyString() {
        storage.set("", forKey: testKey)
        XCTAssertEqual(storage.get(forKey: testKey), "")
    }

    func testUnicodeString() {
        let unicode = "Hello 🌍 Wylde Self — transformation"
        storage.set(unicode, forKey: testKey)
        XCTAssertEqual(storage.get(forKey: testKey), unicode)
    }
}
