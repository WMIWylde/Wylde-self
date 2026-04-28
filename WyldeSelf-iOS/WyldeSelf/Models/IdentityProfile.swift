import Foundation

// ════════════════════════════════════════════════════════════════════
//  IdentityProfile — the structured output of Identity Import.
//  Mirrors the user_identity_profile Supabase table + the JSON shape
//  returned by /api/identity-analyze.
//
//  Used to tune every AI surface (Coach voice, daily messages, push
//  notifications, future-self language) so the app feels written for
//  this specific person.
// ════════════════════════════════════════════════════════════════════

struct IdentityProfile: Codable, Equatable {
    let identityArchetype: String
    let confidenceLevel: String          // "low" | "medium" | "high"
    let communicationTone: String
    let motivationTriggers: [String]
    let limitingPatterns: [String]
    let aspirationalIdentity: String
    let coachingStyle: String            // "direct"|"intense"|"supportive"|"spiritual"|"tactical"|"mixed"
    let languageToUse: [String]
    let languageToAvoid: [String]
    let emotionalDrivers: [String]
    let disciplineLevel: String          // "emerging"|"building"|"strong"|"elite"

    enum CodingKeys: String, CodingKey {
        case identityArchetype    = "identity_archetype"
        case confidenceLevel      = "confidence_level"
        case communicationTone    = "communication_tone"
        case motivationTriggers   = "motivation_triggers"
        case limitingPatterns     = "limiting_patterns"
        case aspirationalIdentity = "aspirational_identity"
        case coachingStyle        = "coaching_style"
        case languageToUse        = "language_to_use"
        case languageToAvoid      = "language_to_avoid"
        case emotionalDrivers     = "emotional_drivers"
        case disciplineLevel      = "discipline_level"
    }

    /// Friendly display label for coaching style — "Direct, tactical" etc.
    var coachingStyleLabel: String {
        switch coachingStyle {
        case "direct":     return "Direct, tactical"
        case "intense":    return "Intense, no-nonsense"
        case "supportive": return "Supportive, grounded"
        case "spiritual":  return "Reflective, identity-driven"
        case "tactical":   return "Tactical, numbers-first"
        case "mixed":      return "Mixed, adaptive"
        default:           return "Adaptive"
        }
    }

    static let placeholder = IdentityProfile(
        identityArchetype: "the disciplined builder",
        confidenceLevel: "high",
        communicationTone: "Direct. Visual. Occasionally vulnerable.",
        motivationTriggers: ["Proving wrong people who doubted them", "Visible compounding", "Quiet follow-through"],
        limitingPatterns: ["Over-planning", "Avoiding rest"],
        aspirationalIdentity: "the man who builds without needing applause",
        coachingStyle: "direct",
        languageToUse: ["build", "compound", "show up", "the work"],
        languageToAvoid: ["journey", "vibes", "manifest", "energy"],
        emotionalDrivers: ["agency", "pride", "frustration"],
        disciplineLevel: "strong"
    )
}
