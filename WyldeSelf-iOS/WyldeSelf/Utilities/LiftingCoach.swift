import Foundation

/// AI-guided lifting knowledge — starting weights, progressive overload coaching,
/// and beginner education. All weights in lbs.
enum LiftingCoach {

    // MARK: - Starting Weight Suggestions

    struct WeightSuggestion {
        let weight: Double
        let note: String
    }

    /// Whether this exercise is bodyweight only.
    static func isBodyweight(_ exercise: String) -> Bool {
        let lower = exercise.lowercased()
        let bwExercises = [
            "push-up", "push up", "pushup", "pull-up", "pull up", "pullup",
            "chin-up", "chin up", "chinup", "dip", "plank", "burpee",
            "mountain climber", "jumping jack", "bodyweight squat",
            "lunge", "calf raise", "hanging leg raise", "leg raise",
            "sit-up", "sit up", "crunch", "flutter kick", "bicycle",
            "superman", "pike", "handstand", "muscle-up", "muscle up",
            "inverted row", "bodyweight"
        ]
        // Check if exercise name contains "body only" or matches known BW exercises
        if lower.contains("bodyweight") || lower.contains("body weight") { return true }
        return bwExercises.contains { lower.contains($0) }
    }

    /// Suggests a starting weight based on exercise, gender, and level.
    static func suggestedWeight(exercise: String, gender: String, level: String) -> WeightSuggestion {
        let lower = exercise.lowercased()

        // Bodyweight exercises
        if isBodyweight(exercise) {
            return WeightSuggestion(weight: 0, note: "Bodyweight. Focus on controlled reps and full range of motion.")
        }
        let isFemale = gender.lowercased() == "female"
        let isBeginner = level.lowercased() == "beginner"
        let isAdvanced = level.lowercased() == "advanced"

        // Compound movements
        if lower.contains("bench press") {
            if isFemale {
                return WeightSuggestion(weight: isBeginner ? 45 : isAdvanced ? 95 : 65, note: "Start with the bar if new. Add 5lb each week.")
            }
            return WeightSuggestion(weight: isBeginner ? 95 : isAdvanced ? 185 : 135, note: "Start light, focus on form. Add 5lb each session.")
        }
        if lower.contains("squat") {
            if isFemale {
                return WeightSuggestion(weight: isBeginner ? 45 : isAdvanced ? 135 : 85, note: "Bodyweight first if needed. Depth over weight.")
            }
            return WeightSuggestion(weight: isBeginner ? 95 : isAdvanced ? 225 : 155, note: "Start with the bar. Add 10lb per week.")
        }
        if lower.contains("deadlift") || lower.contains("romanian") {
            if isFemale {
                return WeightSuggestion(weight: isBeginner ? 65 : isAdvanced ? 155 : 95, note: "Hinge pattern matters most. Keep the bar close.")
            }
            return WeightSuggestion(weight: isBeginner ? 135 : isAdvanced ? 275 : 185, note: "Start moderate. Back flat, hips hinged.")
        }
        if lower.contains("overhead") && lower.contains("press") || lower.contains("shoulder press") {
            if isFemale {
                return WeightSuggestion(weight: isBeginner ? 15 : isAdvanced ? 45 : 25, note: "Dumbbells are fine to start. Brace your core.")
            }
            return WeightSuggestion(weight: isBeginner ? 65 : isAdvanced ? 135 : 95, note: "Start with dumbbells if barbell feels heavy.")
        }
        if lower.contains("row") {
            if isFemale {
                return WeightSuggestion(weight: isBeginner ? 45 : isAdvanced ? 95 : 65, note: "Squeeze shoulder blades together at the top.")
            }
            return WeightSuggestion(weight: isBeginner ? 95 : isAdvanced ? 185 : 135, note: "Pull to your lower chest. Control the negative.")
        }

        // Isolation movements
        if lower.contains("curl") {
            let w: Double = isFemale ? (isBeginner ? 8 : isAdvanced ? 20 : 12) : (isBeginner ? 15 : isAdvanced ? 40 : 25)
            return WeightSuggestion(weight: w, note: "Per dumbbell. No swinging — strict form builds muscle.")
        }
        if lower.contains("lateral raise") || lower.contains("fly") {
            let w: Double = isFemale ? (isBeginner ? 5 : isAdvanced ? 15 : 10) : (isBeginner ? 10 : isAdvanced ? 25 : 15)
            return WeightSuggestion(weight: w, note: "Light weight, high control. Ego-free zone.")
        }
        if lower.contains("tricep") || lower.contains("pushdown") || lower.contains("skull") {
            let w: Double = isFemale ? (isBeginner ? 15 : isAdvanced ? 40 : 25) : (isBeginner ? 30 : isAdvanced ? 70 : 50)
            return WeightSuggestion(weight: w, note: "Lock elbows in place. Slow and controlled.")
        }
        if lower.contains("leg press") {
            if isFemale {
                return WeightSuggestion(weight: isBeginner ? 90 : isAdvanced ? 270 : 180, note: "Feet shoulder-width. Full range of motion.")
            }
            return WeightSuggestion(weight: isBeginner ? 180 : isAdvanced ? 450 : 270, note: "Don't lock your knees at the top.")
        }
        if lower.contains("lunge") {
            let w: Double = isFemale ? (isBeginner ? 0 : isAdvanced ? 25 : 12) : (isBeginner ? 0 : isAdvanced ? 50 : 25)
            return WeightSuggestion(weight: w, note: w == 0 ? "Bodyweight to start. Balance before load." : "Per hand. Step with control.")
        }
        if lower.contains("pulldown") || lower.contains("pull-up") || lower.contains("chin") {
            let w: Double = isFemale ? (isBeginner ? 50 : isAdvanced ? 100 : 70) : (isBeginner ? 80 : isAdvanced ? 160 : 120)
            return WeightSuggestion(weight: w, note: lower.contains("pull-up") ? "Use the assisted machine if needed." : "Pull to upper chest, control the return.")
        }

        // Generic fallback
        let w: Double = isFemale ? (isBeginner ? 10 : isAdvanced ? 30 : 20) : (isBeginner ? 20 : isAdvanced ? 60 : 40)
        return WeightSuggestion(weight: w, note: "Start light. Form first, weight second.")
    }

