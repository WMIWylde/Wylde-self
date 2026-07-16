import SwiftUI

struct ProgramView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = WorkoutService.shared
    @State private var selectedDay: Int? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appBG.ignoresSafeArea()

                if let program = service.program {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Header
                            VStack(alignment: .leading, spacing: 6) {
                                Text("YOUR PROGRAM")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(2.5)
                                    .foregroundColor(Color(hex: "C8A96E"))

                                Text(program.goal)
                                    .font(.system(size: 24, weight: .bold, design: .serif))
                                    .foregroundColor(Theme.primaryText)

                                Text("\(program.days.count)-day split")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.secondaryText)
                            }
                            .padding(.top, 20)

                            // Day cards
                            ForEach(Array(program.days.enumerated()), id: \.element.id) { index, day in
                                dayCard(day: day, index: index)
                            }

                            // Regenerate
                            Button {
                                service.resetProgram()
                                Task { await service.generateProgram(appState: appState) }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 12))
                                    Text("Generate new program")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(Theme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }
                            .padding(.top, 8)

                            Spacer().frame(height: 100)
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .navigationDestination(item: $selectedDay) { dayIndex in
                WorkoutDayView(dayIndex: dayIndex)
                    .environmentObject(appState)
            }
        }
    }

    private func dayCard(day: WorkoutDay, index: Int) -> some View {
        let isToday = (appState.currentDay - 1) % (service.program?.days.count ?? 4) == index

        return Button {
            selectedDay = index
        } label: {
            HStack(spacing: 14) {
                // Day badge
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isToday ? Color(hex: "C8A96E").opacity(0.12) : Theme.chipBG)
                    Text("D\(day.dayNumber)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(isToday ? Color(hex: "C8A96E") : Theme.tertiaryText)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(day.focus)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.primaryText)
                        if isToday {
                            Text("TODAY")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(Color(hex: "C8A96E"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "C8A96E").opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(day.exercises.count) exercises")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.secondaryText)
                }

                Spacer()

                if day.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "7A8771"))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.tertiaryText)
                }
            }
            .padding(16)
            .background(Theme.elevatedBG)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isToday ? Color(hex: "C8A96E").opacity(0.2) : Theme.primaryText.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
