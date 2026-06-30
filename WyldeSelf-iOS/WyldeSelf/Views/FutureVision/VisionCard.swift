import SwiftUI

struct VisionCard: View {
    let vision: FutureVision
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    // Hero image
                    if let base64 = vision.imageBase64,
                       let data = Data(base64Encoded: base64.replacingOccurrences(of: "data:image/png;base64,", with: "").replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        // Placeholder gradient
                        LinearGradient(
                            colors: [VisionTheme.surfaceElevated, VisionTheme.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay(
                            Image(systemName: vision.categoryInfo?.icon ?? "sparkles")
                                .font(.system(size: 40))
                                .foregroundColor(VisionTheme.textFaint)
                        )
                    }

                    // Bottom gradient overlay
                    VisionTheme.cardGradient

                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        // Timeline badge
                        if let horizon = vision.timelineHorizon {
                            Text(horizonLabel(horizon))
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1.5)
                                .foregroundColor(VisionTheme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(VisionTheme.glassFill)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(VisionTheme.borderActive, lineWidth: 0.5))
                        }

                        // Category label
                        Text((vision.categoryInfo?.name ?? vision.category).uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2.5)
                            .foregroundColor(VisionTheme.accent)

                        // Identity statement
                        if let statement = vision.identityStatement {
                            Text("\u{201C}\(statement)\u{201D}")
                                .font(.system(size: 20, weight: .regular, design: .serif))
                                .foregroundColor(VisionTheme.text)
                                .lineSpacing(4)
                        }

                        // Why it matters
                        if let why = vision.whyItMatters {
                            Text(why)
                                .font(.system(size: 13))
                                .foregroundColor(VisionTheme.textMuted)
                                .lineSpacing(2)
                        }
                    }
                    .padding(24)
                }
            }
            .aspectRatio(VisionTheme.cardAspect, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: VisionTheme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private func horizonLabel(_ h: String) -> String {
        switch h {
        case "1year": return "1 YEAR"
        case "3year": return "3 YEAR"
        case "5year": return "5 YEAR"
        case "10year": return "10 YEAR"
        default: return h.uppercased()
        }
    }
}
