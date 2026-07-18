import Foundation

// ════════════════════════════════════════════════════════════════════
//  ProgressionEngine — deterministic progressive overload (double
//  progression). Reads the most recent logged session for an exercise
//  and prescribes the next target weight:
//    • every set hit target reps  → +5lb (upper) / +10lb (lower compounds)
//    • badly missed (avg ≤ target-3) → deload 10%, rounded to 5lb
//    • otherwise → hold weight until all sets hit target
//  Falls back to the LiftingCoach baseline table when no history exists.
// ════════════════════════════════════════════════════════════════════

struct ProgressionTarget {
    enum Source { case history, baseline }
    let weight: Double
    let note: String
    let source: Source
}

enum ProgressionEngine {

    /// Lower-body compounds progress in 10lb jumps; everything else 5lb.
    static func increment(for exercise: String) -> Double {
        let lower = exercise.lowercased()
        let bigLifts = ["squat", "deadlift", "leg press", "hip thrust", "romanian", "rdl", "lunge", "trap bar"]
        return bigLifts.contains(where: { lower.contains($0) }) ? 10 : 5
    }

    static func target(
        exercise: WorkoutExercise,
        lastSession: [SetLog]?,
        gender: String,
        level: String
    ) -> ProgressionTarget {
        let targetReps = exercise.parsedReps
        let completed = (lastSession ?? []).filter { $0.completed && $0.weight > 0 }

        guard !completed.isEmpty, targetReps > 0 else {
            let base = LiftingCoach.suggestedWeight(exercise: exercise.name, gender: gender, level: level)
            return ProgressionTarget(weight: base.weight, note: base.note, source: .baseline)
        }

        let weight = completed.map(\.weight).max() ?? 0
        let allHit = completed.allSatisfy { $0.reps >= targetReps }
        let avgReps = Double(completed.map(\.reps).reduce(0, +)) / Double(completed.count)

        if allHit {
            let next = weight + increment(for: exercise.name)
            return ProgressionTarget(
                weight: next,
                note: "Every set hit \(targetReps) reps at \(Int(weight))lb last session. Move to \(Int(next))lb.",
                source: .history
            )
        }
        if avgReps <= Double(targetReps) - 3 {
            let next = max(((weight * 0.9) / 5).rounded() * 5, 0)
            return ProgressionTarget(
                weight: next,
                note: "Last session was a grind. Deload to \(Int(next))lb and build back with clean reps.",
                source: .history
            )
        }
        return ProgressionTarget(
            weight: weight,
            note: "Stay at \(Int(weight))lb until every set hits \(targetReps) reps.",
            source: .history
        )
    }
}
