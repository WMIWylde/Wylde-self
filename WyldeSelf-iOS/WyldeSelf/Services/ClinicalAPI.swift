import Foundation

// ════════════════════════════════════════════════════════════════════
//  ClinicalAPI — wrapper for the consumer API's endpoints. Attaches the
//  Supabase access token to every request.
//
//  `host` is the SINGLE source of truth for the consumer API base URL.
//  Every consumer service (WyldeScore, protocol tracker, care messaging,
//  reorder, and the /api/consumer/* endpoints below) routes through it.
//  Override via the Info.plist key CLINICAL_API_BASE (defaults to
//  https://www.wyldeself.com).
// ════════════════════════════════════════════════════════════════════

enum ClinicalAPI {

    /// Single source of truth for the consumer API host string.
    static let host: String = (Bundle.main.object(forInfoDictionaryKey: "CLINICAL_API_BASE") as? String)
        ?? "https://www.wyldeself.com"

    static var baseURL: URL {
        return URL(string: host)!
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
            #if DEBUG
            print("[ClinicalAPI] Token attached: \(token.prefix(20))...")
            #endif
        } else {
            #if DEBUG
            print("[ClinicalAPI] WARNING: No auth token available")
            #endif
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
