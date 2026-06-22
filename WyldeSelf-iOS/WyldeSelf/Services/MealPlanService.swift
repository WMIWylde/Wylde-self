import Foundation

@MainActor
final class MealPlanService: ObservableObject {
    static let shared = MealPlanService()
    private init() { loadPlan() }

    @Published var plan: WeeklyMealPlan?
    @Published var isGenerating = false

    private let planKey = "wylde_meal_plan"

    // MARK: - Today's Meals

    func todaysMeals() -> DayMealPlan? {
        guard let plan = plan else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let today = formatter.string(from: Date()).lowercased()
        return plan.days.first { $0.id == today }
    }

    // MARK: - Toggle Meal

    func toggleMeal(dayId: String, mealId: UUID) {
        guard var plan = plan,
              let dayIndex = plan.days.firstIndex(where: { $0.id == dayId }),
              let mealIndex = plan.days[dayIndex].meals.firstIndex(where: { $0.id == mealId }) else { return }
        plan.days[dayIndex].meals[mealIndex].completed.toggle()
        self.plan = plan
        savePlan()
    }

    // MARK: - Toggle Grocery Item

    func toggleGrocery(sectionId: UUID, itemId: UUID) {
        guard var plan = plan,
              let secIndex = plan.groceryList.firstIndex(where: { $0.id == sectionId }),
              let itemIndex = plan.groceryList[secIndex].items.firstIndex(where: { $0.id == itemId }) else { return }
        plan.groceryList[secIndex].items[itemIndex].checked.toggle()
        self.plan = plan
        savePlan()
    }

    // MARK: - Generate Plan

