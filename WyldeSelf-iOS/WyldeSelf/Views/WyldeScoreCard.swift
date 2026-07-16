import SwiftUI

struct WyldeScoreCard: View {
    let score: WyldeScore?
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() }
            } label: {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(Color(hex: "C8A96E"))
                Text("WYLDE SCORE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "C8A96E"))
                Spacer()
                if let s = score {
                    Text("\(s.totalScore)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.primaryText)
                        .contentTransition(.numericText())
                    Text(s.grade)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(gradeColor(s.totalScore))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(gradeColor(s.totalScore).opacity(0.12))
                        .clipShape(Capsule())
                }
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.tertiaryText)
            }
            } // close Button label
            .buttonStyle(.plain)

            if expanded {
            if let s = score {
                // Total score
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(s.totalScore)")
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.primaryText)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.4), value: s.totalScore)
                    Text("/ 100")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.tertiaryText)
                }

                // Component bars
                VStack(spacing: 6) {
                    scoreBar(label: "Ritual", score: s.ritualScore, max: 20, color: Color(hex: "C8A96E"))
                    scoreBar(label: "Movement", score: s.movementScore, max: 20, color: Color(hex: "5EE6D6"))
                    scoreBar(label: "Nutrition", score: s.nutritionScore, max: 20, color: Color(hex: "FF9A3C"))
                    scoreBar(label: "Protocol", score: s.protocolScore, max: 25, color: Color(hex: "B68BFF"))
                    scoreBar(label: "Recovery", score: s.recoveryScore, max: 10, color: Color(hex: "7FD0FF"))
                    scoreBar(label: "Mindset", score: s.mindsetScore, max: 5, color: Color(hex: "7A8771"))
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("—")
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.tertiaryText)
                    Text("/ 100")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.tertiaryText)
                }
                Text("Complete today's actions to build your score")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.secondaryText)
            }
            } // if expanded
        }
        .padding(20)
        .background(Theme.elevatedBG)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hex: "C8A96E").opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    private func scoreBar(label: String, score: Int, max: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.secondaryText)
                .frame(width: 60, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(score) / CGFloat(max))
                        .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 0)
                        .animation(.easeOut(duration: 0.6), value: score)
                }
            }
            .frame(height: 4)

            Text("\(score)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 20, alignment: .trailing)
        }
    }

    private func gradeColor(_ score: Int) -> Color {
        switch score {
        case 90...100: return Color(hex: "C8A96E")
        case 75..<90: return Color(hex: "5EE6D6")
        case 55..<75: return Color(hex: "7A8771")
        case 35..<55: return Color(hex: "FF9A3C")
        default: return Theme.secondaryText
        }
    }
}
