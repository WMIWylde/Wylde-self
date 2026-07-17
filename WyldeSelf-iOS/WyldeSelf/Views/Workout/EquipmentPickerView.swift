import SwiftUI

struct EquipmentPickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let onConfirm: (Set<String>) -> Void

    @State private var selected: Set<String> = []

    private let presets: [(String, String, Set<String>)] = [
        ("Bodyweight Only", "figure.walk", ["bodyweight"]),
        ("Home Basics", "house.fill", ["bodyweight", "dumbbells", "resistance_bands"]),
        ("Home Gym", "dumbbell.fill", ["bodyweight", "dumbbells", "barbell", "bench", "pull_up_bar", "kettlebell"]),
        ("Full Gym", "building.2.fill", ["bodyweight", "dumbbells", "barbell", "bench", "cables", "machines", "pull_up_bar", "kettlebell"]),
    ]

    private let equipment: [(id: String, name: String, icon: String)] = [
        ("bodyweight", "Bodyweight", "figure.strengthtraining.functional"),
        ("dumbbells", "Dumbbells", "dumbbell.fill"),
        ("barbell", "Barbell & Plates", "figure.strengthtraining.traditional"),
        ("kettlebell", "Kettlebell", "figure.cross.training"),
        ("bench", "Bench", "square.split.bottomrightquarter.fill"),
        ("pull_up_bar", "Pull-Up Bar", "arrow.up.square"),
        ("resistance_bands", "Resistance Bands", "oval.portrait"),
        ("cables", "Cable Machine", "cable.connector.horizontal"),
        ("machines", "Gym Machines", "gearshape.2.fill"),
        ("trx", "TRX / Suspension", "point.bottomleft.forward.to.point.topright.scurvepath.fill"),
        ("cardio_machines", "Cardio Machines", "figure.run"),
    ]

    var body: some View {
        ZStack {
            Theme.appBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.secondaryText)
                                .frame(width: 36, height: 36)
                                .background(Theme.elevatedBG)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 4)

                    Text("WHAT ARE YOU WORKING WITH?")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(WyldeStyles.Colors.bronze)

                    Text("Pick your setup for today")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(Theme.primaryText)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Quick presets
                        Text("QUICK SELECT")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Theme.secondaryText)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(presets, id: \.0) { preset in
                                let isActive = preset.2.isSubset(of: selected) && selected.isSubset(of: preset.2)
                                Button {
                                    HapticManager.shared.impact(.light)
                                    selected = preset.2
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: preset.1)
                                            .font(.system(size: 20))
                                            .foregroundColor(isActive ? WyldeStyles.Colors.bronze : Theme.secondaryText)
                                        Text(preset.0)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(isActive ? Theme.primaryText : Theme.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(isActive ? WyldeStyles.Colors.bronze.opacity(0.10) : Theme.elevatedBG)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(isActive ? WyldeStyles.Colors.bronze.opacity(0.4) : Theme.primaryText.opacity(0.06), lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Individual equipment
                        Text("OR PICK INDIVIDUALLY")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Theme.secondaryText)
                            .padding(.top, 8)

                        ForEach(equipment, id: \.id) { item in
                            let isOn = selected.contains(item.id)
                            Button {
                                HapticManager.shared.impact(.light)
                                if isOn {
                                    selected.remove(item.id)
                                } else {
                                    selected.insert(item.id)
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(isOn ? WyldeStyles.Colors.bronze : Theme.tertiaryText)
                                        .frame(width: 36, height: 36)
                                        .background(isOn ? WyldeStyles.Colors.bronze.opacity(0.10) : Theme.elevatedBG)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                    Text(item.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(isOn ? Theme.primaryText : Theme.secondaryText)

                                    Spacer()

                                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(isOn ? WyldeStyles.Colors.bronze : Theme.tertiaryText)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Theme.elevatedBG)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer().frame(height: 80)
                    }
                    .padding(.horizontal, 20)
                }

                // Confirm button
                Button {
                    HapticManager.shared.impact(.medium)
                    onConfirm(selected.isEmpty ? Set(["bodyweight"]) : selected)
                    dismiss()
                } label: {
                    Text(selected.isEmpty ? "Bodyweight Workout" : "Generate Workout (\(selected.count))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(WyldeStyles.Colors.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [WyldeStyles.Colors.gold, Color(hex: "A6834A")],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            // Default to whatever they set in onboarding
            if !appState.equipment.isEmpty {
                // Parse onboarding equipment string into our IDs
                let eq = appState.equipment.lowercased()
                if eq.contains("none") || eq.contains("body") { selected = ["bodyweight"] }
                else if eq.contains("some") || eq.contains("basic") { selected = ["bodyweight", "dumbbells", "resistance_bands"] }
                else if eq.contains("full") || eq.contains("complete") { selected = ["bodyweight", "dumbbells", "barbell", "bench", "cables", "machines", "pull_up_bar", "kettlebell"] }
                else { selected = ["bodyweight", "dumbbells"] }
            } else {
                selected = ["bodyweight", "dumbbells"]
            }
        }
    }
}
