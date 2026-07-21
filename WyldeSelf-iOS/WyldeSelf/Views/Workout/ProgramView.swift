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
                            // Fallback notice — never silently pass off a template as AI
                            if service.usedFallback {
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(WyldeStyles.Colors.clay)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("This is a starter template")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(WyldeStyles.Colors.ink)
                                        Text("Custom generation didn't finish. Regenerate for a program built around your goals.")
                                            .font(.system(size: 12))
                                            .foregroundColor(WyldeStyles.Colors.stone)
                                    }
                                    Spacer()
                                    Button("Retry") {
                                        Task { await service.generateProgram(appState: appState) }
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(WyldeStyles.Colors.bronze)
                                }
                                .padding(14)
                                .background(WyldeStyles.Colors.clay.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Header
                            VStack(alignment: .leading, spacing: 6) {
                                Text("YOUR PROGRAM")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(2.5)
                                    .foregroundColor(WyldeStyles.Colors.bronze)

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
                        .fill(isToday ? WyldeStyles.Colors.bronze.opacity(0.12) : Theme.chipBG)
                    Text("D\(day.dayNumber)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(isToday ? WyldeStyles.Colors.bronze : Theme.tertiaryText)
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
                                .foregroundColor(WyldeStyles.Colors.bronze)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(WyldeStyles.Colors.bronze.opacity(0.12))
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
                        .foregroundColor(WyldeStyles.Colors.sage)
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
                    .stroke(isToday ? WyldeStyles.Colors.bronze.opacity(0.2) : Theme.primaryText.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
