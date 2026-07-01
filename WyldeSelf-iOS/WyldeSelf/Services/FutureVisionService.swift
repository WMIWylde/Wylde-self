import Foundation
import SwiftUI

@MainActor
final class FutureVisionService: ObservableObject {
    static let shared = FutureVisionService()
    private init() { loadCache() }

    @Published var visions: [FutureVision] = []
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var generationProgress: String = ""

    private let cacheKey = "wylde_future_visions"

    // MARK: - Generate vision for a category

    func generateVision(
        category: VisionCategory,
        answers: [String],
        gender: String
    ) async throws -> FutureVision {
        let reflectionText = zip(category.prompts, answers)
            .map { "\($0): \($1)" }
            .joined(separator: "\n")

        // Call the image generation API
        let imageBase64 = try await generateImage(
            category: category.id,
            reflectionText: reflectionText,
            gender: gender
        )

        // Generate identity statement + why it matters from the reflection
        let statement = synthesizeStatement(answers: answers, category: category)
        let why = synthesizeWhy(answers: answers, category: category)

        let vision = FutureVision(
            id: UUID(),
            category: category.id,
            reflectionResponses: FutureVision.ReflectionData(
                prompts: category.prompts,
                answers: answers
            ),
            identityStatement: statement,
            whyItMatters: why,
            imageBase64: imageBase64,
            timelineHorizon: nil,
            sortOrder: visions.count,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        visions.append(vision)
        saveCache()
        return vision
    }

    // MARK: - Image Generation

    private func generateImage(
        category: String,
        reflectionText: String,
        gender: String
    ) async throws -> String? {
        guard let url = URL(string: "https://www.wyldeself.com/api/generate-image") else {
            throw VisionError.invalidURL
        }

        let payload: [String: Any] = [
            "mode": "future_vision",
            "category": category,
            "reflectionText": reflectionText,
            "gender": gender,
            "timeline": "1year",
            "goals": [category],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await AuthService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 90
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        #if DEBUG
        print("[FutureVision] Generating image for \(category)...")
        #endif
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        #if DEBUG
        print("[FutureVision] Response: \(httpCode), bytes: \(data.count)")
        #endif

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VisionError.generationFailed
        }

        let result = try JSONDecoder().decode(ImageGenResponse.self, from: data)
        return result.success ? result.imageBase64 : nil
    }

    // MARK: - Statement Synthesis

    private func synthesizeStatement(answers: [String], category: VisionCategory) -> String {
        let combined = answers.filter { !$0.isEmpty }.joined(separator: " ")
        if combined.isEmpty {
            return defaultStatements[category.id] ?? "I am becoming who I was meant to be."
        }
        // Use first meaningful answer as the identity statement
        if let first = answers.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
            // Ensure it reads as a statement
            if trimmed.lowercased().hasPrefix("i ") {
                return trimmed
            }
            return "I \(trimmed.prefix(1).lowercased())\(trimmed.dropFirst())"
        }
        return defaultStatements[category.id] ?? "I am becoming who I was meant to be."
    }

    private func synthesizeWhy(answers: [String], category: VisionCategory) -> String {
        return defaultWhys[category.id] ?? "This future is achievable because I am becoming the person capable of creating it."
    }

    private let defaultStatements: [String: String] = [
        "health_body": "I move through life strong, capable, and energized.",
        "relationships": "I am surrounded by people who see me and I see them.",
        "family": "I show up fully for the people who matter most.",
        "wealth": "I live with financial ease and intentional abundance.",
        "business": "I build something meaningful that transforms lives.",
        "home": "I live in a space that reflects who I've become.",
        "adventure": "I seek experiences that expand who I am.",
        "spirituality": "I am grounded in something deeper than ambition.",
        "impact": "My existence makes others' lives measurably better.",
        "lifestyle": "Every day feels intentional, not accidental.",
    ]

    private let defaultWhys: [String: String] = [
        "health_body": "My body supports my purpose.",
        "relationships": "Connection is the foundation of a meaningful life.",
        "family": "They deserve the best version of me.",
        "wealth": "Freedom is the ability to choose how I spend my time.",
        "business": "Meaningful work compounds into lasting impact.",
        "home": "Your environment shapes who you become.",
        "adventure": "Growth happens at the edge of comfort.",
        "spirituality": "Stillness is where clarity lives.",
        "impact": "Legacy is built in daily decisions.",
        "lifestyle": "How you spend your days is how you spend your life.",
    ]

    // MARK: - Persistence (local cache)

    private func saveCache() {
        if let data = try? JSONEncoder().encode(visions) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([FutureVision].self, from: data) else { return }
        visions = cached
    }

    func deleteVision(_ id: UUID) {
        visions.removeAll { $0.id == id }
        saveCache()
    }

    // MARK: - Types

    enum VisionError: LocalizedError {
        case invalidURL
        case generationFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL"
            case .generationFailed: return "Image generation failed. Please try again."
            }
        }
    }

    private struct ImageGenResponse: Codable {
        let success: Bool
        let imageBase64: String?
        let mode: String?

        enum CodingKeys: String, CodingKey {
            case success
            case imageBase64 = "image_base64"
            case mode
        }
    }
}
