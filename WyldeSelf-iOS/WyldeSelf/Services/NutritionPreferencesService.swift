import Foundation
import Supabase

@MainActor
final class NutritionPreferencesService: ObservableObject {
    static let shared = NutritionPreferencesService()

    @Published var preferences: NutritionPreferences = .default
    @Published var draft: NutritionPreferences = .default
    @Published var hasUnsavedChanges = false
    @Published var isSaving = false

    private let storageKey = "wylde_nutrition_prefs"
    private let secure = SecureStorage.shared

    private init() {
        loadLocal()
    }

    // MARK: - Local Persistence

    func loadLocal() {
        if let saved = secure.getCodable(NutritionPreferences.self, forKey: storageKey) {
            preferences = saved
        }
    }

    private func saveLocal() {
        secure.setCodable(preferences, forKey: storageKey)
    }

    // MARK: - Supabase Persistence

    func loadFromSupabase() async {
        guard let uid = await AuthService.shared.userID else { return }

        do {
            let row: SupabaseRow = try await SupabaseService.shared
                .from("nutrition_preferences")
                .select("preferences_data")
                .eq("user_id", value: uid)
                .single()
                .execute()
                .value

            if let data = row.preferences_data.data(using: .utf8) {
                let decoded = try JSONDecoder().decode(NutritionPreferences.self, from: data)
                preferences = decoded
                saveLocal()
            }
        } catch {
            #if DEBUG
            print("[NutritionPrefs] Supabase load failed: \(error.localizedDescription)")
            #endif
        }
    }

