import SwiftUI

// ════════════════════════════════════════════════════════════════════
//  ImageLibrary — bundled photo asset registry.
//
//  Names map to image set names in Assets.xcassets. If an image isn't
//  present yet, the view falls back to a tinted gradient so the layout
//  doesn't break during development. Drop matching @1x/@2x/@3x photos
//  into Assets.xcassets to light them up.
//
//  See IMAGES.md (at WyldeSelf-iOS root) for the photo spec — sizes,
//  treatment, naming conventions, and reference brand visuals.
// ════════════════════════════════════════════════════════════════════

enum WyldeImage: String, CaseIterable {
    // Today — rotating hero, varies by time of day + phase
    case todayMorning   = "today-morning"     // dawn light, ritual energy
    case todayMidday    = "today-midday"      // movement, sun
    case todayEvening   = "today-evening"     // wind-down, dusk
    case todayNight     = "today-night"       // candle, quiet close

    // Future — hero behind the "see your future self" framing
    case futureHero     = "future-hero"
    case futurePlaceholder = "future-placeholder"  // before the user's generated image arrives

    // Library — category headers
    case libraryStrength   = "library-strength"
    case libraryMobility   = "library-mobility"
    case libraryConditioning = "library-conditioning"
    case libraryRecovery   = "library-recovery"

    // You — profile and identity context
    case youHero        = "you-hero"           // calm portrait / landscape
    case identityAnchor = "identity-anchor"    // ritual / focus
    case careTeamHero   = "care-team-hero"     // clinical, hands at a desk

    // Onboarding / sign-in
    case signInHero     = "sign-in-hero"
    case onboardingHero = "onboarding-hero"

    // Empty states
    case emptyStateCalm = "empty-state-calm"
}

extension Image {
    /// Render a Wylde image. If the asset isn't in the catalog yet, fall
    /// back to a calm gradient tinted to the scene so screens don't go
    /// gray during development.
    static func wylde(_ image: WyldeImage) -> some View {
        if UIImage(named: image.rawValue) != nil {
            return AnyView(
                Image(image.rawValue)
                    .resizable()
            )
        } else {
            return AnyView(
                LinearGradient(
                    colors: image.fallbackColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Text("photo: \(image.rawValue)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                        .padding(8)
                        .background(.black.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 4)),
                    alignment: .bottomLeading
                )
            )
        }
    }
}

private extension WyldeImage {
    /// Fallback gradient palette per scene — soft tints in the warm
    /// brand neighborhood so the placeholder isn't visually jarring.
    var fallbackColors: [Color] {
        switch self {
        case .todayMorning:   return [WyldeStyles.Colors.bone, WyldeStyles.Colors.gold.opacity(0.45)]
        case .todayMidday:    return [WyldeStyles.Colors.sand, WyldeStyles.Colors.sage.opacity(0.35)]
        case .todayEvening:   return [WyldeStyles.Colors.bronze.opacity(0.35), WyldeStyles.Colors.charcoal.opacity(0.55)]
        case .todayNight:     return [WyldeStyles.Colors.charcoal, WyldeStyles.Colors.ink]
        case .futureHero, .futurePlaceholder:
            return [WyldeStyles.Colors.bone, WyldeStyles.Colors.bronze.opacity(0.40)]
        case .libraryStrength:    return [WyldeStyles.Colors.bone, WyldeStyles.Colors.charcoal.opacity(0.20)]
        case .libraryMobility:    return [WyldeStyles.Colors.bone, WyldeStyles.Colors.sage.opacity(0.30)]
        case .libraryConditioning:return [WyldeStyles.Colors.sand, WyldeStyles.Colors.gold.opacity(0.30)]
        case .libraryRecovery:    return [WyldeStyles.Colors.bone, WyldeStyles.Colors.sage.opacity(0.20)]
        case .youHero, .identityAnchor:
            return [WyldeStyles.Colors.bone, WyldeStyles.Colors.sand.opacity(0.6)]
        case .careTeamHero:
            return [WyldeStyles.Colors.bone, WyldeStyles.Colors.sage.opacity(0.30)]
        case .signInHero, .onboardingHero:
            return [WyldeStyles.Colors.bone, WyldeStyles.Colors.bronze.opacity(0.45)]
        case .emptyStateCalm:
            return [WyldeStyles.Colors.bone, WyldeStyles.Colors.paper]
        }
    }
}

/// Pick the Today hero based on local hour. Cheap, deterministic.
enum TodayHero {
    static var current: WyldeImage {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return .todayMorning
        case 11..<17: return .todayMidday
        case 17..<21: return .todayEvening
        default:      return .todayNight
        }
    }
}
