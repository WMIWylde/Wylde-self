import Foundation
import Security

// ════════════════════════════════════════════════════════════════════
//  SecureStorage — iOS Keychain wrapper for sensitive wellness data.
//  Stores strings (weight, height, health concerns, diet notes, etc.)
//  in the Keychain instead of UserDefaults so they are encrypted at
//  rest and protected by the Secure Enclave.
//
//  API is intentionally simple: set / get / remove / removeAll.
//  Errors are swallowed — a failed Keychain write should never crash
//  the app; the worst case is data is not persisted across launches.
// ════════════════════════════════════════════════════════════════════

final class SecureStorage {
    static let shared = SecureStorage()

    private let service = "com.wyldeself.app"

    private init() {}

    // MARK: - Public API

    func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Try to update first; if the item doesn't exist, add it.
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  key,
        ]

        let update: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  key,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    func remove(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    func removeAll() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  service,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Codable Helpers

    func setCodable<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else { return }
        set(string, forKey: key)
    }

    func getCodable<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let string = get(forKey: key),
              let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: - Full Data Deletion (GDPR / "Delete My Data")

    /// Wipes all sensitive data from Keychain AND file storage.
    /// Call this for "delete my data" compliance.
    func deleteAllUserData() {
        removeAll()
        FileStorage.shared.clearAll()
    }
}