    func generatePlan(appState: AppState) async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            let plan = try await callAI(appState: appState)
            self.plan = plan
            savePlan()
        } catch {
            print("[MealPlanService] AI failed: \(error), using template")
            self.plan = fallbackPlan(appState: appState)
            savePlan()
        }
    }

    private func callAI(appState: AppState) async throws -> WeeklyMealPlan {
        guard let url = URL(string: "https://wyldeself.com/api/openai") else {
            throw MealPlanError.invalidURL
        }

        let prompt = buildPrompt(appState: appState)
        let payload: [String: Any] = [
            "messages": [
                ["role": "system", "content": "You are a precision nutrition coach. Return ONLY valid JSON. No explanations."],
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MealPlanError.apiFailed
        }

        struct Resp: Codable { let choices: [C]?; struct C: Codable { let message: M? }; struct M: Codable { let content: String? } }
        let aiResp = try JSONDecoder().decode(Resp.self, from: data)
        guard let content = aiResp.choices?.first?.message?.content,
              let jsonStart = content.firstIndex(of: "{"),
              let jsonEnd = content.lastIndex(of: "}") else {
            throw MealPlanError.parseFailed
        }

        let jsonData = Data(String(content[jsonStart...jsonEnd]).utf8)
        return try JSONDecoder().decode(WeeklyMealPlan.self, from: jsonData)
    }

    private func buildPrompt(appState: AppState) -> String {
        let diet = appState.dietaryPrefs.isEmpty ? "No restrictions" : appState.dietaryPrefs.joined(separator: ", ")
        let goals = appState.goals.isEmpty ? "Get lean & athletic" : appState.goals.joined(separator: ", ")
        let proteinGoal = appState.proteinGoal
        let calorieGoal = appState.caloriesGoal

        return """
        Create a 7-day meal plan for someone with these goals: \(goals).
        Dietary preferences: \(diet).
        \(appState.dietNotes.isEmpty ? "" : "Notes: \(appState.dietNotes)")
        Daily targets: ~\(calorieGoal) calories, ~\(proteinGoal)g protein.

        Return JSON in this EXACT format:
        {
          "days": [
            {
              "id": "monday",
              "dayName": "Monday",
              "meals": [
                {
                  "mealType": "Breakfast",
                  "name": "Scrambled Eggs with Avocado Toast",
                  "description": "Quick, high-protein start",
                  "ingredients": ["3 eggs", "1 avocado", "2 slices sourdough", "salt", "pepper"],
                  "instructions": ["Scramble eggs in butter", "Toast bread", "Slice avocado on top", "Season"],
                  "prepTime": 10,
                  "calories": 520,
                  "protein": 28,
                  "carbs": 35,
                  "fat": 32
                }
              ]
            }
          ],
          "groceryList": [
            {
              "category": "Protein",
              "items": [{"name": "Chicken breast", "quantity": "3 lbs"}]
            }
          ],
          "generatedAt": "\(ISO8601DateFormatter().string(from: Date()))",
          "goal": "\(goals)"
        }

        Include 3 meals (Breakfast, Lunch, Dinner) and 1 Snack per day.
        Keep meals practical — 10-20 min prep. Real food, not supplements.
        Grocery list grouped by: Protein, Produce, Dairy, Pantry, Grains.
        """
    }

    // MARK: - Fallback

    private func fallbackPlan(appState: AppState) -> WeeklyMealPlan {
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let days = dayNames.map { day -> DayMealPlan in
            DayMealPlan(id: day.lowercased(), dayName: day, meals: [
                PlannedMeal(mealType: .breakfast, name: "Scrambled Eggs & Toast", ingredients: ["3 eggs", "2 toast", "butter"], instructions: ["Scramble eggs", "Toast bread", "Serve"], prepTime: 8, calories: 450, protein: 28, carbs: 30, fat: 24),
                PlannedMeal(mealType: .lunch, name: "Grilled Chicken Salad", ingredients: ["6oz chicken breast", "mixed greens", "cherry tomatoes", "olive oil", "lemon"], instructions: ["Grill chicken 6 min each side", "Toss salad", "Slice chicken on top", "Dress with oil + lemon"], prepTime: 15, calories: 480, protein: 42, carbs: 12, fat: 28),
                PlannedMeal(mealType: .dinner, name: "Salmon with Rice & Vegetables", ingredients: ["6oz salmon fillet", "1 cup rice", "broccoli", "soy sauce", "garlic"], instructions: ["Cook rice", "Pan-sear salmon 4 min each side", "Steam broccoli", "Serve with soy + garlic drizzle"], prepTime: 20, calories: 580, protein: 40, carbs: 52, fat: 22),
                PlannedMeal(mealType: .snack, name: "Greek Yogurt & Berries", ingredients: ["1 cup Greek yogurt", "mixed berries", "honey"], instructions: ["Combine and eat"], prepTime: 2, calories: 220, protein: 18, carbs: 28, fat: 6),
            ])
        }

        let groceryList = [
            GrocerySection(category: "Protein", items: [
                GroceryItem(name: "Eggs", quantity: "2 dozen"),
                GroceryItem(name: "Chicken breast", quantity: "3 lbs"),
                GroceryItem(name: "Salmon fillets", quantity: "3 lbs"),
                GroceryItem(name: "Greek yogurt", quantity: "32 oz"),
            ]),
            GrocerySection(category: "Produce", items: [
                GroceryItem(name: "Mixed greens", quantity: "2 bags"),
                GroceryItem(name: "Broccoli", quantity: "2 heads"),
                GroceryItem(name: "Cherry tomatoes", quantity: "1 pint"),
                GroceryItem(name: "Mixed berries", quantity: "2 pints"),
                GroceryItem(name: "Lemons", quantity: "3"),
                GroceryItem(name: "Garlic", quantity: "1 head"),
            ]),
            GrocerySection(category: "Pantry", items: [
                GroceryItem(name: "Olive oil", quantity: "1 bottle"),
                GroceryItem(name: "Soy sauce", quantity: "1 bottle"),
                GroceryItem(name: "Honey", quantity: "1 jar"),
                GroceryItem(name: "Butter", quantity: "1 stick"),
            ]),
            GrocerySection(category: "Grains", items: [
                GroceryItem(name: "Sourdough bread", quantity: "2 loaves"),
                GroceryItem(name: "White rice", quantity: "2 lbs"),
            ]),
        ]

        return WeeklyMealPlan(days: days, groceryList: groceryList, generatedAt: Date(), goal: appState.goals.first ?? "Get lean & athletic")
    }

    // MARK: - Persistence

    private func savePlan() {
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: planKey)
        }
    }

    private func loadPlan() {
        guard let data = UserDefaults.standard.data(forKey: planKey),
              let saved = try? JSONDecoder().decode(WeeklyMealPlan.self, from: data) else { return }
        plan = saved
    }

    func resetPlan() {
        plan = nil
        UserDefaults.standard.removeObject(forKey: planKey)
    }

    enum MealPlanError: LocalizedError {
        case invalidURL, apiFailed, parseFailed
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .apiFailed: return "Meal plan generation failed"
            case .parseFailed: return "Could not parse meal plan"
            }
        }
    }
}