    // MARK: - Progressive Overload Tips

    /// Returns a contextual overload tip based on set performance.
    static func overloadTip(exercise: String, completedWeight: Double, completedReps: Int, targetReps: Int) -> String {
        if completedReps >= targetReps + 2 {
            return "You hit \(completedReps) reps — increase weight by 5lb next set."
        }
        if completedReps >= targetReps {
            return "Right on target. Next session, try adding 5lb."
        }
        if completedReps >= targetReps - 2 {
            return "Close. Keep this weight until you hit all \(targetReps) reps consistently."
        }
        return "Too heavy — drop 10% and build back up with clean reps."
    }

    // MARK: - Beginner Education

    struct Concept {
        let title: String
        let explanation: String
    }

    static let beginnerConcepts: [Concept] = [
        Concept(
            title: "Progressive Overload",
            explanation: "The core principle of getting stronger. Each session, try to do slightly more than last time — more weight, more reps, or better form. Your body adapts to stress by building muscle. No stress increase = no growth."
        ),
        Concept(
            title: "Hypertrophy",
            explanation: "Muscle growth. It happens when you challenge your muscles with enough volume (sets × reps × weight) and then recover with food and sleep. The 8-12 rep range is optimal for size. Lower reps (3-5) build strength. Higher reps (15+) build endurance."
        ),
        Concept(
            title: "Compound vs Isolation",
            explanation: "Compound movements work multiple joints and muscle groups (squats, bench press, deadlifts). They build the most muscle and strength. Isolation movements target one muscle (curls, lateral raises). Build your program around compounds, then add isolation work."
        ),
        Concept(
            title: "Rest Between Sets",
            explanation: "Rest 2-3 minutes for heavy compounds (squat, bench, deadlift). Rest 60-90 seconds for isolation work. Rest matters — cutting it short means less weight and less growth. Use the rest timer."
        ),
        Concept(
            title: "RPE — Rate of Perceived Exertion",
            explanation: "A scale from 1-10. Most working sets should be RPE 7-8 (you could do 2-3 more reps). RPE 9-10 is all-out effort — save that for PRs. If every set is RPE 10, you're going too hard and risking injury."
        ),
        Concept(
            title: "Form Over Weight",
            explanation: "Bad form with heavy weight = injury. Good form with lighter weight = growth. Every rep should be controlled, especially the lowering phase (eccentric). If you can't control the weight, it's too heavy."
        ),
    ]
}
