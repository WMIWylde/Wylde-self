import Foundation
import SwiftUI
import UIKit

struct FoodAnalysis: Codable {
    let description: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let items: [FoodItem]

    struct FoodItem: Codable {
        let name: String
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
    }
}

@MainActor
final class MacroTrackerService: ObservableObject {
    static let shared = MacroTrackerService()
    private init() { loadTodaysMeals() }

    @Published var todaysMeals: [MealEntry] = []
    @Published var isAnalyzing = false
    @Published var analysisError: String?

    private let mealsKey = "wylde_meals"

    var totalCalories: Int { todaysMeals.filter(\.logged).reduce(0) { $0 + $1.calories } }
    var totalProtein: Int { todaysMeals.filter(\.logged).reduce(0) { $0 + $1.protein } }
    var totalCarbs: Int { todaysMeals.filter(\.logged).reduce(0) { $0 + $1.carbs } }
    var totalFat: Int { todaysMeals.filter(\.logged).reduce(0) { $0 + $1.fat } }

    // MARK: - Analyze Photo

    func analyzePhoto(_ image: UIImage) async -> FoodAnalysis? {
        isAnalyzing = true
        analysisError = nil

        defer { isAnalyzing = false }

        guard let jpegData = image.jpegData(compressionQuality: 0.6) else {
            analysisError = "Could not process image"
            return nil
        }

        let base64 = jpegData.base64EncodedString()

        do {
            let analysis = try await callVisionAPI(base64: base64)
            return analysis
        } catch {
            analysisError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Add Meal

    func addMeal(name: String, analysis: FoodAnalysis, mealType: MealType) {
        let entry = MealEntry(
            name: name.isEmpty ? analysis.description : name,
            mealType: mealType,
            calories: analysis.calories,
            protein: analysis.protein,
            carbs: analysis.carbs,
            fat: analysis.fat,
            items: analysis.items.map { $0.name },
            logged: true
        )
        todaysMeals.append(entry)
        saveMeals()
    }

    func toggleMealLogged(_ id: UUID) {
        if let index = todaysMeals.firstIndex(where: { $0.id == id }) {
            todaysMeals[index].logged.toggle()
            saveMeals()
        }
    }

    func removeMeal(_ id: UUID) {
        todaysMeals.removeAll { $0.id == id }
        saveMeals()
    }

    // MARK: - Vision API

    private func callVisionAPI(base64: String) async throws -> FoodAnalysis {
        guard let url = URL(string: "https://www.wyldeself.com/api/openai") else {
            throw MacroError.invalidURL
        }

        let prompt = """
        Analyze this food photo carefully. Estimate portion sizes from visual cues and calculate macronutrient content precisely.

        Return ONLY valid JSON in this exact format:
        {
          "description": "Brief description of the meal",
          "calories": 650,
          "protein": 42,
          "carbs": 55,
          "fat": 28,
          "items": [
            {"name": "Grilled chicken breast", "calories": 280, "protein": 35, "carbs": 0, "fat": 6},
            {"name": "Brown rice", "calories": 220, "protein": 5, "carbs": 45, "fat": 2}
          ]
        }

        Be accurate. Estimate portions from visual cues. Round to whole numbers.
        """

        let messages: [[String: Any]] = [
            ["role": "system", "content": "You are a nutrition analyst. Analyze food photos and return macro estimates as JSON only. No explanations."],
            ["role": "user", "content": [
                ["type": "text", "text": prompt],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
            ] as [Any]]
        ]

        let payload: [String: Any] = ["messages": messages]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await AuthService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        #if DEBUG
        print("[MacroTracker] Sending photo, payload: \(request.httpBody?.count ?? 0) bytes")
        #endif
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        #if DEBUG
        print("[MacroTracker] Response: \(httpCode), bytes: \(data.count)")
        #endif
        guard httpCode == 200 else {
            #if DEBUG
            if let str = String(data: data, encoding: .utf8) { print("[MacroTracker] Error: \(str.prefix(300))") }
            #endif
            throw MacroError.apiFailed
        }

        // Parse OpenAI response
        struct OpenAIResp: Codable {
            let choices: [Choice]?
            struct Choice: Codable { let message: Msg? }
            struct Msg: Codable { let content: String? }
        }

        let aiResp = try JSONDecoder().decode(OpenAIResp.self, from: data)
        guard let content = aiResp.choices?.first?.message?.content else {
            throw MacroError.parseFailed
        }

        // Extract JSON from response
        guard let jsonStart = content.firstIndex(of: "{"),
              let jsonEnd = content.lastIndex(of: "}") else {
            throw MacroError.parseFailed
        }
        let jsonString = String(content[jsonStart...jsonEnd])
        let jsonData = Data(jsonString.utf8)
        return try JSONDecoder().decode(FoodAnalysis.self, from: jsonData)
    }

    // MARK: - Persistence

    private func dayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return mealsKey + "_" + f.string(from: Date())
    }

    private func saveMeals() {
        if let data = try? JSONEncoder().encode(todaysMeals) {
            UserDefaults.standard.set(data, forKey: dayKey())
        }
    }

    // MARK: - History

    func mealsForDate(_ date: Date) -> [MealEntry] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let key = mealsKey + "_" + f.string(from: date)
        guard let data = UserDefaults.standard.data(forKey: key),
              let meals = try? JSONDecoder().decode([MealEntry].self, from: data) else { return [] }
        return meals
    }

    func datesWithData(last days: Int = 30) -> [Date] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        var dates: [Date] = []
        for i in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let key = mealsKey + "_" + f.string(from: date)
            if UserDefaults.standard.data(forKey: key) != nil {
                dates.append(date)
            }
        }
        return dates
    }

    func summaryForDate(_ date: Date) -> (calories: Int, protein: Int, carbs: Int, fat: Int) {
        let meals = mealsForDate(date).filter(\.logged)
        return (
            meals.reduce(0) { $0 + $1.calories },
            meals.reduce(0) { $0 + $1.protein },
            meals.reduce(0) { $0 + $1.carbs },
            meals.reduce(0) { $0 + $1.fat }
        )
    }

    private func loadTodaysMeals() {
        guard let data = UserDefaults.standard.data(forKey: dayKey()),
              let saved = try? JSONDecoder().decode([MealEntry].self, from: data) else { return }
        todaysMeals = saved
    }

    enum MacroError: LocalizedError {
        case invalidURL, apiFailed, parseFailed
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL"
            case .apiFailed: return "Analysis failed"
            case .parseFailed: return "Could not read nutrition data"
            }
        }
    }
}

// MARK: - Models

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
}

struct MealEntry: Identifiable, Codable {
    let id: UUID
    let name: String
    let mealType: MealType
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let items: [String]
    var logged: Bool
    let timestamp: Date

    init(name: String, mealType: MealType, calories: Int, protein: Int, carbs: Int, fat: Int, items: [String], logged: Bool) {
        self.id = UUID()
        self.name = name
        self.mealType = mealType
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.items = items
        self.logged = logged
        self.timestamp = Date()
    }
}
