import SwiftUI

struct EditProfileSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var ageRange: String = ""
    @State private var weight: String = ""
    @State private var weightUnit: String = "lbs"
    @State private var heightRange: String = ""
    @State private var fitnessLevel: String = ""

    private let ageOptions = ["18-24", "25-34", "35-44", "45-54", "55-64", "65+"]
    private let heightOptions = ["Under 5'4\"", "5'4\"-5'7\"", "5'8\"-5'11\"", "6'0\"-6'3\"", "6'4\"+"]
    private let fitnessOptions = ["Beginner", "Intermediate", "Advanced"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic info") {
                    TextField("Name", text: $name)
                        .textContentType(.name)

                    Picker("Age range", selection: $ageRange) {
                        Text("Select").tag("")
                        ForEach(ageOptions, id: \.self) { Text($0).tag($0) }
                    }

                    Picker("Height", selection: $heightRange) {
                        Text("Select").tag("")
                        ForEach(heightOptions, id: \.self) { Text($0).tag($0) }
                    }

                    HStack {
                        TextField("Weight", text: $weight)
                            .keyboardType(.decimalPad)
                        Picker("", selection: $weightUnit) {
                            Text("lbs").tag("lbs")
                            Text("kg").tag("kg")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                }

                Section("Fitness") {
                    Picker("Experience level", selection: $fitnessLevel) {
                        Text("Select").tag("")
                        ForEach(fitnessOptions, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                name = appState.userName
                ageRange = appState.ageRange
                weight = appState.weight
                weightUnit = appState.weightUnit
                heightRange = appState.heightRange
                fitnessLevel = appState.fitnessLevel
            }
        }
    }

    private func save() {
        appState.userName = name.trimmingCharacters(in: .whitespaces)
        appState.ageRange = ageRange
        appState.weight = weight
        appState.weightUnit = weightUnit
        appState.heightRange = heightRange
        appState.fitnessLevel = fitnessLevel

        // Sync updated profile to Supabase
        Task {
            await AuthService.shared.syncProfile(appState: appState)
        }
    }
}
