import Foundation

// ════════════════════════════════════════════════════════════════════
//  MacroCalculator — computes personalized daily macro targets from
//  user profile data (height, weight, age, sex, activity, goals).
//
//  Uses Mifflin-St Jeor for BMR, activity multiplier for TDEE, then
//  adjusts based on nutrition goal. Returns nil for any field it
//  can't compute (lets the caller fall back to defaults).
// ════════════════════════════════════════════════════════════════════

struct MacroTargets {
    let calories: Int
    let protein: Int   // grams
    let carbs: Int     // grams
    let fat: Int       // grams
}

enum MacroCalculator {

    /// Compute personalized macro targets from AppState profile data.
    /// Returns nil if insufficient data (no weight).
    static func calculate(
        weightStr: String,
        weightUnit: String,
        heightRange: String,
        ageRange: String,
        gender: String,
        fitnessLevel: String,
        trainingDays: String,
        nutritionGoal: NutritionGoal?
    ) -> MacroTargets? {
        // Weight is required — everything else has reasonable defaults
        guard let weightValue = Double(weightStr), weightValue > 0 else { return nil }

        let weightKg: Double
        if weightUnit == "kg" {
            weightKg = weightValue
        } else {
            weightKg = weightValue * 0.453592
        }

        let heightCm = parseHeightCm(heightRange)
        let age = parseAge(ageRange)
        let isMale = gender.lowercased() != "female"

        // ─── BMR (Mifflin-St Jeor) ───
        let bmr: Double
        if isMale {
            bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) + 5
        } else {
            bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) - 161
        }

        // ─── Activity multiplier ───
        let activityMultiplier = activityFactor(fitnessLevel: fitnessLevel, trainingDays: trainingDays)
        let tdee = bmr * activityMultiplier

        // ─── Goal adjustment ───
        let goal = nutritionGoal ?? .generalWellness
        let (calorieAdjust, proteinPerKg, fatPct) = goalParameters(goal)

        let targetCalories = Int(tdee * calorieAdjust)

        // ─── Macro split ───
        let proteinGrams = Int(weightKg * proteinPerKg)
        let fatGrams = Int(Double(targetCalories) * fatPct / 9.0)
        let remainingCals = targetCalories - (proteinGrams * 4) - (fatGrams * 9)
        let carbGrams = max(0, remainingCals / 4)

        return MacroTargets(
            calories: targetCalories,
            protein: proteinGrams,
            carbs: carbGrams,
            fat: fatGrams
        )
    }

    // MARK: - Parsing Helpers

    /// Extracts a height in cm from ranges like "5'8\"–5'11\"".
    /// Uses the midpoint of the range.
    private static func parseHeightCm(_ range: String) -> Double {
        // Try to find feet/inches patterns like 5'4 or 6'3
        let pattern = #"(\d)'(\d{1,2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return 175 // default ~5'9"
        }

        let matches = regex.matches(in: range, range: NSRange(range.startIndex..., in: range))
        var heights: [Double] = []

        for match in matches {
            if let feetRange = Range(match.range(at: 1), in: range),
               let inchRange = Range(match.range(at: 2), in: range),
               let feet = Double(range[feetRange]),
               let inches = Double(range[inchRange]) {
                let totalInches = feet * 12 + inches
                heights.append(totalInches * 2.54)
            }
        }

        if heights.isEmpty {
            // Handle "Under 5'4"" or "Over 6'3""
            if range.contains("Under") { return 157 }  // ~5'2"
            if range.contains("Over") { return 195 }   // ~6'5"
            return 175 // default
        }

        return heights.reduce(0, +) / Double(heights.count) // midpoint
    }

    /// Extracts an age from ranges like "25–34". Uses midpoint.
    private static func parseAge(_ range: String) -> Int {
        let numbers = range.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 10 && $0 < 100 }

        if numbers.count >= 2 {
            return (numbers[0] + numbers[1]) / 2
        } else if let single = numbers.first {
            return single
        }
        return 30 // default
    }

    /// Maps fitness level + training days to an activity multiplier.
    private static func activityFactor(fitnessLevel: String, trainingDays: String) -> Double {
        let days = Int(trainingDays.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }.first ?? 3)

        let levelBase: Double
        switch fitnessLevel.lowercased() {
        case "beginner": levelBase = 1.2
        case "intermediate": levelBase = 1.35
        case "advanced": levelBase = 1.5
        default: levelBase = 1.3
        }

        // Add ~0.05 per training day above 3
        let dayBonus = Double(max(0, days - 3)) * 0.05
        return min(levelBase + dayBonus, 1.9)
    }

    /// Returns (calorie multiplier, protein g/kg, fat % of calories)
    /// based on the user's nutrition goal.
    private static func goalParameters(_ goal: NutritionGoal) -> (Double, Double, Double) {
        switch goal {
        case .fatLoss:
            return (0.80, 2.2, 0.25)    // 20% deficit, high protein, moderate fat
        case .buildMuscle:
            return (1.15, 2.0, 0.25)    // 15% surplus, high protein
        case .bodyRecomp:
            return (1.0, 2.2, 0.25)     // maintenance, high protein
        case .maintainWeight:
            return (1.0, 1.8, 0.30)     // maintenance, standard
        case .athleticPerformance:
            return (1.10, 2.0, 0.25)    // slight surplus, performance
        case .improveEnergy:
            return (1.0, 1.6, 0.30)     // maintenance, balanced
        case .improveDigestion:
            return (1.0, 1.6, 0.28)     // maintenance, moderate
        case .metabolicHealth:
            return (0.90, 1.8, 0.30)    // slight deficit, balanced
        case .reduceInflammation:
            return (1.0, 1.6, 0.32)     // maintenance, higher healthy fats
        case .heartHealth:
            return (0.95, 1.6, 0.28)    // slight deficit, moderate fat
        case .healthyAging:
            return (1.0, 1.8, 0.30)     // maintenance, adequate protein
        case .generalWellness:
            return (1.0, 1.6, 0.28)     // maintenance, balanced
        }
    }
}
