import SwiftUI
import UIKit

/// Central design tokens for WyldeSelf iOS.
/// Adaptive: automatically switches between dark (web-matching) and light palettes.
enum WyldeStyles {

    /// Helper: creates a Color that adapts to dark/light mode.
    private static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(wyldeHex: dark)
                : UIColor(wyldeHex: light)
        })
    }

    enum Colors {
        // Foundation — dark matches web app (#070707 bg, #F4F1E8 text)
        static let paper    = adaptive(light: "F4F1EC", dark: "070707")
        static let bone     = adaptive(light: "E8E2D6", dark: "111111")
        static let sand     = adaptive(light: "D4C9B5", dark: "1A1A1A")
        static let stone    = adaptive(light: "665F53", dark: "A6A29A")
        static let charcoal = adaptive(light: "2C2A26", dark: "F4F1E8")
        static let ink      = adaptive(light: "1A1816", dark: "F4F1E8")

        // Accent — gold replaces sage as primary accent in dark mode (matches web)
        static let bronze = adaptive(light: "9C7A4A", dark: "C8A96E")
        static let gold   = adaptive(light: "C9A84C", dark: "C8A96E")
        static let sage   = adaptive(light: "7A8771", dark: "D4BE92")
        static let clay   = adaptive(light: "A06B4F", dark: "C26B5A")

        // Semantic
        static let success = sage
        static let warning = clay
        static let error = adaptive(light: "8B3A2F", dark: "C26B5A")
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