    func save() async {
        isSaving = true
        defer { isSaving = false }

        preferences.updatedAt = Date()
        saveLocal()

        guard let uid = await AuthService.shared.userID else { return }

        do {
            let prefsData: Data = try JSONEncoder().encode(preferences)
            let prefsJSON = String(data: prefsData, encoding: .utf8) ?? "{}"

            let row = SupabaseUpsertRow(
                user_id: uid,
                preferences_data: prefsJSON,
                dietary_framework: preferences.dietaryFramework?.rawValue,
                restrictions: preferences.restrictions.map(\.rawValue),
                source: preferences.source.rawValue
            )

            try await SupabaseService.shared
                .from("nutrition_preferences")
                .upsert(row)
                .execute()
        } catch {
            #if DEBUG
            print("[NutritionPrefs] Supabase save failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Draft Editing

    func beginEditing() {
        draft = preferences
        hasUnsavedChanges = false
    }

    func updateDraft(_ block: (inout NutritionPreferences) -> Void) {
        block(&draft)
        hasUnsavedChanges = (draft != preferences)
    }

    func commitEditing() async {
        preferences = draft
        hasUnsavedChanges = false
        await save()
    }

    func cancelEditing() {
        draft = preferences
        hasUnsavedChanges = false
    }

    // MARK: - Macro Sync

    func syncMacroGoalsToAppState(_ appState: AppState) {
        // If the user has manually set targets in preferences, use those
        if let cal = preferences.calorieTarget { appState.caloriesGoal = cal }
        if let prot = preferences.proteinTarget { appState.proteinGoal = prot }
        if let carb = preferences.carbTarget { appState.carbsGoal = carb }
        if let fat = preferences.fatTarget { appState.fatGoal = fat }

        // If no manual targets, calculate from body data + goals
        let hasManualTargets = preferences.calorieTarget != nil
        if !hasManualTargets {
            calculateAndApplyMacros(appState)
        }
    }

    /// Compute macro targets from user's height, weight, age, sex, activity, and nutrition goals.
    func calculateAndApplyMacros(_ appState: AppState) {
        guard let targets = MacroCalculator.calculate(
            weightStr: appState.weight,
            weightUnit: appState.weightUnit,
            heightRange: appState.heightRange,
            ageRange: appState.ageRange,
            gender: appState.gender,
            fitnessLevel: appState.fitnessLevel,
            trainingDays: appState.trainingDays,
            nutritionGoal: preferences.goals.first
        ) else { return }

        appState.caloriesGoal = targets.calories
        appState.proteinGoal = targets.protein
        appState.carbsGoal = targets.carbs
        appState.fatGoal = targets.fat
    }

    // MARK: - AI Prompt Context

    func buildPromptContext() -> String {
        let p = preferences
        var lines: [String] = []

        lines.append("NUTRITION PREFERENCES:")

        if let framework = p.dietaryFramework {
            lines.append("Dietary framework: \(framework.displayName)")
            if let disclaimer = framework.medicalDisclaimer {
                lines.append("Note: \(disclaimer)")
            }
        }

        if !p.goals.isEmpty {
            lines.append("Goals: \(p.goals.map(\.displayName).joined(separator: ", "))")
        }

        // Hard exclusions — critical section
        if !p.restrictions.isEmpty {
            lines.append("")
            lines.append("HARD EXCLUSIONS (NEVER include these — these are medical allergies and strict dietary restrictions):")
            for r in p.restrictions {
                lines.append("- \(r.displayName)")
            }
            if !p.otherRestrictionText.isEmpty {
                lines.append("- Other: \(p.otherRestrictionText)")
            }
            lines.append("Do NOT include ANY ingredient that contains or is derived from the above allergens.")
        }

        if !p.excludedFoods.isEmpty {
            lines.append("Additional excluded foods: \(p.excludedFoods.joined(separator: ", "))")
        }

        // Food preferences
        if !p.favoriteFoods.isEmpty || !p.dislikedFoods.isEmpty || !p.preferredProteins.isEmpty || !p.preferredCuisines.isEmpty {
            lines.append("")
            lines.append("Food preferences:")
            if !p.favoriteFoods.isEmpty { lines.append("- Favorites: \(p.favoriteFoods.joined(separator: ", "))") }
            if !p.dislikedFoods.isEmpty { lines.append("- Dislikes: \(p.dislikedFoods.joined(separator: ", "))") }
            if !p.preferredProteins.isEmpty { lines.append("- Preferred proteins: \(p.preferredProteins.joined(separator: ", "))") }
            if !p.preferredCuisines.isEmpty { lines.append("- Preferred cuisines: \(p.preferredCuisines.joined(separator: ", "))") }
        }

        // Meal structure
        lines.append("")
        lines.append("Meal structure:")
        lines.append("- \(p.mealsPerDay) meals + \(p.snacksPerDay) snacks per day")
        lines.append("- Include breakfast: \(p.includeBreakfast ? "yes" : "no")")
        if p.intermittentFasting, let start = p.eatingWindowStart, let end = p.eatingWindowEnd {
            lines.append("- Intermittent fasting: eating window \(start) to \(end)")
        }
        lines.append("- Leftovers OK: \(p.leftoversAllowed ? "yes" : "no")")
        lines.append("- Repeat meals OK: \(p.repeatMealsAllowed ? "yes" : "no")")
        if p.householdSize > 1 {
            lines.append("- Household size: \(p.householdSize) people")
        }
        if !p.mealPrepDays.isEmpty {
            lines.append("- Meal prep days: \(p.mealPrepDays.joined(separator: ", "))")
        }

        // Lifestyle
        if let skill = p.cookingSkill {
            lines.append("- Cooking skill: \(skill.displayName)")
        }
        if let maxMin = p.maxCookingMinutes {
            lines.append("- Max cooking time: \(maxMin) minutes")
        }
        if !p.availableAppliances.isEmpty {
            lines.append("- Available appliances: \(p.availableAppliances.map(\.displayName).joined(separator: ", "))")
        }
        if let budget = p.weeklyBudget, !budget.isEmpty {
            lines.append("- Weekly budget: \(budget)")
        }

        // Targets
        let targets = [
            p.calorieTarget.map { "Calories: ~\($0)" },
            p.proteinTarget.map { "Protein: ~\($0)g" },
            p.carbTarget.map { "Carbs: ~\($0)g" },
            p.fatTarget.map { "Fat: ~\($0)g" },
            p.fiberTarget.map { "Fiber: ~\($0)g" },
        ].compactMap { $0 }

        if !targets.isEmpty {
            lines.append("")
            lines.append("Daily nutrition targets:")
            for t in targets { lines.append("- \(t)") }
        }

        if !p.clinicalNotes.isEmpty {
            lines.append("")
            lines.append("Additional notes: \(p.clinicalNotes)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Allergy Enforcement

    /// Deterministically checks whether any ingredient violates the user's restrictions.
    /// Returns the list of violations found (empty = safe).
    func checkAllergyViolations(ingredients: [String]) -> [(ingredient: String, restriction: Restriction)] {
        var violations: [(String, Restriction)] = []
        for ingredient in ingredients {
            let lower = ingredient.lowercased()
            for restriction in preferences.restrictions {
                for keyword in restriction.ingredientKeywords {
                    if lower.contains(keyword) {
                        violations.append((ingredient, restriction))
                        break
                    }
                }
            }
        }
        return violations
    }

    // MARK: - Reset

    func reset() {
        preferences = .default
        draft = .default
        hasUnsavedChanges = false
        secure.remove(forKey: storageKey)
    }
}

// MARK: - Supabase Row Types

private struct SupabaseRow: Decodable {
    let preferences_data: String
}

private struct SupabaseUpsertRow: Encodable {
    let user_id: String
    let preferences_data: String
    let dietary_framework: String?
    let restrictions: [String]
    let source: String
}
