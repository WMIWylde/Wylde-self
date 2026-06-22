import Foundation

// ════════════════════════════════════════════════════════════════════
//  ClinicalAPI — wrapper for the clinical Next.js app's consumer
//  endpoints. Attaches the Supabase access token to every request.
//
//  Configure CLINICAL_API_BASE in Info.plist (defaults to
//  https://clinical.wyldeself.com).
// ════════════════════════════════════════════════════════════════════

enum ClinicalAPI {

    static var baseURL: URL {
        let s = (Bundle.main.object(forInfoDictionaryKey: "CLINICAL_API_BASE") as? String)
              ?? "https://clinical.wyldeself.com"
        return URL(string: s)!
    }

    // MARK: ─── Patient profile + today's plan ───
    static func me() async throws -> MeResponse {
        try await request("/api/consumer/me", method: "GET", body: Optional<EmptyBody>.none)
    }

    // MARK: ─── Progress / trajectory ───
    static func progress() async throws -> ProgressResponse {
        try await request("/api/consumer/progress", method: "GET", body: Optional<EmptyBody>.none)
    }

    // MARK: ─── Submit daily check-in ───
    @discardableResult
    static func submitCheckin(_ payload: CheckinPayload) async throws -> CheckinResponse {
        try await request("/api/consumer/checkin", method: "POST", body: payload)
    }

    // MARK: ─── Care relationship management ───
    static func generateCareInvite(message: String? = nil) async throws -> CareInviteResponse {
        struct Body: Codable { let message: String? }
        return try await request("/api/consumer/care/invite", method: "POST", body: Body(message: message))
    }

    static func acceptClinicCode(_ code: String) async throws -> CareAcceptResponse {
        struct Body: Codable { let code: String }
        return try await request("/api/consumer/care/accept", method: "POST", body: Body(code: code))
    }

    static func careRelationships() async throws -> CareRelationshipsResponse {
        try await request("/api/consumer/care/relationships", method: "GET", body: Optional<EmptyBody>.none)
    }

    static func revokeAccess() async throws {
        let _: EmptyResponse = try await request("/api/consumer/care/relationships", method: "DELETE", body: Optional<EmptyBody>.none)
    }

    // MARK: ─── Internal ───
    private static func request<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        body: Body?
    ) async throws -> Response {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Attach the user's Supabase JWT (silent if signed out — server rejects).
        if let token = await AuthService.shared.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("[ClinicalAPI] Token attached: \(token.prefix(20))...")
        } else {
            print("[ClinicalAPI] WARNING: No auth token available")
        }

        if let body, !(body is EmptyBody) {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(error: "Bad response")
        }
        guard (200..<300).contains(http.statusCode) else {
            if let err = try? JSONDecoder().decode(APIError.self, from: data) { throw err }
            throw APIError(error: "Request failed (HTTP \(http.statusCode))")
        }
        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

struct EmptyBody: Encodable {}
struct EmptyResponse: Decodable {}
