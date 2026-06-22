import SwiftUI

struct FutureReflectionFlow: View {
    let category: VisionCategory
    @Binding var answers: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Category header
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(VisionTheme.accent)
                Text(category.name.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.5)
                    .foregroundColor(VisionTheme.accent)
            }

            Text("What does success look like here?")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(VisionTheme.text)

            ForEach(Array(category.prompts.enumerated()), id: \.offset) { index, prompt in
                VStack(alignment: .leading, spacing: 8) {
                    Text(prompt)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(VisionTheme.textMuted)

                    TextField("", text: binding(for: index), axis: .vertical)
                        .lineLimit(2...5)
                        .font(.system(size: 15))
                        .foregroundColor(VisionTheme.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(VisionTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(VisionTheme.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .tint(VisionTheme.accent)
                }
            }
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        while answers.count <= index { answers.append("") }
        return Binding(
            get: { index < answers.count ? answers[index] : "" },
            set: { answers[index] = $0 }
        )
    }
}
