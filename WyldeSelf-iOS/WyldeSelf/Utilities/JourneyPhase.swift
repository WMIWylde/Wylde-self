import Foundation

/// Maps day-in-program (1..84) to the four-phase identity-transformation
/// structure. Mirrors `getJourneyPhase()` in app.html. Used by the native
/// StartTodayFlow Identity Anchor step and any Today-screen surfaces that
/// want to label the user's current phase.
struct JourneyPhase {
    let name: String
    let focus: String
    let range: String

    static func forDay(_ day: Int) -> JourneyPhase {
        let d = max(1, day)
        if d <= 14 {
            return JourneyPhase(
                name: "Foundation",
                focus: "Consistency. Rhythm. Showing up.",
                range: "Days 1\u{2013}14"
            )
        }
        if d <= 42 {
            return JourneyPhase(
                name: "Build",
                focus: "Stronger habits. Better fuel. Progressive load.",
                range: "Days 15\u{2013}42"
            )
        }
        if d <= 70 {
            return JourneyPhase(
                name: "Embody",
                focus: "Identity integration. Confidence. Deeper consistency.",
                range: "Days 43\u{2013}70"
            )
        }
        return JourneyPhase(
            name: "Integrate",
            focus: "Maintenance. Reflection. The next plan.",
            range: "Days 71\u{2013}84"
        )
    }
}

/// Returns a calm, one-line headline that evolves with the user's week
/// in their 12-week journey. Mirrors `getFutureYouCopy()` in app.html.
enum FutureYouCopy {
    static func forWeek(_ week: Int) -> String {
        let w = max(1, week)
        if w <= 1  { return "This is the version you\u{2019}re beginning to build." }
        if w <= 3  { return "Early days. The pattern is forming." }
        if w <= 5  { return "You\u{2019}re starting to see it: consistency changes identity." }
        if w <= 7  { return "No longer guessing. You have evidence." }
        if w <= 10 { return "The work is becoming who you are." }
        return "This is what follow-through looks like."
    }

    /// Convenience: derive the user's current week from their day number.
    static func forDay(_ day: Int) -> String {
        let week = max(1, Int(ceil(Double(max(1, day)) / 7.0)))
        return forWeek(week)
    }
}
