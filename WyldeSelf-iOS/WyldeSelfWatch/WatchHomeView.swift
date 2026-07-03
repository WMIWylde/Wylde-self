import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject var connector: PhoneConnector

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Day + Score header
                    dayHeader

                    // Workout card
                    NavigationLink(destination: WatchWorkoutView()) {
                        workoutCard
                    }
                    .buttonStyle(.plain)

                    // Water card
                    waterCard

                    // Walk card
                    walkCard

                    // Ritual progress
                    ritualCard
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Wylde")
        }
    }

    // MARK: - Day Header

    private var dayHeader: some View {
        VStack(spacing: 4) {
            Text("DAY \(connector.currentDay)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.78, green: 0.66, blue: 0.43)) // gold

            if connector.wyldeScore > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text("\(connector.wyldeScore)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Workout

    private var workoutCard: some View {
        HStack(spacing: 10) {
            Image(systemName: connector.workoutCompleted ? "checkmark.circle.fill" : "dumbbell.fill")
                .font(.system(size: 18))
                .foregroundColor(connector.workoutCompleted ? .green : Color(red: 0.78, green: 0.66, blue: 0.43))

            VStack(alignment: .leading, spacing: 2) {
                Text(connector.workoutCompleted ? "Done" : "Workout")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                if !connector.workoutCompleted && !connector.workoutFocus.isEmpty {
                    Text(connector.workoutFocus)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            Spacer()
            if !connector.workoutCompleted {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Water

    private var waterCard: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "drop.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.5, green: 0.82, blue: 1.0))
                Text("Water")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(connector.waterLogged)/\(connector.waterGoal)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Dots
            HStack(spacing: 4) {
                ForEach(0..<connector.waterGoal, id: \.self) { i in
                    Circle()
                        .fill(i < connector.waterLogged ? Color(red: 0.5, green: 0.82, blue: 1.0) : Color.white.opacity(0.12))
                        .frame(width: 14, height: 14)
                }
            }

            // Add button
            Button {
                connector.addWater()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Add")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(red: 0.5, green: 0.82, blue: 1.0))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(connector.waterLogged >= connector.waterGoal)
            .opacity(connector.waterLogged >= connector.waterGoal ? 0.4 : 1)
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Walk

    private var walkCard: some View {
        HStack(spacing: 10) {
            Image(systemName: connector.walkCompleted ? "checkmark.circle.fill" : "figure.walk")
                .font(.system(size: 16))
                .foregroundColor(connector.walkCompleted ? .green : Color(red: 0.5, green: 0.82, blue: 1.0))

            Text(connector.walkCompleted ? "Walk done" : "30 min walk")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            if !connector.walkCompleted {
                Button {
                    connector.endWalk()
                } label: {
                    Text("Done")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.5, green: 0.82, blue: 1.0))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Ritual

    private var ritualCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.78, green: 0.66, blue: 0.43))

            Text("Ritual")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            Text("\(connector.ritualDone)/\(connector.ritualTotal)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(connector.ritualDone == connector.ritualTotal ? .green : .white.opacity(0.6))
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
