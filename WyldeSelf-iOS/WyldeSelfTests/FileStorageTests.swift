import XCTest
@testable import WyldeSelf

final class FileStorageTests: XCTestCase {

    let storage = FileStorage.shared
    let testFile = "test_file_\(UUID().uuidString)"

    override func tearDown() {
        storage.delete(forKey: testFile)
        super.tearDown()
    }

    func testWriteAndRead() {
        let data = "Test data for Wylde Self".data(using: .utf8)!
        storage.write(data, forKey: testFile)
        let result = storage.read(forKey: testFile)
        XCTAssertEqual(result, data)
    }

    func testReadReturnsNilForMissingFile() {
        XCTAssertNil(storage.read(forKey: "nonexistent_\(UUID().uuidString)"))
    }

    func testDelete() {
        let data = "delete me".data(using: .utf8)!
        storage.write(data, forKey: testFile)
        storage.delete(forKey: testFile)
        XCTAssertNil(storage.read(forKey: testFile))
    }

    func testOverwrite() {
        storage.write("first".data(using: .utf8)!, forKey: testFile)
        storage.write("second".data(using: .utf8)!, forKey: testFile)
        let result = storage.read(forKey: testFile)
        XCTAssertEqual(String(data: result!, encoding: .utf8), "second")
    }
}
