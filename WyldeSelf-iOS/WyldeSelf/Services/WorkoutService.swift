import Foundation
import SwiftUI

@MainActor
final class WorkoutService: ObservableObject {
    static let shared = WorkoutService()
    private init() { loadProgram(); loadPRs() }

    @Published var program: WorkoutProgram?
    @Published var isGenerating = false
    @Published var generationError: String?
    @Published var personalRecords: [String: PersonalRecord] = [:]

    private let programKey = "wylde_workout_program"
    private let prKey = "wylde_personal_records"

    // MARK: - Today's Workout

    func todaysWorkout(day: Int) -> WorkoutDay? {
        guard let program = program else { return nil }
        let index = (day - 1) % program.days.count
        return program.days.indices.contains(index) ? program.days[index] : nil
    }

    // MARK: - Program Generation

    func generateProgram(appState: AppState) async {
        isGenerating = true
        generationError = nil

        // Try AI generation with a timeout, fall back to template
        do {
            let program = try await withThrowingTaskGroup(of: WorkoutProgram.self) { group in
                group.addTask {
                    try await self.callAIForProgram(appState: appState)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 60_000_000_000) // 60s timeout
                    throw WorkoutError.generationFailed
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            self.program = program
            saveProgram()
            print("[WorkoutService] ✅ AI program generated: \(program.days.count) days")
        } catch {
            print("[WorkoutService] ❌ AI failed: \(error.localizedDescription) — using fallback template")
            self.program = fallbackProgram(goal: appState.goals.first ?? "Get lean & athletic")
            saveProgram()
        }

        isGenerating = false
    }

    private func callAIForProgram(appState: AppState) async throws -> WorkoutProgram {
        guard let url = URL(string: "https://www.wyldeself.com/api/openai") else {
            throw WorkoutError.invalidURL
        }

        let prompt = buildProgramPrompt(appState: appState)
        let payload: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 4096,
            "messages": [
                ["role": "system", "content": "You are a world-class NSCA-certified strength and conditioning coach with 20+ years of experience training athletes, executives, and transformation clients. You design periodized programs with precise exercise selection, set/rep schemes, tempo prescriptions, and coaching cues. Return ONLY valid JSON."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WorkoutError.generationFailed
        }

        // Parse the AI response
        let aiResponse = try JSONDecoder().decode(AIResponse.self, from: data)
        guard let content = aiResponse.choices?.first?.message?.content else {
            throw WorkoutError.generationFailed
        }

        return try parseAIProgram(content, goal: appState.goals.first ?? "Get lean & athletic")
    }

    private func buildProgramPrompt(appState: AppState) -> String {
        let days = appState.trainingDays.isEmpty ? "4 days" : appState.trainingDays
        let level = appState.fitnessLevel.isEmpty ? "intermediate" : appState.fitnessLevel
        let goals = appState.goals.isEmpty ? ["Get lean & athletic"] : appState.goals
        let equipment = appState.equipment.isEmpty ? "Some basics" : appState.equipment
        let gym = appState.gymAccess.isEmpty ? "No" : appState.gymAccess
        let gender = appState.gender.isEmpty ? "male" : appState.gender
        let weight = appState.weight.isEmpty ? "" : "Weight: \(appState.weight) \(appState.weightUnit)"
        let height = appState.heightRange.isEmpty ? "" : "Height: \(appState.heightRange)"
        let age = appState.ageRange.isEmpty ? "" : "Age range: \(appState.ageRange)"
        let seed = Int.random(in: 1000...9999) // Forces different output each generation

        return """
        Design a unique, personalized \(days)/week training program. Variation seed: \(seed).

        CLIENT PROFILE:
        - Gender: \(gender)
        \(weight.isEmpty ? "" : "- \(weight)")
        \(height.isEmpty ? "" : "- \(height)")
        \(age.isEmpty ? "" : "- \(age)")
        - Fitness level: \(level)
        - Goals: \(goals.joined(separator: ", "))
        - Equipment at home: \(equipment)
        - Gym access: \(gym)
        \(appState.gymName.isEmpty ? "" : "- Gym: \(appState.gymName)")
        \(appState.healthConcerns.isEmpty ? "" : "- Health concerns: \(appState.healthConcerns.joined(separator: ", "))")

        PROGRAMMING PRINCIPLES:
        - Design this as a periodized program, not a random list of exercises
        - Each day should have a clear training focus with logical exercise pairings
        - Use progressive overload principles: compound movements first, isolation after
        - Vary rep ranges: strength (3-5), hypertrophy (8-12), endurance (15-20)
        - Include unilateral work (single-leg, single-arm) at least once per week
        - Include a posterior chain focus day or emphasis
        - Vary cardio: don't use treadmill every day — rotate rowing, cycling, stairmaster, jump rope, sled push, farmer's walks, battle ropes
        - For \(level) level: \(level == "beginner" ? "focus on movement patterns and form, use machines where helpful" : level == "advanced" ? "include supersets, drop sets, tempo work, and advanced variations" : "balance compound strength with targeted hypertrophy work")

        GOAL-SPECIFIC ADJUSTMENTS:
        \(goals.contains("Burn fat") ? "- Higher volume, shorter rest (45-60s), include HIIT finishers" : "")
        \(goals.contains("Build muscle") ? "- Heavy compounds 4-6 reps, moderate isolation 10-12 reps, rest 2-3 min on compounds" : "")
        \(goals.contains("Improve endurance") ? "- Include circuit-style training, higher rep ranges, active recovery exercises" : "")
        \(goals.contains("Increase flexibility") ? "- Include mobility exercises, yoga-inspired movements, dynamic stretching between sets" : "")
        \(goals.contains("Build confidence") ? "- Focus on visible muscle groups (shoulders, arms, chest, glutes), include mirror-friendly exercises" : "")

        MANDATORY STRUCTURE:
        - First exercise: "Dynamic Warmup", "10 min", "Prepare the body for training"
        - Last exercise: cardio/conditioning finisher, "15-20 min" (vary the type each day)
        - Between warmup and finisher: 5-7 strength exercises with specific set × rep schemes
        - Use precise exercise names (e.g., "Incline Dumbbell Press 30°", not "Chest Press")
        - Each exercise needs a 10-20 word coaching cue with form tips

        DO NOT repeat the same exercises across days. Each day should feel distinct.
        DO NOT use generic exercises like "Push-ups" unless the client has no equipment.
        DO NOT give the same cardio finisher on multiple days.

        Return ONLY a valid JSON array:
        [
          {
            "day": "Day 01",
            "focus": "Upper Push + Shoulders",
            "exercises": [
              ["Dynamic Warmup", "10 min", "Prepare the body for training"],
              ["Exercise Name", "4 × 8", "Detailed coaching cue about form"],
              ["Conditioning Finisher Name", "15-20 min", "Pace and intensity cue"]
            ]
          }
        ]
        """
    }

    private func parseAIProgram(_ content: String, goal: String) throws -> WorkoutProgram {
        // Extract JSON array from response
        guard let jsonStart = content.firstIndex(of: "["),
              let jsonEnd = content.lastIndex(of: "]") else {
            throw WorkoutError.parseFailed
        }
        let jsonString = String(content[jsonStart...jsonEnd])
        let jsonData = Data(jsonString.utf8)

        let rawDays = try JSONDecoder().decode([[String: Any_JSON]].self, from: jsonData)
        var days: [WorkoutDay] = []

        for (i, rawDay) in rawDays.enumerated() {
            let dayLabel = rawDay["day"]?.stringValue ?? "Day \(String(format: "%02d", i + 1))"
            let focus = rawDay["focus"]?.stringValue ?? "Training"
            let rawExercises = rawDay["exercises"]?.arrayValue ?? []

            var exercises: [WorkoutExercise] = []
            for rawEx in rawExercises {
                guard let arr = rawEx.arrayValue, arr.count >= 3 else { continue }
                let name = arr[0].stringValue ?? ""
                let setsReps = arr[1].stringValue ?? ""
                let cue = arr[2].stringValue ?? ""
                let isWarmup = name.lowercased().contains("warmup") || name.lowercased().contains("warm-up") || name.lowercased().contains("warm up")
                let isCardio = !isWarmup && (setsReps.contains("min") || name.lowercased().contains("treadmill") || name.lowercased().contains("bike") || name.lowercased().contains("rowing") || name.lowercased().contains("stairmaster"))

                var setLogs: [SetLog] = []
                if !isWarmup && !isCardio {
                    let pattern = /(\d+)\s*[×x]\s*(\d+)/
                    if let match = setsReps.firstMatch(of: pattern),
                       let setCount = Int(match.1),
                       let repCount = Int(match.2) {
                        setLogs = (0..<setCount).map { _ in SetLog(reps: repCount) }
                    }
                }

                exercises.append(WorkoutExercise(
                    id: UUID(),
                    name: name,
                    setsReps: setsReps,
                    cue: cue,
                    isWarmup: isWarmup,
                    isCardio: isCardio,
                    sets: setLogs
                ))
            }

            days.append(WorkoutDay(
                id: dayLabel.lowercased().replacingOccurrences(of: " ", with: "_"),
                dayNumber: i + 1,
                focus: focus,
                exercises: exercises
            ))
        }

        return WorkoutProgram(days: days, generatedAt: Date(), goal: goal)
    }

    // MARK: - Specialized Programs

    func kettlebellHIITProgram() -> WorkoutProgram {
        let templates: [[String: Any]] = [
            ["day": "Day 01", "focus": "Full Body Power", "exercises": [
                ["Dynamic Warmup", "10 min", "Prepare the body for training"],
                ["Kettlebell Swing", "5 × 15", "Hinge hard, snap the hips, arms are ropes. Bell to chest height."],
                ["Goblet Squat", "4 × 12", "Hold bell at chest, elbows inside knees, sit deep, drive up through heels."],
                ["Kettlebell Clean & Press", "4 × 8 each", "Clean to rack, press overhead, control down. Alternate arms."],
                ["Kettlebell Row", "4 × 10 each", "Hinge, pull to hip, squeeze the back. No rotation."],
                ["Turkish Get-Up", "3 × 3 each", "Slow and controlled. Every position is a checkpoint. Master the pattern."],
                ["HIIT Finisher: Swing Intervals", "8 min", "30 seconds max effort swings, 30 seconds rest. 8 rounds."]
            ]],
            ["day": "Day 02", "focus": "Core & Conditioning", "exercises": [
                ["Dynamic Warmup", "10 min", "Prepare the body for training"],
                ["Kettlebell Windmill", "3 × 6 each", "Slow rotation, eyes on the bell, deep hip hinge. This is mobility + strength."],
                ["Kettlebell Dead Bug Pull-Over", "3 × 10", "Back flat on floor, extend opposite arm and leg while holding bell overhead."],
                ["Kettlebell Halo", "3 × 8 each direction", "Circle the bell around your head. Tight core, smooth path."],
                ["Kettlebell Renegade Row", "4 × 8 each", "Plank position, row one bell at a time. No hip rotation. Core locked."],
                ["Kettlebell Figure 8", "3 × 12", "Pass the bell between legs in a figure 8. Low stance, fluid movement."],
                ["HIIT Finisher: Tabata Complex", "8 min", "20 sec goblet squat, 10 rest. 20 sec swing, 10 rest. 8 rounds."]
            ]],
            ["day": "Day 03", "focus": "Lower Body & Posterior Chain", "exercises": [
                ["Dynamic Warmup", "10 min", "Prepare the body for training"],
                ["Kettlebell Sumo Deadlift", "5 × 8", "Wide stance, toes out, grip the bell between legs. Drive through the floor."],
                ["Kettlebell Front Rack Squat", "4 × 10 each", "Bell in rack position, squat deep. Core braced, elbow tight."],
                ["Kettlebell Single-Leg Deadlift", "3 × 10 each", "Hinge on one leg, bell in opposite hand. Balance + hamstring."],
                ["Kettlebell Lateral Lunge", "3 × 8 each", "Step wide, sit into the hip, bell at chest. Push back to center."],
                ["Kettlebell Swing to Squat", "4 × 10", "Swing the bell up, catch in goblet position, squat, swing back down."],
                ["HIIT Finisher: EMOM Swings", "10 min", "Every minute on the minute: 15 heavy swings. Rest the remainder."]
            ]],
            ["day": "Day 04", "focus": "Upper Body & Power", "exercises": [
                ["Dynamic Warmup", "10 min", "Prepare the body for training"],
                ["Kettlebell Floor Press", "4 × 10 each", "Lie on floor, press from the bottom. Full stop at the floor each rep."],
                ["Kettlebell Push-Up to Row", "4 × 8 each", "Push-up on bells, row at the top. Plank stays tight."],
                ["Kettlebell Snatch", "4 × 6 each", "One fluid motion from floor to overhead. The king of kettlebell movements."],
                ["Kettlebell High Pull", "3 × 10 each", "Pull the bell to chin height, elbow high. Control the descent."],
                ["Kettlebell Overhead Carry", "3 × 40 steps each", "Bell locked out overhead, walk. Shoulder stability and core endurance."],
                ["HIIT Finisher: Death By Burpee + Swing", "6 min", "Minute 1: 1 burpee + 1 swing. Minute 2: 2+2. Keep adding until you can't."]
            ]]
        ]

        let days = buildDaysFromTemplates(templates)
        return WorkoutProgram(days: days, generatedAt: Date(), goal: "Kettlebell HIIT — Full Body Core")
    }

    // MARK: - Template Builder

    private func buildDaysFromTemplates(_ templates: [[String: Any]]) -> [WorkoutDay] {
        return templates.enumerated().map { i, t -> WorkoutDay in
            let focus = t["focus"] as? String ?? "Training"
            let rawExercises = t["exercises"] as? [[String]] ?? []
            let exercises = rawExercises.map { arr -> WorkoutExercise in
                let name = arr[0]
                let setsReps = arr[1]
                let cue = arr[2]
                let isWarmup = name.lowercased().contains("warmup")
                let isCardio = !isWarmup && (setsReps.contains("min") || name.lowercased().contains("hiit") || name.lowercased().contains("finisher"))
                var setLogs: [SetLog] = []
                if !isWarmup && !isCardio {
                    if let match = setsReps.firstMatch(of: /(\d+)\s*[×x]\s*(\d+)/),
                       let sc = Int(match.1), let rc = Int(match.2) {
                        setLogs = (0..<sc).map { _ in SetLog(reps: rc) }
                    }
                }
                return WorkoutExercise(id: UUID(), name: name, setsReps: setsReps, cue: cue, isWarmup: isWarmup, isCardio: isCardio, sets: setLogs)
            }
            return WorkoutDay(id: "day_\(String(format: "%02d", i + 1))", dayNumber: i + 1, focus: focus, exercises: exercises)
        }
    }

    // MARK: - Fallback Templates

    func fallbackProgram(goal: String) -> WorkoutProgram {
        let templates: [[String: Any]] = [
            ["day": "Day 01", "focus": "Chest & Triceps", "exercises": [
                ["Dynamic Warmup", "10 min", "Prepare the body for training"],
                ["Flat Barbell Bench Press", "5 × 5", "Grip slightly wider than shoulders, lower bar to mid-chest, press explosively"],
                ["Incline Dumbbell Press", "4 × 10", "Bench at 30 degrees, press dumbbells from chest to full lockout"],
                ["Cable Chest Fly", "3 × 15", "Cables set high, step forward, bring handles together at chest height"],
                ["Lying EZ-Bar Skull Crusher", "4 × 10", "Lower bar to forehead by bending elbows, extend arms to lockout"],
                ["Cable Tricep Pushdown", "3 × 15", "Rope or bar attachment, press down keeping elbows pinned at sides"],
                ["Treadmill Incline Walk", "15-20 min", "3.5 mph, 10-12% incline, steady pace"]
            ]],
            ["day": "Day 02", "focus": "Back & Biceps", "exercises": [
                ["Dynamic Warmup", "10 min", "Prepare the body for training"],
                ["Barbell Bent-Over Row", "5 × 5", "Hinge at hips, pull bar to lower chest, squeeze shoulder blades"],
                ["Lat Pulldown", "4 × 10", "Wide grip, pull to upper chest, control the negative"],
                ["Seated Cable Row", "3 × 12", "Pull to waist, keep chest tall, squeeze at peak"],
                ["Barbell Curl", "4 × 10", "Strict form, no swinging, squeeze at the top"],
                ["Hammer Curl", "3 × 12", "Neutral grip, control the eccentric"],
                ["Rowing Machine", "15 min", "Steady state, 24-28 strokes per minute"]
            ]],
            ["day": "Day 03", "focus": "Legs & Core", "exercises": [
                ["Dynamic Warmup", "10 min", "Prepare the body for training"],
                ["Barbell Back Squat", "5 × 5", "Break at hips and knees together, depth to parallel or below"],
                ["Romanian Deadlift", "4 × 10", "Hinge at hips, bar close to legs, feel the hamstring stretch"],
                ["Leg Press", "3 × 12", "Feet shoulder-width, full range of motion"],
                ["Walking Lunges", "3 × 12 each", "Step forward, knee tracks over toe, drive through front heel"],
                ["Hanging Leg Raise", "3 × 15", "Control the swing, curl pelvis up at the top"],
                ["Stairmaster", "15 min", "Level 6-8, steady rhythm"]
            ]],
            ["day": "Day 04", "focus": "Shoulders & Arms", "exercises": [
                ["Dynamic Warmup", "10 min", "Prepare the body for training"],
                ["Overhead Barbell Press", "5 × 5", "Brace core, press straight up, lock out overhead"],
                ["Dumbbell Lateral Raise", "4 × 12", "Slight bend in elbows, raise to shoulder height"],
                ["Face Pull", "3 × 15", "Rope at face height, pull apart and squeeze rear delts"],
                ["Dumbbell Curl", "3 × 12", "Alternate arms, full range of motion"],
                ["Overhead Tricep Extension", "3 × 12", "Dumbbell behind head, extend fully, control the descent"],
                ["Cycling", "15-20 min", "Moderate resistance, 80-90 RPM"]
            ]]
        ]

        return WorkoutProgram(days: buildDaysFromTemplates(templates), generatedAt: Date(), goal: goal)
    }

    // MARK: - Set Logging

    func logSet(dayIndex: Int, exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int) {
        guard var program = program,
              program.days.indices.contains(dayIndex),
              program.days[dayIndex].exercises.indices.contains(exerciseIndex),
              program.days[dayIndex].exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }

        program.days[dayIndex].exercises[exerciseIndex].sets[setIndex].weight = weight
        program.days[dayIndex].exercises[exerciseIndex].sets[setIndex].reps = reps
        program.days[dayIndex].exercises[exerciseIndex].sets[setIndex].completed = true
        self.program = program
        saveProgram()

        // Check for PR
        let exName = program.days[dayIndex].exercises[exerciseIndex].name
        updatePR(exerciseName: exName, weight: weight, reps: reps)
    }

    private func updatePR(exerciseName: String, weight: Double, reps: Int) {
        let key = exerciseName.lowercased()
        if let existing = personalRecords[key] {
            if weight > existing.bestWeight || (weight == existing.bestWeight && reps > existing.bestReps) {
                personalRecords[key] = PersonalRecord(exerciseName: exerciseName, bestWeight: weight, bestReps: reps, achievedAt: Date())
                savePRs()
            }
        } else {
            personalRecords[key] = PersonalRecord(exerciseName: exerciseName, bestWeight: weight, bestReps: reps, achievedAt: Date())
            savePRs()
        }
    }

    func pr(for exerciseName: String) -> PersonalRecord? {
        personalRecords[exerciseName.lowercased()]
    }

    // MARK: - Persistence

    private func saveProgram() {
        if let data = try? JSONEncoder().encode(program) {
            UserDefaults.standard.set(data, forKey: programKey)
        }
    }

    private func loadProgram() {
        guard let data = UserDefaults.standard.data(forKey: programKey),
              let saved = try? JSONDecoder().decode(WorkoutProgram.self, from: data) else { return }
        program = saved
    }

    private func savePRs() {
        if let data = try? JSONEncoder().encode(personalRecords) {
            UserDefaults.standard.set(data, forKey: prKey)
        }
    }

    private func loadPRs() {
        guard let data = UserDefaults.standard.data(forKey: prKey),
              let saved = try? JSONDecoder().decode([String: PersonalRecord].self, from: data) else { return }
        personalRecords = saved
    }

    func resetProgram() {
        program = nil
        UserDefaults.standard.removeObject(forKey: programKey)
    }

    // MARK: - Types

    enum WorkoutError: LocalizedError {
        case invalidURL, generationFailed, parseFailed
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL"
            case .generationFailed: return "Program generation failed"
            case .parseFailed: return "Could not parse AI response"
            }
        }
    }

    private struct AIResponse: Codable {
        let choices: [Choice]?
        struct Choice: Codable {
            let message: Message?
        }
        struct Message: Codable {
            let content: String?
        }
    }
}

// Simple JSON type for parsing mixed arrays
enum Any_JSON: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([Any_JSON])
    case dict([String: Any_JSON])
    case null

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
    var arrayValue: [Any_JSON]? {
        if case .array(let a) = self { return a }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { self = .string(s) }
        else if let i = try? container.decode(Int.self) { self = .int(i) }
        else if let d = try? container.decode(Double.self) { self = .double(d) }
        else if let b = try? container.decode(Bool.self) { self = .bool(b) }
        else if let a = try? container.decode([Any_JSON].self) { self = .array(a) }
        else if let d = try? container.decode([String: Any_JSON].self) { self = .dict(d) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .array(let a): try container.encode(a)
        case .dict(let d): try container.encode(d)
        case .null: try container.encodeNil()
        }
    }
}
