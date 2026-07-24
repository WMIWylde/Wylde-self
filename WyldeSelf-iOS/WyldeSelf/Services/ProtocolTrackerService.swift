import Foundation

@MainActor
final class ProtocolTrackerService: ObservableObject {
    static let shared = ProtocolTrackerService()
    private init() {}

    @Published var protocols: [MeResponse.ActiveProtocol] = []
    @Published var prescriptions: [MeResponse.Prescription] = []
    @Published var adherenceLogs: [ProtocolAdherenceLog] = []
    @Published var adherenceRate: Int?
    @Published var isLoading = false

    private let baseURL = ClinicalAPI.host

    // MARK: - Fetch protocols + prescriptions + adherence

    func fetch() async {
        guard let token = await AuthService.shared.accessToken,
              let url = URL(string: "\(baseURL)/api/consumer/protocols") else { return }

        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let resp = try JSONDecoder().decode(ProtocolsResponse.self, from: data)
            protocols = resp.protocols ?? []
            prescriptions = resp.prescriptions ?? []
            adherenceLogs = resp.adherenceLogs ?? []
            adherenceRate = resp.adherenceRate
        } catch {
            #if DEBUG
            print("[ProtocolTracker] Fetch failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Log a dose

    func logDose(prescriptionId: String, protocolId: String?, status: String, dose: String? = nil, notes: String? = nil, sideEffects: [String: String]? = nil) async {
        if status == "taken" {
            struct LedgerRow: Encodable { let delta: Int; let reason: String; let source: String }
            try? await SupabaseService.shared.from("points_ledger")
                .insert(LedgerRow(delta: 10, reason: "Dose logged", source: "ios")).execute()
        }
        guard let token = await AuthService.shared.accessToken,
              let url = URL(string: "\(baseURL)/api/consumer/protocols") else { return }

        var payload: [String: Any] = [
            "prescription_id": prescriptionId,
            "status": status,
        ]
        if let pid = protocolId { payload["protocol_id"] = pid }
        if let d = dose { payload["dose"] = d }
        if let n = notes { payload["notes"] = n }
        if let se = sideEffects { payload["side_effects"] = se }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 201 {
                await fetch() // Refresh data
            }
        } catch {
            #if DEBUG
            print("[ProtocolTracker] Log dose failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Types

    private struct ProtocolsResponse: Codable {
        let protocols: [MeResponse.ActiveProtocol]?
        let prescriptions: [MeResponse.Prescription]?
        let adherenceLogs: [ProtocolAdherenceLog]?
        let adherenceRate: Int?

        enum CodingKeys: String, CodingKey {
            case protocols, prescriptions
            case adherenceLogs = "adherence_logs"
            case adherenceRate = "adherence_rate"
        }
    }
}
