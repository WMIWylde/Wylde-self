import SwiftUI
import HealthKit

struct WatchWorkoutView: View {
    @EnvironmentObject var connector: PhoneConnector
    @Environment(\.dismiss) private var dismiss

    @State private var isActive = false
    @State private var elapsed = 0
    @State private var timer: Timer?
    @State private var heartRate: Double = 0
    @State private var calories: Double = 0

    private let healthStore = HKHealthStore()

    var body: some View {
        VStack(spacing: 12) {
            if !isActive && !connector.workoutCompleted {
                // Pre-workout
                VStack(spacing: 16) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(red: 0.78, green: 0.66, blue: 0.43))

                    if !connector.workoutFocus.isEmpty {
                        Text(connector.workoutFocus)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("\(connector.workoutExerciseCount) exercises")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Button {
                        startWorkout()
                    } label: {
                        Text("Start")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.78, green: 0.66, blue: 0.43))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

            } else if isActive {
                // Active workout
                VStack(spacing: 8) {
                    // Timer
                    Text(formatTime(elapsed))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.78, green: 0.66, blue: 0.43))

                    // Heart rate
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        Text(heartRate > 0 ? "\(Int(heartRate)) bpm" : "--")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    // Calories
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text("\(Int(calories)) cal")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer().frame(height: 8)

                    // End button
                    Button {
                        endWorkout()
                    } label: {
                        Text("End Workout")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

            } else {
                // Completed
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.green)
                    Text("Workout Complete")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(formatTime(elapsed))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(8)
        .onDisappear {
            timer?.invalidate()
        }
    }

    // MARK: - Workout Control

    private func startWorkout() {
        isActive = true
        elapsed = 0
        calories = 0
        heartRate = 0

        connector.startWorkout()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                elapsed += 1
                // Estimate calories (rough: ~8 cal/min for strength training)
                calories = Double(elapsed) / 60.0 * 8.0
            }
        }

        startHeartRateQuery()
    }

    private func endWorkout() {
        timer?.invalidate()
        timer = nil
        isActive = false

        connector.endWorkout()
    }

    private func startHeartRateQuery() {
        guard HKHealthStore.isHealthDataAvailable(),
              let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let query = HKAnchoredObjectQuery(
            type: hrType,
            predicate: HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate),
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { _, samples, _, _, _ in
            self.processHeartRate(samples)
        }

        query.updateHandler = { _, samples, _, _, _ in
            self.processHeartRate(samples)
        }

        healthStore.execute(query)
    }

    private func processHeartRate(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else { return }
        let bpm = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        DispatchQueue.main.async {
            heartRate = bpm
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
