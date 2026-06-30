import Foundation

// ════════════════════════════════════════════════════════════════════
//  Models matching the clinical app's /api/consumer/* endpoints.
//  These mirror the shape of the response bodies in the clinical Next.js
//  app — see wyldeself-clinical/app/api/consumer/*/route.ts.
// ════════════════════════════════════════════════════════════════════

// MARK: - /api/consumer/me
struct MeResponse: Codable {
    let patient: Patient?
    let `protocol`: ActiveProtocol?
    let prescriptions: [Prescription]
    let today: TodayState

    struct Patient: Codable {
        let id: String
        let first_name: String
        let last_name: String
        let status: String
    }
    struct ActiveProtocol: Codable {
        let id: String
        let name: String
        let phase: String?
        let started_at: String
        let day_number: Int?
    }
    struct Prescription: Codable, Identifiable {
        let drug: String
        let dose: String
        let frequency: String
        let status: String
        let last_filled_at: String?
        var id: String { "\(drug)-\(dose)" }
    }
    struct TodayState: Codable {
        let adherence_required: [String]
        let already_logged_today: Bool
    }
}

// MARK: - /api/consumer/progress
struct ProgressResponse: Codable {
    let patient: Patient?
    let `protocol`: ActiveProtocol?
    let timeseries: [Datapoint]
    let snapshots: [Snapshot]
    let comparison: Comparison

    struct Patient: Codable {
        let first_name: String
        let last_name: String
        let status: String
    }
    struct ActiveProtocol: Codable {
        let name: String
        let phase: String?
        let started_at: String
        let day_number: Int?
    }
    struct Datapoint: Codable, Identifiable {
        let date: String
        let doses: Int
        let sleep_score: Int?
        let hrv: Int?
        let rhr: Int?
        var id: String { date }
    }
    struct Snapshot: Codable, Identifiable {
        let milestone: String
        let snapshot_date: String
        let metrics: [String: Double]
        var id: String { milestone }
    }
    struct Comparison: Codable {
        let adherence: Pair?
        let hrv: Pair?
        let sleep_score: Pair?
        let rhr: Pair?
    }
    struct Pair: Codable {
        let baseline: Double
        let current: Double
        let unit: String
    }
}

// MARK: - /api/consumer/checkin
struct CheckinPayload: Codable {
    var date: String?
    let doses: Int
    let daily_checkin: Int
    let workout: Int
    let nutrition: Int
    var weight: Double?
    var sleep_score: Int?
    var hrv: Int?
    var rhr: Int?
    var mood: Int?
    var notes: String?
}

struct CheckinResponse: Codable {
    let ok: Bool
    let checkin: SavedCheckin
    struct SavedCheckin: Codable {
        let id: String
        let date: String
    }
}

// MARK: - /api/consumer/care/*
struct CareInviteResponse: Codable {
    let code: String
    let expires_at: String
    let share_text: String
}

struct CareAcceptResponse: Codable {
    let patient_id: String
    let linked: Bool
}

struct CareRelationshipsResponse: Codable {
    let active_relationship: ActiveRelationship?
    let pending_invites: [PendingInvite]

    struct ActiveRelationship: Codable {
        let patient_id: String
        let linked_at: String
        let clinic: Clinic?
        struct Clinic: Codable { let name: String }
    }
    struct PendingInvite: Codable, Identifiable {
        let code: String
        let status: String
        let message: String?
        let access_level: String
        let expires_at: String
        let created_at: String
        var id: String { code }
    }
}

// MARK: - shared error
struct APIError: Codable, Error, LocalizedError {
    let error: String
    var errorDescription: String? { error }
}
