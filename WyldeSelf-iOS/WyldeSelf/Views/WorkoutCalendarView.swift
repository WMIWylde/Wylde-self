import SwiftUI
import UserNotifications

struct WorkoutCalendarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDays: Set<Int> = [] // 0=Sun, 1=Mon...6=Sat
    @State private var workoutTime = Date()
    @State private var waterReminders = true
    @State private var proteinReminders = true
    @State private var saved = false

    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        ZStack {
            Color(hex: "070707").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SCHEDULE")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2.5)
                                .foregroundColor(Color(hex: "C8A96E"))
                            Text("Plan Your Week")
                                .font(.system(size: 22, weight: .bold, design: .serif))
                                .foregroundColor(Color(hex: "F4F1E8"))
                        }
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "A6A29A"))
                                .frame(width: 36, height: 36)
                                .background(Color(hex: "111111"))
                                .clipShape(Circle())
                        }
                    }

                    // Workout Days
                    VStack(alignment: .leading, spacing: 12) {
                        Text("WORKOUT DAYS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Color(hex: "6E6B65"))
                        Text("Which days do you train?")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "A6A29A"))

                        HStack(spacing: 8) {
                            ForEach(0..<7, id: \.self) { day in
                                dayButton(day)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(hex: "111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Workout Time
                    VStack(alignment: .leading, spacing: 12) {
                        Text("WORKOUT TIME")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Color(hex: "6E6B65"))
                        Text("When do you usually train?")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "A6A29A"))

                        DatePicker("", selection: $workoutTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .frame(height: 120)
                    }
                    .padding(20)
                    .background(Color(hex: "111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Reminders
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DAILY REMINDERS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Color(hex: "6E6B65"))

                        reminderToggle(
                            icon: "drop.fill",
                            title: "Water Reminders",
                            subtitle: "Every 2 hours from 8am to 8pm",
                            color: Color(hex: "7FD0FF"),
                            isOn: $waterReminders
                        )

                        reminderToggle(
                            icon: "fork.knife",
                            title: "Protein Check-In",
                            subtitle: "Midday + evening — are you on track?",
                            color: Color(hex: "5EE6D6"),
                            isOn: $proteinReminders
                        )
                    }
                    .padding(20)
                    .background(Color(hex: "111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Save
                    GoldButton(label: saved ? "Saved ✓" : "Save Schedule") {
                        saveSchedule()
                    }
                    .disabled(saved)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { loadSchedule() }
    }

    // MARK: - Day Button

    private func dayButton(_ day: Int) -> some View {
        let isSelected = selectedDays.contains(day)
        return Button {
            if isSelected { selectedDays.remove(day) }
            else { selectedDays.insert(day) }
            saved = false
        } label: {
            Text(dayLabels[day])
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? Color(hex: "070707") : Color(hex: "A6A29A"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color(hex: "C8A96E") : Color(hex: "1A1A1A"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Reminder Toggle

    private func reminderToggle(icon: String, title: String, subtitle: String, color: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "F4F1E8"))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "A6A29A"))
            }
            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(color)
                .onChange(of: isOn.wrappedValue) { saved = false }
        }
    }

    // MARK: - Save & Schedule

    private func saveSchedule() {
        let defaults = UserDefaults.standard
        defaults.set(Array(selectedDays), forKey: "wylde_workout_days")
        defaults.set(workoutTime.timeIntervalSince1970, forKey: "wylde_workout_time")
        defaults.set(waterReminders, forKey: "wylde_water_reminders")
        defaults.set(proteinReminders, forKey: "wylde_protein_reminders")

        scheduleNotifications()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            saved = true
        }
        HapticManager.shared.notification(.success)
    }

    private func loadSchedule() {
        let defaults = UserDefaults.standard
        if let days = defaults.array(forKey: "wylde_workout_days") as? [Int] {
            selectedDays = Set(days)
        }
        let timeInterval = defaults.double(forKey: "wylde_workout_time")
        if timeInterval > 0 { workoutTime = Date(timeIntervalSince1970: timeInterval) }
        waterReminders = defaults.bool(forKey: "wylde_water_reminders")
        proteinReminders = defaults.bool(forKey: "wylde_protein_reminders")
        // Default water to true if never set
        if defaults.object(forKey: "wylde_water_reminders") == nil { waterReminders = true }
        if defaults.object(forKey: "wylde_protein_reminders") == nil { proteinReminders = true }
    }

    // MARK: - Notifications

    private func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()

        // Remove old scheduled notifications
        center.removePendingNotificationRequests(withIdentifiers:
            (0..<7).map { "workout_day_\($0)" } +
            (8...20).map { "water_\($0)" } +
            ["protein_midday", "protein_evening"]
        )

        // Workout reminders
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: workoutTime)
        let minute = calendar.component(.minute, from: workoutTime)

        for day in selectedDays {
            var dateComponents = DateComponents()
            dateComponents.weekday = day + 1 // Sunday = 1 in Calendar
            dateComponents.hour = hour
            dateComponents.minute = max(0, minute - 30) // 30 min before

            let content = UNMutableNotificationContent()
            content.title = "Time to train"
            content.body = "Your workout starts in 30 minutes. Warm up and show up."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "workout_day_\(day)", content: content, trigger: trigger)
            center.add(request)
        }

        // Water reminders — every 2 hours from 8am to 8pm
        if waterReminders {
            for hour in stride(from: 8, through: 20, by: 2) {
                var dateComponents = DateComponents()
                dateComponents.hour = hour
                dateComponents.minute = 0

                let content = UNMutableNotificationContent()
                content.title = "Hydrate"
                content.body = ["Drink water. Your body needs it.", "Glass of water. Now.", "Stay hydrated — it compounds.", "Water break. Keep it moving."][hour % 4]
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(identifier: "water_\(hour)", content: content, trigger: trigger)
                center.add(request)
            }
        }

        // Protein reminders — midday + evening
        if proteinReminders {
            // Midday — 12pm
            let middayContent = UNMutableNotificationContent()
            middayContent.title = "Protein check"
            middayContent.body = "Are you on track for \(appState.proteinGoal)g today? Make the next meal protein-forward."
            middayContent.sound = .default

            var middayComponents = DateComponents()
            middayComponents.hour = 12
            middayComponents.minute = 0
            center.add(UNNotificationRequest(
                identifier: "protein_midday",
                content: middayContent,
                trigger: UNCalendarNotificationTrigger(dateMatching: middayComponents, repeats: true)
            ))

            // Evening — 6pm
            let eveningContent = UNMutableNotificationContent()
            eveningContent.title = "Protein check"
            eveningContent.body = "Evening check — have you hit your protein target? A shake can close the gap."
            eveningContent.sound = .default

            var eveningComponents = DateComponents()
            eveningComponents.hour = 18
            eveningComponents.minute = 0
            center.add(UNNotificationRequest(
                identifier: "protein_evening",
                content: eveningContent,
                trigger: UNCalendarNotificationTrigger(dateMatching: eveningComponents, repeats: true)
            ))
        }
    }
}
