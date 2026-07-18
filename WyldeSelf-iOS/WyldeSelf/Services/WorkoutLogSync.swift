import Foundation
import Supabase

// ════════════════════════════════════════════════════════════════════
//  WorkoutLogSync — persists every logged set to Supabase
//  (workout_set_logs) and pulls recent history so ProgressionEngine
//  can prescribe next-session targets. History survives program
//  regeneration and reinstalls.
//
//  user_id is applied by a DB default (auth.uid()) — never sent.
// ════════════════════════════════════════════════════════════════════

@MainActor
final class WorkoutLogSync: ObservableObject {
    static let shared = WorkoutLogSync()
    private init() {}

    /// exercise name (lowercased) → completed sets from the most recent
    /// logged calendar day for that exercise.
    @Published private(set) var lastSessions: [String: [SetLog]] = [:]

    private var lastFetch: Date?

    private struct InsertRow: Encodable {
        let exercise_name: String
        let weight: Double
        let reps: Int
        let target_reps: Int
        let day_focus: String
    }

    private struct FetchRow: Decodable {
        let exercise_name: String
        let weight: Double
        let reps: Int
        let logged_at: String
    }

    // MARK: - Upload (fire-and-forget)

    func upload(exerciseName: String, weight: Double, reps: Int, targetReps: Int, dayFocus: String) {
        let row = InsertRow(
            exercise_name: exerciseName,
            weight: weight,
            reps: reps,
            target_reps: targetReps,
            day_focus: dayFocus
        )
        // Update in-memory history immediately so the next card render
        // reflects today's work even before a refetch.
        let key = exerciseName.lowercased()
        var sets = lastSessions[key] ?? []
        var log = SetLog(reps: reps, weight: weight)
        log.completed = true
        sets.append(log)
        lastSessions[key] = sets

        Task {
            do {
                try await SupabaseService.shared
                    .from("workout_set_logs")
                    .insert(row)
                    .execute()
            } catch {
                #if DEBUG
                print("[WorkoutLogSync] upload failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - History

    /// Fetch the last 90 days of logs (throttled to once per 5 minutes)
    /// and reduce to each exercise's most recent session.
    func refreshHistory(force: Bool = false) async {
        if !force, let last = lastFetch, Date().timeIntervalSince(last) < 300 { return }
        do {
            let cutoff = ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: -90 * 86400))
            let rows: [FetchRow] = try await SupabaseService.shared
                .from("workout_set_logs")
                .select("exercise_name, weight, reps, logged_at")
                .gte("logged_at", value: cutoff)
                .order("logged_at", ascending: false)
                .limit(1000)
                .execute()
                .value
            lastFetch = Date()

            // Most recent calendar day per exercise (rows arrive newest-first)
            var result: [String: [SetLog]] = [:]
            var sessionDay: [String: String] = [:]
            for row in rows {
                let key = row.exercise_name.lowercased()
                let day = String(row.logged_at.prefix(10))
                if let existingDay = sessionDay[key] {
                    guard existingDay == day else { continue }  // older session — skip
                } else {
                    sessionDay[key] = day
                }
                var log = SetLog(reps: row.reps, weight: row.weight)
                log.completed = true
                result[key, default: []].append(log)
            }
            lastSessions = result
            #if DEBUG
            print("[WorkoutLogSync] history: \(result.count) exercises")
            #endif
        } catch {
            #if DEBUG
            print("[WorkoutLogSync] fetch failed: \(error.localizedDescription)")
            #endif
        }
    }

    func lastSession(for exerciseName: String) -> [SetLog]? {
        lastSessions[exerciseName.lowercased()]
    }
}
