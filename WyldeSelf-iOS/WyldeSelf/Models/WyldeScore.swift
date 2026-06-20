import Foundation

struct WyldeScore: Codable, Identifiable {
    let id: UUID?
    let date: String
    let totalScore: Int
    let ritualScore: Int
    let movementScore: Int
    let nutritionScore: Int
    let protocolScore: Int
    let recoveryScore: Int
    let mindsetScore: Int

    enum CodingKeys: String, CodingKey {
        case id, date
        case totalScore = "total_score"
        case ritualScore = "ritual_score"
        case movementScore = "movement_score"
        case nutritionScore = "nutrition_score"
        case protocolScore = "protocol_score"
        case recoveryScore = "recovery_score"
        case mindsetScore = "mindset_score"
    }

    var grade: String {
        switch totalScore {
        case 90...100: return "Elite"
        case 75..<90: return "Strong"
        case 55..<75: return "Building"
        case 35..<55: return "Emerging"
        default: return "Start"
        }
    }
}

struct ProtocolAdherenceLog: Codable, Identifiable {
    let id: UUID
    let prescriptionId: UUID?
    let protocolId: UUID?
    let status: String  // taken, skipped, missed
    let dose: String?
    let notes: String?
    let sideEffects: [String: String]?
    let takenAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case prescriptionId = "prescription_id"
        case protocolId = "protocol_id"
        case status, dose, notes
        case sideEffects = "side_effects"
        case takenAt = "taken_at"
        case createdAt = "created_at"
    }
}

struct CareMessage: Codable, Identifiable {
    let id: UUID
    let relationshipId: UUID
    let senderId: UUID
    let recipientId: UUID
    let body: String
    let messageType: String?
    let readAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case relationshipId = "relationship_id"
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case body
        case messageType = "message_type"
        case readAt = "read_at"
        case createdAt = "created_at"
    }

    var isFromPatient: Bool {
        // Will be determined by comparing against current user ID
        true
    }
}
