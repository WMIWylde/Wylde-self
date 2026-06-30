import SwiftUI

/// Dark cinematic color tokens for the Future Vision feature.
/// Scoped to vision views only — the app remains light-mode elsewhere.
/// Follows the IdentityImportView pattern of explicit hex colors.
enum VisionTheme {
    // Surfaces
    static let background = Color(hex: "070707")
    static let surface = Color(hex: "111111")
    static let surfaceElevated = Color(hex: "1A1A1A")
    static let surfaceCard = Color(hex: "141414")

    // Text
    static let text = Color(hex: "F4F1E8")
    static let textMuted = Color(hex: "A6A29A")
    static let textFaint = Color(hex: "6B6760")

    // Accents
    static let accent = Color(hex: "C8A96E")
    static let bronze = Color(hex: "9C7A4A")
    static let sage = Color(hex: "7A8771")
    static let gold = Color(hex: "C9A84C")

    // Borders & Glass
    static let border = Color(hex: "F4F1E8").opacity(0.06)
    static let borderActive = Color(hex: "C8A96E").opacity(0.3)
    static let glassFill = Color.white.opacity(0.04)

    // Gradients
    static let cardGradient = LinearGradient(
        colors: [.clear, Color.black.opacity(0.7), Color.black.opacity(0.85)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let heroFade = LinearGradient(
        colors: [Color(hex: "070707").opacity(0), Color(hex: "070707")],
        startPoint: .center,
        endPoint: .bottom
    )

    // Layout
    static let cardRadius: CGFloat = 20
    static let cardAspect: CGFloat = 4.0 / 5.0
}
