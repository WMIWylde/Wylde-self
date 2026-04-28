import Foundation

// ════════════════════════════════════════════════════════════════════
//  IdentityAnalysisService — calls /api/identity-analyze with the
//  user's pasted URLs + raw text, returns the structured IdentityProfile.
//  All persistence happens server-side (Supabase upsert via the endpoint).
// ════════════════════════════════════════════════════════════════════

@MainActor
final class IdentityAnalysisService: ObservableObject {
    static let shared = IdentityAnalysisService()
    private init() {}

    @Published var isAnalyzing: Bool = false
    @Published var lastError: String? = nil

    private let endpoint = URL(string: "https://wyldeself.com/api/identity-analyze")!

    /// Submit the import. Returns the parsed profile on success, throws on failure.
    func analyze(userId: String, urls: [String], rawText: String) async throws -> IdentityProfile {
        isAnalyzing = true
        defer { isAnalyzing = false }
        lastError = nil

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "user_id": userId,
            "urls": urls,
            "raw_text": rawText
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data)["error"]) ?? "HTTP error"
            self.lastError = msg
            throw NSError(domain: "IdentityAnalysisService", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        // Response is { ok: true, profile: { ... } }
        struct Wrapper: Decodable {
            let ok: Bool
            let profile: IdentityProfile
        }
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: data)
        return wrapper.profile
    }
}
