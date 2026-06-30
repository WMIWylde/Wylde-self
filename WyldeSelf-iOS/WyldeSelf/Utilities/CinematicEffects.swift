import SwiftUI

// ════════════════════════════════════════════════════════════════════
//  CinematicEffects — reusable visual depth components matching
//  the web app's atmospheric design language.
// ════════════════════════════════════════════════════════════════════

// MARK: - Ambient Background

/// Full-screen dark background with animated radial glow blobs.
/// Matches the web app's radial-gradient + drifting blur layers.
struct AmbientBackground: View {
    var glowColor: Color = Color(hex: "D4A574")
    var secondaryGlow: Color = Color(hex: "B85540")
    var baseColors: (top: Color, mid: Color, bottom: Color) = (
        Color(hex: "070707"),
        Color(hex: "070707"),
        Color(hex: "070707")
    )

    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [baseColors.top, baseColors.mid, baseColors.bottom],
                startPoint: .top,
                endPoint: .bottom
            )

            // Primary glow blob — top right
            Circle()
                .fill(glowColor)
                .frame(width: 420, height: 420)
                .blur(radius: 110)
                .opacity(0.15)
                .offset(
                    x: 120 + sin(phase) * 20,
                    y: -200 + cos(phase * 0.7) * 15
                )

            // Secondary glow blob — bottom left
            Circle()
                .fill(secondaryGlow)
                .frame(width: 360, height: 360)
                .blur(radius: 110)
                .opacity(0.10)
                .offset(
                    x: -100 - sin(phase * 0.8) * 15,
                    y: 200 + cos(phase) * 10
                )
        }
        .frame(maxWidth: UIScreen.main.bounds.width)
        .clipped()
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 24).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}

/// Variant for the Future Self screen — sage/forest tones
struct ForestAmbientBackground: View {
    var body: some View {
        AmbientBackground(
            glowColor: Color(hex: "7A8771"),
            secondaryGlow: Color(hex: "C9A86A"),
            baseColors: (
                Color(hex: "0E130E"),
                Color(hex: "222A20"),
                Color(hex: "0E130E")
            )
        )
    }
}

// MARK: - Cinematic Hero Card

/// Large hero card with gradient overlays matching the web's .ov-hero
struct CinematicHeroCard<Content: View>: View {
    var height: CGFloat = 380
    var cornerRadius: CGFloat = 28
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Dark forest base
            LinearGradient(
                colors: [Color(hex: "20241C"), Color(hex: "1A1E16")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Radial glow — top right
            RadialGradient(
                colors: [Color(hex: "C9A86A").opacity(0.12), .clear],
                center: .init(x: 0.85, y: 0.1),
                startRadius: 0,
                endRadius: 200
            )

            // Bottom fade for text readability
            LinearGradient(
                colors: [.clear, Color(hex: "20241C").opacity(0.5), Color(hex: "20241C").opacity(0.85)],
                startPoint: .init(x: 0.5, y: 0.3),
                endPoint: .bottom
            )

            // Content
            content()
                .padding(24)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Glass Card

/// Glassmorphism card with backdrop blur effect.
/// Matches web's .ob-step-sage pattern.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var borderColor: Color = Color(hex: "D4A574").opacity(0.20)
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "1F1814").opacity(0.85),
                                        Color(hex: "16110F").opacity(0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Gold Gradient Button

/// Primary CTA button with gold gradient matching web's .ob-next
struct GoldButton: View {
    let label: String
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "1A1816"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "E6C886"), Color(hex: "A6834A")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
    }
}

// MARK: - Radial Glow Overlay

/// Subtle radial glow for cards and sections — matches web's ::before pseudo-elements
struct RadialGlowOverlay: View {
    var color: Color = Color(hex: "D4A574")
    var opacity: Double = 0.15
    var position: UnitPoint = .init(x: 0.8, y: 0.0)
    var radius: CGFloat = 200

    var body: some View {
        RadialGradient(
            colors: [color.opacity(opacity), .clear],
            center: position,
            startRadius: 0,
            endRadius: radius
        )
        .allowsHitTesting(false)
    }
}

// MARK: - Glowing Progress Bar

/// Progress bar with glow effect matching web's .ob-progress-bar-fill
struct GlowingProgressBar: View {
    var progress: CGFloat  // 0.0 to 1.0
    var color: Color = Color(hex: "D4BE92")

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 3)

                // Fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * min(progress, 1), height: 3)
                    .shadow(color: color.opacity(0.4), radius: 6, x: 0, y: 0)
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Blur Tab Bar Background

/// Matches web nav: rgba(11,11,11,0.94) + blur(24px)
struct BlurredTabBarBackground: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Color(hex: "0B0B0B").opacity(0.88)
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 0.5)
            }
    }
}
