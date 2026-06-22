import SwiftUI
import UIKit

/// App-wide visuals. Prefer `WyldeStyles` for raw tokens; existing screens use these aliases.
enum Theme {
    /// Paper / charcoal system from DESIGN.md (no pure black/white).
    static var background: Color { WyldeStyles.Colors.paper }
    static var surface: Color { WyldeStyles.Colors.paper }
    static var text: Color { WyldeStyles.Colors.ink }
    static var muted: Color { WyldeStyles.Colors.stone }
    static var text3: Color { WyldeStyles.Colors.charcoal.opacity(0.55) }
    static var sage: Color { WyldeStyles.Colors.sage }
    /// Celebration / founder moments — use bronze for everyday primary accents in new UI.
    static var gold: Color { WyldeStyles.Colors.gold }
    static var bronze: Color { WyldeStyles.Colors.bronze }
    static var border: Color { WyldeStyles.Colors.charcoal.opacity(0.06) }

    /// Bundled fonts are not finalized; keep names for gradual migration off system fonts.
    static let displayFont = "Inter-Bold"
    static let bodyFont = "Inter-Regular"

    static var cardRadius: CGFloat { WyldeStyles.Layout.cardCornerRadius }
    static var cardPadding: CGFloat { WyldeStyles.Spacing.lg }
    static var screenPadding: CGFloat { WyldeStyles.Spacing.lg }

    // Card surface — adaptive white/dark
    static var cardSurface: Color {
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(wyldeHex: "111111")
                : UIColor(wyldeHex: "FFFFFF")
        })
    }

    /// For `UITabBarAppearance` / `UINavigationBarAppearance` alongside SwiftUI chrome.
    static var paperUIColor: UIColor {
        UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(wyldeHex: "0B0B0B")
                : UIColor(wyldeHex: "F4F1EC")
        }
    }
    static var hairlineShadowUIColor: UIColor {
        UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.04)
                : UIColor(white: 0, alpha: 0.06)
        }
    }
}

extension UIColor {
    convenience init(wyldeHex: String, alpha: CGFloat = 1) {
        let hex = wyldeHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 244, 241, 236)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255 * alpha
        )
    }
}

// Hex color extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
