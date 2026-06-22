import Foundation

struct WorkoutProgram: Codable {
    var days: [WorkoutDay]
    let generatedAt: Date
    let goal: String
}

struct WorkoutDay: Identifiable, Codable {
    let id: String
    let dayNumber: Int
    let focus: String
    var exercises: [WorkoutExercise]

    var completedSets: Int {
        exercises.flatMap(\.sets).filter(\.completed).count
    }
    var totalSets: Int {
        exercises.flatMap(\.sets).count
    }
    var isComplete: Bool {
        totalSets > 0 && completedSets == totalSets
    }
}

struct WorkoutExercise: Identifiable, Codable {
    let id: UUID
    let name: String
    let setsReps: String
    let cue: String
    let isWarmup: Bool
    let isCardio: Bool
    var sets: [SetLog]

    var parsedSetCount: Int {
        if isWarmup || isCardio { return 0 }
        let pattern = /(\d+)\s*[×x]\s*(\d+)/
        if let match = setsReps.firstMatch(of: pattern) {
            return Int(match.1) ?? 0
        }
        return 0
    }

    var parsedReps: Int {
        let pattern = /(\d+)\s*[×x]\s*(\d+)/
        if let match = setsReps.firstMatch(of: pattern) {
            return Int(match.2) ?? 0
        }
        return 0
    }

    var timerMinutes: Int {
        if let match = setsReps.firstMatch(of: /(\d+)\s*min/) {
            return Int(match.1) ?? 10
        }
        // Range: "15-20 min" → take upper bound
        if let match = setsReps.firstMatch(of: /(\d+)-(\d+)\s*min/) {
            return Int(match.2) ?? 15
        }
        if isWarmup { return 10 }
        if isCardio { return 15 }
        return 0
    }

    /// Whether this is a compound movement (longer rest time)
    var isCompound: Bool {
        let compoundKeywords = ["bench", "squat", "deadlift", "press", "row", "pull-up", "chin-up", "clean", "snatch"]
        let lower = name.lowercased()
        return compoundKeywords.contains { lower.contains($0) }
    }
}

struct SetLog: Identifiable, Codable {
    let id: UUID
    var reps: Int
    var weight: Double
    var completed: Bool

    init(reps: Int = 0, weight: Double = 0) {
        self.id = UUID()
        self.reps = reps
        self.weight = weight
        self.completed = false
    }
}

struct PersonalRecord: Codable {
    let exerciseName: String
    var bestWeight: Double
    var bestReps: Int
    let achievedAt: Date
}
