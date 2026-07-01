import Foundation

// ════════════════════════════════════════════════════════════════════
//  FileStorage — stores large data (base64 images, vision caches)
//  as files in Application Support/WyldeSelf/ instead of UserDefaults
//  or Keychain. Keychain has size limits (~16 KB recommended) so
//  base64-encoded images must live on disk.
//
//  Files are stored in the app sandbox — already encrypted at rest
//  when the device has a passcode (iOS Data Protection).
// ════════════════════════════════════════════════════════════════════

final class FileStorage {
    static let shared = FileStorage()

    private let directoryName = "WyldeSelf"
    private let fileManager = FileManager.default

    private var baseURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent(directoryName)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {}

    // MARK: - Write

    func write(_ data: Data, forKey key: String) {
        guard let url = fileURL(for: key) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    func writeString(_ string: String, forKey key: String) {
        guard let data = string.data(using: .utf8) else { return }
        write(data, forKey: key)
    }

    // MARK: - Read

    func read(forKey key: String) -> Data? {
        guard let url = fileURL(for: key), fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    func readString(forKey key: String) -> String? {
        guard let data = read(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    func delete(forKey key: String) {
        guard let url = fileURL(for: key) else { return }
        try? fileManager.removeItem(at: url)
    }

    /// Remove all files in the WyldeSelf storage directory.
    func clearAll() {
        guard let dir = baseURL else { return }
        guard let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in contents {
            try? fileManager.removeItem(at: file)
        }
    }

    // MARK: - Helpers

    private func fileURL(for key: String) -> URL? {
        // Sanitize key to a safe filename
        let safe = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return baseURL?.appendingPathComponent(safe)
    }
}
