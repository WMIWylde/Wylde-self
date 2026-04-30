import Foundation

/// Centralized one-sentence coach voice for the iOS app. Mirrors the
/// `coachLine()` helper in app.html so the native and web surfaces speak
/// with the same calm, grounded tone — never hype, never shame, never
/// more than one short sentence.
///
/// Usage:
///   CoachLine.get(.ritualDone)
///   CoachLine.get(.mealLogged, protein: 95, proteinGoal: 180)
enum CoachContext: String {
    case mealLogged
    case mealLowProtein
    case mealOnTrack
    case workoutDone
    case ritualDone
    case closeout
    case missed
    case generic
}

enum CoachLine {

    // MARK: - Pools (kept in sync with app.html)
    private static let pools: [CoachContext: [String]] = [
        .mealLogged: [
            "Solid. Keep it simple from here.",
            "Logged. That counts.",
            "One more aligned choice."
        ],
        .mealLowProtein: [
            "You\u{2019}re low on protein. Make the next meal protein-forward.",
            "Protein\u{2019}s lagging — anchor the next plate around it.",
            "Next meal: lead with protein."
        ],
        .mealOnTrack: [
            "On track for protein today.",
            "Protein is landing. Stay with it.",
            "Macros are tracking. Keep going."
        ],
        .workoutDone: [
            "You showed up. That was the hard part.",
            "Work logged. Recovery starts now.",
            "One honest session in the bank."
        ],
        .ritualDone: [
            "Good. That\u{2019}s how the day starts.",
            "Standard set. The rest follows.",
            "You started clean. That counts."
        ],
        .closeout: [
            "You followed through today.",
            "Day closed. Momentum logged.",
            "You kept your word."
        ],
        .missed: [
            "Not perfect. Still progress.",
            "No shame. Re-enter the day.",
            "The next aligned choice is enough."
        ],
        .generic: [
            "Stay consistent.",
            "This compounds.",
            "One honest step."
        ]
    ]

    // Track last-used index per context so back-to-back calls don't repeat.
    // Stored on the type so rotation is consistent across the app session.
    private static var lastIndex: [CoachContext: Int] = [:]

    /// Returns one short sentence appropriate for the given context.
    /// When `mealLogged` is requested with daily protein context, the pool
    /// auto-swaps to `mealLowProtein` (<50% goal) or `mealOnTrack` (>=70%).
    static func get(_ context: CoachContext, protein: Int? = nil, proteinGoal: Int? = nil) -> String {
        var ctx = context
        if context == .mealLogged,
           let p = protein, let g = proteinGoal, g > 0 {
            let pct = Double(p) / Double(g)
            if pct < 0.5 { ctx = .mealLowProtein }
            else if pct >= 0.7 { ctx = .mealOnTrack }
        }
        guard let pool = pools[ctx], !pool.isEmpty else {
            return pools[.generic]?.randomElement() ?? "Stay consistent."
        }
        let idx: Int
        if let last = lastIndex[ctx], pool.count > 1 {
            idx = (last + 1) % pool.count
        } else {
            idx = Int.random(in: 0..<pool.count)
        }
        lastIndex[ctx] = idx
        return pool[idx]
    }
}
