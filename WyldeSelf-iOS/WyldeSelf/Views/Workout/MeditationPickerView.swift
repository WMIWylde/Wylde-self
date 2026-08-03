import SwiftUI

/// Meditation selector — shows available guided meditations.
/// Tapping one opens GuidedMeditationView with that meditation's audio.
struct MeditationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMeditation: Meditation?

    var body: some View {
        ZStack {
            WyldeStyles.Colors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MEDITATION")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2.5)
                            .foregroundColor(WyldeStyles.Colors.bronze)
                        Text("Choose Your Practice")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundColor(WyldeStyles.Colors.ink)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(WyldeStyles.Colors.stone)
                            .frame(width: 36, height: 36)
                            .background(WyldeStyles.Colors.bone)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(Meditation.all) { meditation in
                            meditationCard(meditation)
                        }

                        // Facilitator credit
                        facilitatorCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .fullScreenCover(item: $selectedMeditation) { meditation in
            GuidedMeditationView(meditation: meditation)
        }
    }

    // MARK: - Card

    private func meditationCard(_ meditation: Meditation) -> some View {
        Button {
            HapticManager.shared.impact(.light)
            selectedMeditation = meditation
        } label: {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(meditation.accent.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: meditation.icon)
                        .font(.system(size: 22))
                        .foregroundColor(meditation.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(meditation.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(WyldeStyles.Colors.ink)
                    Text(meditation.subtitle)
                        .font(.system(size: 12.5))
                        .foregroundColor(WyldeStyles.Colors.stone)
                        .lineLimit(2)
                        .lineSpacing(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(meditation.durationLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(meditation.accent)
                    if let facilitator = meditation.facilitator {
                        Text(facilitator)
                            .font(.system(size: 10.5))
                            .foregroundColor(WyldeStyles.Colors.stone)
                    }
                }
            }
            .padding(16)
            .background(Theme.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(meditation.accent.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Facilitator Credit

    private var facilitatorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(WyldeStyles.Colors.bronze)
                Text("Meditations by Tommy Sobel")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(WyldeStyles.Colors.ink)
            }
            Text("Guided meditations crafted to help you connect with your future self and cultivate compassion.")
                .font(.system(size: 12.5))
                .foregroundColor(WyldeStyles.Colors.stone)
                .lineSpacing(2)
            Button {
                if let url = URL(string: "https://superconscious-healing.com/") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Learn more about Tommy")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(WyldeStyles.Colors.bronze)
                .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(WyldeStyles.Colors.bronze.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(WyldeStyles.Colors.bronze.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.top, 8)
    }
}

// MARK: - Meditation Model

struct Meditation: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let audioFile: String       // Bundle filename without extension
    let durationSeconds: Int
    let icon: String
    let accent: Color
    let facilitator: String?

    var durationLabel: String {
        let m = durationSeconds / 60
        return "\(m) min"
    }

    static let all: [Meditation] = [
        Meditation(
            id: "guided-visualization",
            title: "Guided Visualization",
            subtitle: "See the version of yourself you're becoming. A calm, structured practice.",
            audioFile: "guided-meditation",
            durationSeconds: 600,
            icon: "figure.mind.and.body",
            accent: WyldeStyles.Colors.vitalTeal,
            facilitator: nil
        ),
        Meditation(
            id: "future-self-kite",
            title: "Future Self Kite",
            subtitle: "A guided journey to meet your future self. Let go and let it fly.",
            audioFile: "future-self-kite-meditation",
            durationSeconds: 473,
            icon: "wind",
            accent: WyldeStyles.Colors.sage,
            facilitator: "Tommy Sobel"
        ),
        Meditation(
            id: "octopus-of-compassion",
            title: "Octopus of Compassion",
            subtitle: "Extend compassion in every direction. A practice for opening the heart.",
            audioFile: "octopus-of-compassion-meditation",
            durationSeconds: 1020,
            icon: "heart.circle",
            accent: WyldeStyles.Colors.bronze,
            facilitator: "Tommy Sobel"
        ),
    ]
}
