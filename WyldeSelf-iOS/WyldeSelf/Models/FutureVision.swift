import Foundation

// MARK: - Vision Categories

struct VisionCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
    let prompts: [String]

    static let all: [VisionCategory] = [
        VisionCategory(id: "health_body", name: "Health & Body", icon: "figure.run", prompts: [
            "How do you move?",
            "How do you feel when you wake up?",
            "What does your body look like?"
        ]),
        VisionCategory(id: "relationships", name: "Relationships", icon: "heart.fill", prompts: [
            "Who surrounds you?",
            "What do your closest relationships feel like?"
        ]),
        VisionCategory(id: "family", name: "Family", icon: "house.fill", prompts: [
            "What does your family life look like?",
            "How do you show up for them?"
        ]),
        VisionCategory(id: "wealth", name: "Wealth", icon: "chart.line.uptrend.xyaxis", prompts: [
            "What does financial freedom feel like?",
            "Not the number — the feeling."
        ]),
        VisionCategory(id: "business", name: "Business", icon: "briefcase.fill", prompts: [
            "What are you building?",
            "Who do you serve?",
            "What does a great workday feel like?"
        ]),
        VisionCategory(id: "home", name: "Home", icon: "building.2.fill", prompts: [
            "Where do you live?",
            "What does your space feel like?"
        ]),
        VisionCategory(id: "adventure", name: "Adventure", icon: "mountain.2.fill", prompts: [
            "What experiences are you having?",
            "Where are you going?"
        ]),
        VisionCategory(id: "spirituality", name: "Spirituality", icon: "leaf.fill", prompts: [
            "What grounds you?",
            "What practice sustains you?"
        ]),
        VisionCategory(id: "impact", name: "Impact", icon: "globe.americas.fill", prompts: [
            "What mark are you leaving?",
            "Who benefits from your existence?"
        ]),
        VisionCategory(id: "lifestyle", name: "Lifestyle", icon: "sun.and.horizon.fill", prompts: [
            "What does a Tuesday look like?",
            "What is your daily rhythm?"
        ]),
    ]

    static func find(_ id: String) -> VisionCategory? {
        all.first { $0.id == id }
    }
}

// MARK: - Future Vision (Supabase-backed)

struct FutureVision: Identifiable, Codable, Equatable {
    let id: UUID
    var category: String
    var reflectionResponses: ReflectionData?
    var identityStatement: String?
    var whyItMatters: String?
    var imageBase64: String?
    var timelineHorizon: String?
    var sortOrder: Int
    var isActive: Bool
    let createdAt: Date?
    var updatedAt: Date?

    struct ReflectionData: Codable, Equatable {
        let prompts: [String]
        let answers: [String]
    }

    var categoryInfo: VisionCategory? {
        VisionCategory.find(category)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case reflectionResponses = "reflection_responses"
        case identityStatement = "identity_statement"
        case whyItMatters = "why_it_matters"
        case imageBase64 = "image_url"
        case timelineHorizon = "timeline_horizon"
        case sortOrder = "sort_order"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
