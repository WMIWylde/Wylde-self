import SwiftUI

/// Central design tokens for WyldeSelf iOS.
/// Source of truth: DESIGN.md
enum WyldeStyles {

    enum Colors {
        // Foundation
        static let paper = Color(hex: "F4F1EC")
        static let bone = Color(hex: "E8E2D6")
        static let sand = Color(hex: "D4C9B5")
        static let stone = Color(hex: "9A9286")
        static let charcoal = Color(hex: "2C2A26")
        static let ink = Color(hex: "1A1816")

        // Accent
        static let bronze = Color(hex: "9C7A4A")
        static let gold = Color(hex: "C9A84C")
        static let sage = Color(hex: "7A8771")
        static let clay = Color(hex: "A06B4F")

        // Semantic
        static let success = sage
        static let warning = clay
        static let error = Color(hex: "8B3A2F")
    }

    /// Layout primitives from DESIGN.md (sizes not on the spacing scale).
    enum Layout {
        /// Component spec: lg corner radius = 16pt.
        static let cardCornerRadius: CGFloat = 16
    }

    enum Typography {
        enum Display {
            /// Editorial serif until bundled Cormorant Garamond ships (see DESIGN.md typography).
            static let hero = Font.system(size: 48, weight: .regular, design: .serif)
            static let large = Font.system(size: 36, weight: .medium)
            static let medium = Font.system(size: 28, weight: .medium)
        }

        enum Body {
            static let large = Font.system(size: 18, weight: .regular)
            static let medium = Font.system(size: 16, weight: .regular)
            static let small = Font.system(size: 14, weight: .regular)
        }

        enum Label {
            static let large = Font.system(size: 14, weight: .semibold)
            static let small = Font.system(size: 11, weight: .semibold)
            static let largeTracking: CGFloat = 0.05
            static let smallTracking: CGFloat = 0.1
        }

        enum Numeric {
            static let large = Font.system(size: 32, weight: .regular, design: .monospaced)
            static let medium = Font.system(size: 18, weight: .regular, design: .monospaced)
        }
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 40
        static let x2l: CGFloat = 64
        static let x3l: CGFloat = 96
    }
}

extension Font {
    static let wyldeDisplayHero = WyldeStyles.Typography.Display.hero
    static let wyldeDisplayLarge = WyldeStyles.Typography.Display.large
    static let wyldeDisplayMedium = WyldeStyles.Typography.Display.medium

    static let wyldeBodyLarge = WyldeStyles.Typography.Body.large
    static let wyldeBodyMedium = WyldeStyles.Typography.Body.medium
    static let wyldeBodySmall = WyldeStyles.Typography.Body.small

    static let wyldeLabelLarge = WyldeStyles.Typography.Label.large
    static let wyldeLabelSmall = WyldeStyles.Typography.Label.small

    static let wyldeNumericLarge = WyldeStyles.Typography.Numeric.large
    static let wyldeNumericMedium = WyldeStyles.Typography.Numeric.medium
}

extension Color {
    static let wyldePaper = WyldeStyles.Colors.paper
    static let wyldeBone = WyldeStyles.Colors.bone
    static let wyldeSand = WyldeStyles.Colors.sand
    static let wyldeStone = WyldeStyles.Colors.stone
    static let wyldeCharcoal = WyldeStyles.Colors.charcoal
    static let wyldeInk = WyldeStyles.Colors.ink
    static let wyldeBronze = WyldeStyles.Colors.bronze
    static let wyldeGold = WyldeStyles.Colors.gold
    static let wyldeSage = WyldeStyles.Colors.sage
    static let wyldeClay = WyldeStyles.Colors.clay
    static let wyldeSuccess = WyldeStyles.Colors.success
    static let wyldeWarning = WyldeStyles.Colors.warning
    static let wyldeError = WyldeStyles.Colors.error
}
