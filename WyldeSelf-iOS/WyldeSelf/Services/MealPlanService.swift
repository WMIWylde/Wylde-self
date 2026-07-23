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

    // MARK: - Lock / Favorite

    func toggleLock(dayId: String, mealId: UUID) {
        guard var plan = plan,
              let dayIndex = plan.days.firstIndex(where: { $0.id == dayId }),
              let mealIndex = plan.days[dayIndex].meals.firstIndex(where: { $0.id == mealId }) else { return }
        plan.days[dayIndex].meals[mealIndex].isLocked.toggle()
        self.plan = plan
        savePlan()
    }

    func toggleFavorite(dayId: String, mealId: UUID) {
        guard var plan = plan,
              let dayIndex = plan.days.firstIndex(where: { $0.id == dayId }),
              let mealIndex = plan.days[dayIndex].meals.firstIndex(where: { $0.id == mealId }) else { return }
        plan.days[dayIndex].meals[mealIndex].isFavorite.toggle()
        self.plan = plan
        savePlan()
    }

    // MARK: - Swap Meal

    @Published var isSwapping = false

    func swapMeal(dayId: String, mealId: UUID, appState: AppState) async {
        guard let plan = plan,
              let dayIndex = plan.days.firstIndex(where: { $0.id == dayId }),
              let mealIndex = plan.days[dayIndex].meals.firstIndex(where: { $0.id == mealId }) else { return }

        let oldMeal = plan.days[dayIndex].meals[mealIndex]
        isSwapping = true
        defer { isSwapping = false }

        do {
            let replacement = try await generateSingleMeal(
                mealType: oldMeal.mealType,
                replacing: oldMeal.name,
                dayName: plan.days[dayIndex].dayName,
                appState: appState
            )
            var updatedPlan = plan
            var newMeal = replacement
            newMeal.isSwapped = true
            updatedPlan.days[dayIndex].meals[mealIndex] = newMeal
            // Rebuild grocery list
            updatedPlan.groceryList = RecipeBookService.shared.buildGroceryList(from: updatedPlan.days)
            self.plan = updatedPlan
            savePlan()
        } catch {
            #if DEBUG
            print("[MealPlanService] Swap failed: \(error)")
            #endif
        }
    }

    // MARK: - Regenerate Day

    @Published var isRegeneratingDay = false

    func regenerateDay(dayId: String, appState: AppState) async {
        guard var plan = plan,
              let dayIndex = plan.days.firstIndex(where: { $0.id == dayId }) else { return }

        isRegeneratingDay = true
        defer { isRegeneratingDay = false }

        let day = plan.days[dayIndex]
        let lockedMeals = day.meals.filter(\.isLocked)
        let unlockedTypes = day.meals.filter { !$0.isLocked }.map(\.mealType)

        if unlockedTypes.isEmpty { return } // All locked, nothing to regenerate

        do {
            var newMeals = lockedMeals
            for mealType in unlockedTypes {
                let meal = try await generateSingleMeal(
                    mealType: mealType,
                    replacing: nil,
                    dayName: day.dayName,
                    appState: appState
                )
                newMeals.append(meal)
            }

            // Sort by meal type order
            let typeOrder: [MealType] = [.breakfast, .lunch, .dinner, .snack]
            newMeals.sort { a, b in
                (typeOrder.firstIndex(of: a.mealType) ?? 99) < (typeOrder.firstIndex(of: b.mealType) ?? 99)
            }

            plan.days[dayIndex].meals = newMeals
            plan.groceryList = RecipeBookService.shared.buildGroceryList(from: plan.days)
            self.plan = plan
            savePlan()
        } catch {
            #if DEBUG
            print("[MealPlanService] Day regeneration failed: \(error)")
            #endif
        }
    }

    // MARK: - Single Meal Generation

    private func generateSingleMeal(mealType: MealType, replacing: String?, dayName: String, appState: AppState) async throws -> PlannedMeal {
        guard let url = URL(string: "https://www.wyldeself.com/api/openai") else {
            throw MealPlanError.invalidURL
        }

        let nutritionContext = NutritionPreferencesService.shared.buildPromptContext()
        let prefs = NutritionPreferencesService.shared.preferences
        let calorieGoal = prefs.calorieTarget ?? appState.caloriesGoal

        var prompt = """
        Generate ONE \(mealType.rawValue.lowercased()) meal for \(dayName).

        \(nutritionContext)

        Daily calorie target: ~\(calorieGoal)
        """

        if let old = replacing {
            prompt += "\n\nThis replaces '\(old)'. Generate something DIFFERENT."
        }

        // List existing meals in the plan to avoid repeats
        if let plan = plan {
            let existingNames = plan.days.flatMap(\.meals).map(\.name)
            if !existingNames.isEmpty {
                prompt += "\n\nDo NOT repeat any of these meals: \(existingNames.joined(separator: ", "))"
            }
        }

        prompt += """

        Include a short identity-based reason for this meal (1 sentence, motivational, not preachy).
        Include dietary tags like "high-protein", "quick", "low-carb", etc.

        Return ONLY valid JSON:
        {
          "mealType": "\(mealType.rawValue)",
          "name": "Meal name",
          "description": "Brief description",
          "ingredients": ["ingredient 1", "ingredient 2"],
          "instructions": ["Step 1", "Step 2"],
          "prepTime": 15,
          "calories": 500,
          "protein": 35,
          "carbs": 40,
          "fat": 18,
          "identityReason": "Supports the consistent energy you're building.",
          "dietaryTags": ["high-protein", "quick"]
        }
        """

        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "max_tokens": 1024,
            "temperature": 0.9,
            "messages": [
                ["role": "system", "content": "You are a sports nutritionist. Generate one meal as JSON only. Never recommend below 200 cal per meal. Use non-shaming, identity-affirming language."],
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await AuthService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 30
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
        let meal = try JSONDecoder().decode(PlannedMeal.self, from: jsonData)

        // Allergy check
        let violations = NutritionPreferencesService.shared.checkAllergyViolations(ingredients: meal.ingredients)
        if !violations.isEmpty {
            #if DEBUG
            print("[MealPlanService] Swap result had allergy violation, retrying would be needed")
            #endif
            throw MealPlanError.allergyViolation
        }

        return meal
    }

    // MARK: - Plan Has Active Edits

    var planHasActiveEdits: Bool {
        guard let plan = plan else { return false }
        return plan.days.contains { day in
            day.meals.contains { $0.completed || $0.isSwapped || $0.isLocked || $0.isFavorite }
        } || plan.groceryList.contains { section in
            section.items.contains(where: \.checked)
        }
    }

    // MARK: - Grocery Operations

    func toggleGrocery(sectionId: UUID, itemId: UUID) {
        guard var plan = plan,
              let secIndex = plan.groceryList.firstIndex(where: { $0.id == sectionId }),
              let itemIndex = plan.groceryList[secIndex].items.firstIndex(where: { $0.id == itemId }) else { return }
        plan.groceryList[secIndex].items[itemIndex].checked.toggle()
        self.plan = plan
        savePlan()
    }

    func togglePantryItem(sectionId: UUID, itemId: UUID) {
        guard var plan = plan,
              let secIndex = plan.groceryList.firstIndex(where: { $0.id == sectionId }),
              let itemIndex = plan.groceryList[secIndex].items.firstIndex(where: { $0.id == itemId }) else { return }
        plan.groceryList[secIndex].items[itemIndex].isPantryItem.toggle()
        // Pantry items are auto-checked (you already have them)
        if plan.groceryList[secIndex].items[itemIndex].isPantryItem {
            plan.groceryList[secIndex].items[itemIndex].checked = true
        }
        self.plan = plan
        savePlan()
    }

    func addCustomGroceryItem(name: String, category: String) {
        guard var plan = plan, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        if let secIndex = plan.groceryList.firstIndex(where: { $0.category == category }) {
            plan.groceryList[secIndex].items.append(
                GroceryItem(name: name.trimmingCharacters(in: .whitespaces), quantity: "", isCustom: true)
            )
        } else {
            plan.groceryList.append(
                GrocerySection(category: category, items: [
                    GroceryItem(name: name.trimmingCharacters(in: .whitespaces), quantity: "", isCustom: true)
                ])
            )
        }
        self.plan = plan
        savePlan()
    }

    func removeGroceryItem(sectionId: UUID, itemId: UUID) {
        guard var plan = plan,
              let secIndex = plan.groceryList.firstIndex(where: { $0.id == sectionId }) else { return }
        plan.groceryList[secIndex].items.removeAll { $0.id == itemId }
        // Remove empty sections
        if plan.groceryList[secIndex].items.isEmpty {
            plan.groceryList.remove(at: secIndex)
        }
        self.plan = plan
        savePlan()
    }

    func regenerateGroceryList() {
        guard var plan = plan else { return }
        // Preserve custom items and pantry markings
        let customItems = plan.groceryList.flatMap { section in
            section.items.filter(\.isCustom).map { (section.category, $0) }
        }
        let pantryNames = Set(plan.groceryList.flatMap { $0.items.filter(\.isPantryItem) }.map { $0.name.lowercased() })
        let checkedNames = Set(plan.groceryList.flatMap { $0.items.filter(\.checked) }.map { $0.name.lowercased() })

        // Rebuild from meals
        var newList = RecipeBookService.shared.buildGroceryList(from: plan.days)

        // Re-apply pantry and checked status
        for secIdx in newList.indices {
            for itemIdx in newList[secIdx].items.indices {
                let lower = newList[secIdx].items[itemIdx].name.lowercased()
                if pantryNames.contains(lower) {
                    newList[secIdx].items[itemIdx].isPantryItem = true
                    newList[secIdx].items[itemIdx].checked = true
                } else if checkedNames.contains(lower) {
                    newList[secIdx].items[itemIdx].checked = true
                }
            }
        }

        // Re-add custom items
        for (category, item) in customItems {
            if let secIdx = newList.firstIndex(where: { $0.category == category }) {
                newList[secIdx].items.append(item)
            } else {
                newList.append(GrocerySection(category: category, items: [item]))
            }
        }

        plan.groceryList = newList
        self.plan = plan
        savePlan()
    }

    var groceryProgress: (checked: Int, total: Int) {
        guard let plan = plan else { return (0, 0) }
        let total = plan.groceryList.reduce(0) { $0 + $1.items.count }
        let checked = plan.groceryList.reduce(0) { $0 + $1.items.filter(\.checked).count }
        return (checked, total)
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
        var plan = try JSONDecoder().decode(WeeklyMealPlan.self, from: jsonData)

        // Deterministic allergy enforcement — don't trust the AI alone
        let prefsService = NutritionPreferencesService.shared
        if !prefsService.preferences.restrictions.isEmpty {
            for dayIndex in plan.days.indices {
                plan.days[dayIndex].meals.removeAll { meal in
                    let allIngredients = meal.ingredients
                    let violations = prefsService.checkAllergyViolations(ingredients: allIngredients)
                    if !violations.isEmpty {
                        #if DEBUG
                        print("[MealPlanService] Removed meal '\(meal.name)' — allergy violation: \(violations.map { "\($0.0) (\($0.1.displayName))" })")
                        #endif
                        return true
                    }
                    return false
                }
            }
        }

        return plan
    }

    private func buildPrompt(appState: AppState) -> String {
        let nutritionContext = NutritionPreferencesService.shared.buildPromptContext()
        let prefs = NutritionPreferencesService.shared.preferences
        let goals = prefs.goals.isEmpty
            ? (appState.goals.isEmpty ? "Get lean & athletic" : appState.goals.joined(separator: ", "))
            : prefs.goals.map(\.displayName).joined(separator: ", ")

        let weight = appState.weight.isEmpty ? "unknown" : appState.weight + " " + appState.weightUnit
        let height = appState.heightRange.isEmpty ? "unknown" : appState.heightRange
        let gender = appState.gender.isEmpty ? "unspecified" : appState.gender
        let level = appState.fitnessLevel.isEmpty ? "intermediate" : appState.fitnessLevel
        let trainingDays = appState.trainingDays.isEmpty ? "4 days" : appState.trainingDays

        // Use structured targets if set, otherwise fall back to AppState defaults
        let calorieGoal = prefs.calorieTarget ?? appState.caloriesGoal
        let proteinGoal = prefs.proteinTarget ?? appState.proteinGoal
        let carbsGoal = prefs.carbTarget ?? appState.carbsGoal
        let fatGoal = prefs.fatTarget ?? appState.fatGoal

        let mealsPerDay = prefs.mealsPerDay
        let snacksPerDay = prefs.snacksPerDay

        return """
        Create a 7-day meal plan for this person:

        Gender: \(gender)
        Weight: \(weight)
        Height: \(height)
        Fitness level: \(level)
        Training: \(trainingDays)/week
        \(appState.healthConcerns.isEmpty ? "" : "Health concerns: \(appState.healthConcerns.joined(separator: ", "))")

        \(nutritionContext)

        Daily macro targets:
        - Calories: ~\(calorieGoal)
        - Protein: ~\(proteinGoal)g
        - Carbs: ~\(carbsGoal)g
        - Fat: ~\(fatGoal)g

        CRITICAL RULES:
        - Every day MUST have DIFFERENT meals. No repeated meals across the week.
        - Include variety in proteins, grains, and vegetables throughout the week.
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
                  "fat": 20,
                  "identityReason": "Supports the consistent energy you are building.",
                  "dietaryTags": ["high-protein", "quick"]
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

        Include \(mealsPerDay) meals and \(snacksPerDay) snacks per day.
        \(prefs.includeBreakfast ? "Include breakfast." : "Skip breakfast — start with lunch.")
        Keep meals practical — 10-30 min prep. Real food.
        Grocery list grouped by: Protein, Produce, Dairy, Pantry, Grains, Supplements.

        For each meal include:
        - "identityReason": A short sentence connecting the meal to the person's goals. Use encouraging, non-shaming language. Examples: "Supports the energy and consistency you are building.", "A high-protein meal that reinforces your strength goal.", "Simple enough to repeat on busy days."
        - "dietaryTags": Array of tags like "high-protein", "quick", "low-carb", "meal-prep", "anti-inflammatory", etc.
        """
    }

    // MARK: - Build Manual Plan

    func buildManualPlan(days: [DayMealPlan], goal: String) {
        let groceryList = RecipeBookService.shared.buildGroceryList(from: days)
        self.plan = WeeklyMealPlan(days: days, groceryList: groceryList, generatedAt: Date(), goal: goal, source: .manual)
        savePlan()
    }

    // MARK: - Fallback

    private func fallbackPlan(appState: AppState) -> WeeklyMealPlan {
        let recipes = RecipeBookService.recipes
        let breakfasts = recipes.filter { $0.mealType == .breakfast }.shuffled()
        let lunches = recipes.filter { $0.mealType == .lunch }.shuffled()
        let dinners = recipes.filter { $0.mealType == .dinner }.shuffled()
        let snacks = recipes.filter { $0.mealType == .snack }.shuffled()

        let prefs = NutritionPreferencesService.shared.preferences
        let mealsPerDay = prefs.mealsPerDay
        let snacksPerDay = max(1, prefs.snacksPerDay)

        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let days = dayNames.enumerated().map { i, day -> DayMealPlan in
            var meals: [PlannedMeal] = []

            // Main meals — each day gets a different one
            if prefs.includeBreakfast && mealsPerDay >= 3 {
                meals.append(breakfasts[i % breakfasts.count].toPlannedMeal())
            }
            meals.append(lunches[i % lunches.count].toPlannedMeal())
            meals.append(dinners[i % dinners.count].toPlannedMeal())

            // Snacks — rotate through, offset so each day is different
            for s in 0..<snacksPerDay {
                let snackIndex = (i * snacksPerDay + s) % snacks.count
                meals.append(snacks[snackIndex].toPlannedMeal())
            }

            return DayMealPlan(id: day.lowercased(), dayName: day, meals: meals)
        }

        let groceryList = RecipeBookService.shared.buildGroceryList(from: days)
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
        case invalidURL, apiFailed, parseFailed, allergyViolation
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .apiFailed: return "Meal plan generation failed"
            case .parseFailed: return "Could not parse meal plan"
            case .allergyViolation: return "Generated meal contained restricted ingredients"
            }
        }
    }
}
