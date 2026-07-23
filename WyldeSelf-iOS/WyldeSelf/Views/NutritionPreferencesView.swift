import SwiftUI

struct NutritionPreferencesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = NutritionPreferencesService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showDiscardAlert = false
    @State private var showMedicalDisclaimer = false
    @State private var disclaimerText = ""

    // Tag input state
    @State private var newFavorite = ""
    @State private var newDislike = ""
    @State private var newExcluded = ""

    var body: some View {
        ZStack {
            Theme.appBG.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        dietaryDirectionSection
                        goalsSection
                        restrictionsSection
                        foodPreferencesSection
                        mealStructureSection
                        lifestyleSection
                        targetsSection
                        notesSection

                        // Save / Cancel
                        VStack(spacing: 12) {
                            GoldButton(label: "Save Preferences", isDisabled: !service.hasUnsavedChanges, action:  {
                                Task {
                                    await service.commitEditing()
                                    service.syncMacroGoalsToAppState(appState)
                                    dismiss()
                                }
                            })

                            Button {
                                service.cancelEditing()
                                dismiss()
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Theme.tertiaryText)
                            }
                        }
                        .padding(.top, 8)

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
        }
        .onAppear { service.beginEditing() }
        .alert("Discard Changes?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                service.cancelEditing()
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You have unsaved changes to your nutrition preferences.")
        }
        .alert("Medical Guidance", isPresented: $showMedicalDisclaimer) {
            Button("I Understand", role: .cancel) {}
        } message: {
            Text(disclaimerText)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("NUTRITION PREFERENCES")
                .font(.system(size: 10, weight: .bold))
                .tracking(2.5)
                .foregroundColor(WyldeStyles.Colors.bronze)
            Spacer()
            Button {
                if service.hasUnsavedChanges {
                    showDiscardAlert = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(Theme.elevatedBG)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Section 1: Dietary Direction

    private var dietaryDirectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("DIETARY DIRECTION")

            ForEach(DietaryFramework.groupedByCategory, id: \.0) { category, frameworks in
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.tertiaryText)

                    FlowLayout(spacing: 8) {
                        ForEach(frameworks) { framework in
                            PillButton(
                                label: framework.displayName,
                                isSelected: service.draft.dietaryFramework == framework
                            ) {
                                service.updateDraft {
                                    if $0.dietaryFramework == framework {
                                        $0.dietaryFramework = nil
                                    } else {
                                        $0.dietaryFramework = framework
                                        if framework.isMedicallySupervised, let disc = framework.medicalDisclaimer {
                                            disclaimerText = disc
                                            showMedicalDisclaimer = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if let fw = service.draft.dietaryFramework {
                Text(fw.description)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.secondaryText)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Section 2: Goals

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("YOUR GOALS")

            FlowLayout(spacing: 8) {
                ForEach(NutritionGoal.allCases) { goal in
                    PillButton(
                        label: goal.displayName,
                        isSelected: service.draft.goals.contains(goal)
                    ) {
                        service.updateDraft {
                            if $0.goals.contains(goal) {
                                $0.goals.removeAll { $0 == goal }
                            } else {
                                $0.goals.append(goal)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Section 3: Restrictions & Allergies

    private var restrictionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(WyldeStyles.Colors.vitalOrange)
                sectionHeader("RESTRICTIONS & ALLERGIES")
            }

            Text("Hard exclusions — meals will never include these ingredients.")
                .font(.system(size: 12))
                .foregroundColor(Theme.secondaryText)

            FlowLayout(spacing: 8) {
                ForEach(Restriction.allCases) { restriction in
                    PillButton(
                        label: restriction.displayName,
                        isSelected: service.draft.restrictions.contains(restriction)
                    ) {
                        service.updateDraft {
                            if $0.restrictions.contains(restriction) {
                                $0.restrictions.removeAll { $0 == restriction }
                            } else {
                                $0.restrictions.append(restriction)
                            }
                        }
                    }
                }
            }

            if service.draft.restrictions.contains(.other) {
                TextField("Describe other restrictions...", text: Binding(
                    get: { service.draft.otherRestrictionText },
                    set: { val in service.updateDraft { $0.otherRestrictionText = val } }
                ))
                .textFieldStyle(prefsTextFieldStyle)
            }
        }
    }

    // MARK: - Section 4: Food Preferences

    private var foodPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("FOOD PREFERENCES")

            // Preferred proteins
            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred proteins")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.secondaryText)

                let proteins = ["Chicken", "Beef", "Turkey", "Fish", "Shrimp", "Tofu", "Tempeh", "Eggs", "Pork", "Lamb"]
                FlowLayout(spacing: 8) {
                    ForEach(proteins, id: \.self) { protein in
                        PillButton(
                            label: protein,
                            isSelected: service.draft.preferredProteins.contains(protein)
                        ) {
                            service.updateDraft {
                                if $0.preferredProteins.contains(protein) {
                                    $0.preferredProteins.removeAll { $0 == protein }
                                } else {
                                    $0.preferredProteins.append(protein)
                                }
                            }
                        }
                    }
                }
            }

            // Preferred cuisines
            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred cuisines")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.secondaryText)

                let cuisines = ["Mediterranean", "Mexican", "Asian", "Italian", "Indian", "American", "Middle Eastern", "Japanese", "Korean", "Thai"]
                FlowLayout(spacing: 8) {
                    ForEach(cuisines, id: \.self) { cuisine in
                        PillButton(
                            label: cuisine,
                            isSelected: service.draft.preferredCuisines.contains(cuisine)
                        ) {
                            service.updateDraft {
                                if $0.preferredCuisines.contains(cuisine) {
                                    $0.preferredCuisines.removeAll { $0 == cuisine }
                                } else {
                                    $0.preferredCuisines.append(cuisine)
                                }
                            }
                        }
                    }
                }
            }

            // Favorite foods
            tagInputSection(title: "Favorite foods", items: service.draft.favoriteFoods, text: $newFavorite) { food in
                service.updateDraft { $0.favoriteFoods.append(food) }
            } onRemove: { food in
                service.updateDraft { $0.favoriteFoods.removeAll { $0 == food } }
            }

            // Disliked foods
            tagInputSection(title: "Foods you dislike", items: service.draft.dislikedFoods, text: $newDislike) { food in
                service.updateDraft { $0.dislikedFoods.append(food) }
            } onRemove: { food in
                service.updateDraft { $0.dislikedFoods.removeAll { $0 == food } }
            }

            // Excluded foods
            tagInputSection(title: "Foods to always exclude", items: service.draft.excludedFoods, text: $newExcluded) { food in
                service.updateDraft { $0.excludedFoods.append(food) }
            } onRemove: { food in
                service.updateDraft { $0.excludedFoods.removeAll { $0 == food } }
            }
        }
    }

    // MARK: - Section 5: Meal Structure

    private var mealStructureSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("MEAL STRUCTURE")

            // Meals per day
            HStack {
                Text("Meals per day")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.primaryText)
                Spacer()
                Stepper("\(service.draft.mealsPerDay)", value: Binding(
                    get: { service.draft.mealsPerDay },
                    set: { val in service.updateDraft { $0.mealsPerDay = val } }
                ), in: 2...6)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Theme.primaryText)
            }

            // Snacks per day
            HStack {
                Text("Snacks per day")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.primaryText)
                Spacer()
                Stepper("\(service.draft.snacksPerDay)", value: Binding(
                    get: { service.draft.snacksPerDay },
                    set: { val in service.updateDraft { $0.snacksPerDay = val } }
                ), in: 0...4)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Theme.primaryText)
            }

            // Household size
            HStack {
                Text("Household size")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.primaryText)
                Spacer()
                Stepper("\(service.draft.householdSize)", value: Binding(
                    get: { service.draft.householdSize },
                    set: { val in service.updateDraft { $0.householdSize = val } }
                ), in: 1...8)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Theme.primaryText)
            }

            // Toggles
            prefsToggle("Include breakfast", isOn: Binding(
                get: { service.draft.includeBreakfast },
                set: { val in service.updateDraft { $0.includeBreakfast = val } }
            ))

            prefsToggle("Intermittent fasting", isOn: Binding(
                get: { service.draft.intermittentFasting },
                set: { val in service.updateDraft { $0.intermittentFasting = val } }
            ))

            if service.draft.intermittentFasting {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.tertiaryText)
                        TextField("8:00 AM", text: Binding(
                            get: { service.draft.eatingWindowStart ?? "" },
                            set: { val in service.updateDraft { $0.eatingWindowStart = val.isEmpty ? nil : val } }
                        ))
                        .textFieldStyle(prefsTextFieldStyle)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("End")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.tertiaryText)
                        TextField("8:00 PM", text: Binding(
                            get: { service.draft.eatingWindowEnd ?? "" },
                            set: { val in service.updateDraft { $0.eatingWindowEnd = val.isEmpty ? nil : val } }
                        ))
                        .textFieldStyle(prefsTextFieldStyle)
                    }
                }
            }

            prefsToggle("Leftovers allowed", isOn: Binding(
                get: { service.draft.leftoversAllowed },
                set: { val in service.updateDraft { $0.leftoversAllowed = val } }
            ))

            prefsToggle("Repeat meals OK", isOn: Binding(
                get: { service.draft.repeatMealsAllowed },
                set: { val in service.updateDraft { $0.repeatMealsAllowed = val } }
            ))

            // Meal prep days
            VStack(alignment: .leading, spacing: 8) {
                Text("Meal prep days")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.secondaryText)

                let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                FlowLayout(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        PillButton(
                            label: String(day.prefix(3)),
                            isSelected: service.draft.mealPrepDays.contains(day)
                        ) {
                            service.updateDraft {
                                if $0.mealPrepDays.contains(day) {
                                    $0.mealPrepDays.removeAll { $0 == day }
                                } else {
                                    $0.mealPrepDays.append(day)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Section 6: Lifestyle

    private var lifestyleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("LIFESTYLE")

            // Cooking skill
            VStack(alignment: .leading, spacing: 8) {
                Text("Cooking skill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.secondaryText)

                FlowLayout(spacing: 8) {
                    ForEach(CookingSkill.allCases) { skill in
                        PillButton(
                            label: skill.displayName,
                            isSelected: service.draft.cookingSkill == skill
                        ) {
                            service.updateDraft {
                                $0.cookingSkill = $0.cookingSkill == skill ? nil : skill
                            }
                        }
                    }
                }
            }

            // Max cooking time
            HStack {
                Text("Max cooking time")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.primaryText)
                Spacer()
                if let maxMin = service.draft.maxCookingMinutes {
                    Text("\(maxMin) min")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(WyldeStyles.Colors.bronze)
                    Stepper("", value: Binding(
                        get: { maxMin },
                        set: { val in service.updateDraft { $0.maxCookingMinutes = val } }
                    ), in: 10...120, step: 5)
                    .labelsHidden()
                } else {
                    Button("Set limit") {
                        service.updateDraft { $0.maxCookingMinutes = 30 }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WyldeStyles.Colors.bronze)
                }
            }

            // Budget
            HStack {
                Text("Weekly budget")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.primaryText)
                Spacer()
                TextField("Optional", text: Binding(
                    get: { service.draft.weeklyBudget ?? "" },
                    set: { val in service.updateDraft { $0.weeklyBudget = val.isEmpty ? nil : val } }
                ))
                .textFieldStyle(prefsTextFieldStyle)
                .frame(maxWidth: 120)
            }

            // Appliances
            VStack(alignment: .leading, spacing: 8) {
                Text("Available appliances")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.secondaryText)

                FlowLayout(spacing: 8) {
                    ForEach(Appliance.allCases) { appliance in
                        PillButton(
                            label: appliance.displayName,
                            isSelected: service.draft.availableAppliances.contains(appliance)
                        ) {
                            service.updateDraft {
                                if $0.availableAppliances.contains(appliance) {
                                    $0.availableAppliances.removeAll { $0 == appliance }
                                } else {
                                    $0.availableAppliances.append(appliance)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Section 7: Targets

    private var targetsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                sectionHeader("CUSTOM TARGETS")
                Text("(optional)")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.tertiaryText)
            }

            Text("Leave blank to use your profile defaults.")
                .font(.system(size: 12))
                .foregroundColor(Theme.secondaryText)

            targetRow(label: "Calories", value: service.draft.calorieTarget, unit: "") { val in
                service.updateDraft { $0.calorieTarget = val }
            }
            targetRow(label: "Protein", value: service.draft.proteinTarget, unit: "g") { val in
                service.updateDraft { $0.proteinTarget = val }
            }
            targetRow(label: "Carbs", value: service.draft.carbTarget, unit: "g") { val in
                service.updateDraft { $0.carbTarget = val }
            }
            targetRow(label: "Fat", value: service.draft.fatTarget, unit: "g") { val in
                service.updateDraft { $0.fatTarget = val }
            }
            targetRow(label: "Fiber", value: service.draft.fiberTarget, unit: "g") { val in
                service.updateDraft { $0.fiberTarget = val }
            }
        }
    }

    // MARK: - Section 8: Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                sectionHeader("NOTES")
                Text("(optional)")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.tertiaryText)
            }

            TextField("Any other dietary needs, medical context, or preferences...", text: Binding(
                get: { service.draft.clinicalNotes },
                set: { val in service.updateDraft { $0.clinicalNotes = val } }
            ), axis: .vertical)
            .lineLimit(3...6)
            .textFieldStyle(prefsTextFieldStyle)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .tracking(2)
            .foregroundColor(Theme.tertiaryText)
    }

    private func prefsToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Theme.primaryText)
        }
        .tint(WyldeStyles.Colors.bronze)
    }

    private func targetRow(label: String, value: Int?, unit: String, onChange: @escaping (Int?) -> Void) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Theme.primaryText)
            if !unit.isEmpty {
                Text("(\(unit))")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.tertiaryText)
            }
            Spacer()
            TextField("—", text: Binding(
                get: { value.map(String.init) ?? "" },
                set: { text in onChange(Int(text)) }
            ))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(WyldeStyles.Colors.bronze)
            .frame(width: 80)

            if value != nil {
                Button {
                    onChange(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.tertiaryText)
                }
            }
        }
    }

    private func tagInputSection(title: String, items: [String], text: Binding<String>, onAdd: @escaping (String) -> Void, onRemove: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.secondaryText)

            if !items.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        HStack(spacing: 4) {
                            Text(item)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.primaryText)
                            Button { onRemove(item) } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(Theme.tertiaryText)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.chipBG)
                        .clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Add...", text: text)
                    .textFieldStyle(prefsTextFieldStyle)
                    .onSubmit {
                        let trimmed = text.wrappedValue.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty && !items.contains(trimmed) {
                            onAdd(trimmed)
                            text.wrappedValue = ""
                        }
                    }
                Button {
                    let trimmed = text.wrappedValue.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && !items.contains(trimmed) {
                        onAdd(trimmed)
                        text.wrappedValue = ""
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(WyldeStyles.Colors.bronze)
                }
            }
        }
    }

    private var prefsTextFieldStyle: some TextFieldStyle {
        PrefsTextFieldStyle()
    }
}

// MARK: - Custom TextField Style

struct PrefsTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 13))
            .foregroundColor(Theme.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.elevatedBG)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.primaryText.opacity(0.06), lineWidth: 1)
            )
    }
}
