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
            #if DEBUG
            print("[MealPlanService] AI failed: \(error), using template")
            #endif
            self.plan = fallbackPlan(appState: appState)
            savePlan()
        }
    }

    private func callAI(appState: AppState) async throws -> WeeklyMealPlan {
        guard let url = URL(string: "https://www.wyldeself.com/api/openai") else {
            throw MealPlanError.invalidURL
        }

        let prompt = buildPrompt(appState: appState)
        let payload: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 4096,
            "temperature": 0.8,
            "messages": [
                ["role": "system", "content": "You are an elite sports nutritionist and registered dietitian with expertise in body composition, performance nutrition, and meal prep. You create detailed, varied, macro-precise meal plans with real recipes people actually want to eat. Include protein shakes, functional snacks, and practical prep instructions. You are NOT a medical professional — never recommend below 1200 cal/day for women or 1500 cal/day for men. If the user reports pregnancy, breastfeeding, or medical conditions, recommend consulting a doctor as nutrition needs change significantly. If eating patterns appear severely restrictive, flag it and suggest professional guidance. Return ONLY valid JSON."],
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await AuthService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 60
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
        let carbsGoal = appState.carbsGoal
        let fatGoal = appState.fatGoal
        let weight = appState.weight.isEmpty ? "unknown" : appState.weight + " " + appState.weightUnit
        let height = appState.heightRange.isEmpty ? "unknown" : appState.heightRange
        let gender = appState.gender.isEmpty ? "unspecified" : appState.gender
        let level = appState.fitnessLevel.isEmpty ? "intermediate" : appState.fitnessLevel
        let trainingDays = appState.trainingDays.isEmpty ? "4 days" : appState.trainingDays

        return """
        Create a 7-day meal plan for this person:

        Gender: \(gender)
        Weight: \(weight)
        Height: \(height)
        Fitness level: \(level)
        Training: \(trainingDays)/week
        Goals: \(goals)
        Dietary preferences: \(diet)
        \(appState.dietNotes.isEmpty ? "" : "Diet notes: \(appState.dietNotes)")
        \(appState.healthConcerns.isEmpty ? "" : "Health concerns: \(appState.healthConcerns.joined(separator: ", "))")

        Daily macro targets:
        - Calories: ~\(calorieGoal)
        - Protein: ~\(proteinGoal)g
        - Carbs: ~\(carbsGoal)g
        - Fat: ~\(fatGoal)g

        CRITICAL RULES:
        - Every day MUST have DIFFERENT meals. No repeated meals across the week.
        - Include variety: different proteins (chicken, fish, beef, turkey, shrimp, tofu), different grains, different vegetables.
        - Include 1-2 protein shakes per day if needed to hit protein targets (whey, plant-based, or collagen).
        - Training days should have slightly higher carbs pre/post workout.
        - Rest days can have slightly lower calories.
        - Include meal prep friendly options for weekdays.
        - Weekend meals can be slightly more elaborate.
        - Snacks should be functional: protein bars, shakes, nuts, Greek yogurt, fruit.
        - Calculate macros accurately for each meal — they should add up to daily targets.

        Return JSON in this EXACT format:
        {
          "days": [
            {
              "id": "monday",
              "dayName": "Monday",
              "meals": [
                {
                  "mealType": "Breakfast",
                  "name": "Meal name",
                  "description": "Brief description",
                  "ingredients": ["ingredient 1", "ingredient 2"],
                  "instructions": ["Step 1", "Step 2"],
                  "prepTime": 10,
                  "calories": 520,
                  "protein": 35,
                  "carbs": 40,
                  "fat": 20
                }
              ]
            }
          ],
          "groceryList": [
            {
              "category": "Protein",
              "items": [{"name": "Item", "quantity": "amount"}]
            }
          ],
          "generatedAt": "\(ISO8601DateFormatter().string(from: Date()))",
          "goal": "\(goals)"
        }

        Include 3 meals (Breakfast, Lunch, Dinner) and 1-2 Snacks per day.
        Keep meals practical — 10-30 min prep. Real food.
        At least 1 protein shake or smoothie per day.
        Grocery list grouped by: Protein, Produce, Dairy, Pantry, Grains, Supplements.
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
