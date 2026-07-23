import SwiftUI

struct CreateRecipeView: View {
    @StateObject private var recipeBook = RecipeBookService.shared
    @Environment(\.dismiss) private var dismiss

    var editingRecipe: Recipe?

    @State private var name = ""
    @State private var description = ""
    @State private var mealType: MealType = .dinner
    @State private var prepTime = 15
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var ingredients: [String] = []
    @State private var instructions: [String] = []
    @State private var tags: [String] = []

    @State private var newIngredient = ""
    @State private var newInstruction = ""
    @State private var newTag = ""

    var body: some View {
        ZStack {
            Theme.appBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Text(editingRecipe == nil ? "CREATE RECIPE" : "EDIT RECIPE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(WyldeStyles.Colors.bronze)
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
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Name
                        fieldSection("RECIPE NAME") {
                            TextField("e.g. Garlic Butter Chicken", text: $name)
                                .recipeField()
                        }

                        // Description
                        fieldSection("DESCRIPTION") {
                            TextField("Brief description (optional)", text: $description)
                                .recipeField()
                        }

                        // Meal type
                        fieldSection("MEAL TYPE") {
                            HStack(spacing: 8) {
                                ForEach([MealType.breakfast, .lunch, .dinner, .snack], id: \.self) { type in
                                    PillButton(label: type.rawValue, isSelected: mealType == type) {
                                        mealType = type
                                    }
                                }
                            }
                        }

                        // Prep time
                        fieldSection("PREP TIME") {
                            HStack {
                                Stepper("\(prepTime) min", value: $prepTime, in: 1...180, step: 5)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(Theme.primaryText)
                            }
                        }

                        // Macros
                        fieldSection("NUTRITION (per serving)") {
                            HStack(spacing: 12) {
                                macroField("Cal", text: $calories)
                                macroField("Protein", text: $protein)
                                macroField("Carbs", text: $carbs)
                                macroField("Fat", text: $fat)
                            }
                        }

                        // Ingredients
                        fieldSection("INGREDIENTS") {
                            ForEach(ingredients.indices, id: \.self) { i in
                                HStack(spacing: 8) {
                                    Text("·")
                                        .foregroundColor(WyldeStyles.Colors.bronze)
                                    Text(ingredients[i])
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.primaryText)
                                    Spacer()
                                    Button {
                                        ingredients.remove(at: i)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(Theme.tertiaryText)
                                    }
                                }
                            }

                            HStack(spacing: 8) {
                                TextField("e.g. 6 oz chicken breast", text: $newIngredient)
                                    .recipeField()
                                    .onSubmit { addIngredient() }
                                Button { addIngredient() } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(WyldeStyles.Colors.bronze)
                                }
                            }
                        }

                        // Instructions
                        fieldSection("INSTRUCTIONS") {
                            ForEach(Array(instructions.enumerated()), id: \.offset) { i, step in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(i + 1).")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(WyldeStyles.Colors.bronze)
                                        .frame(width: 20)
                                    Text(step)
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.primaryText)
                                    Spacer()
                                    Button {
                                        instructions.remove(at: i)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(Theme.tertiaryText)
                                    }
                                }
                            }

                            HStack(spacing: 8) {
                                TextField("e.g. Sear chicken 4 min each side", text: $newInstruction)
                                    .recipeField()
                                    .onSubmit { addInstruction() }
                                Button { addInstruction() } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(WyldeStyles.Colors.bronze)
                                }
                            }
                        }

                        // Tags
                        fieldSection("TAGS (optional)") {
                            if !tags.isEmpty {
                                FlowLayout(spacing: 6) {
                                    ForEach(tags, id: \.self) { tag in
                                        HStack(spacing: 4) {
                                            Text(tag)
                                                .font(.system(size: 11))
                                                .foregroundColor(Theme.primaryText)
                                            Button { tags.removeAll { $0 == tag } } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(Theme.tertiaryText)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Theme.chipBG)
                                        .clipShape(Capsule())
                                    }
                                }
                            }

                            let presetTags = ["high-protein", "low-carb", "quick", "meal-prep", "vegan", "vegetarian", "keto", "mediterranean", "comfort", "one-pot", "sheet-pan", "budget"]
                            FlowLayout(spacing: 6) {
                                ForEach(presetTags.filter { !tags.contains($0) }, id: \.self) { tag in
                                    Button {
                                        tags.append(tag)
                                    } label: {
                                        Text("+ \(tag)")
                                            .font(.system(size: 10))
                                            .foregroundColor(Theme.tertiaryText)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Theme.elevatedBG)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        // Save
                        GoldButton(label: editingRecipe == nil ? "Save Recipe" : "Update Recipe", isDisabled: !isValid) {
                            saveRecipe()
                        }
                        .padding(.top, 8)

                        if editingRecipe != nil {
                            Button {
                                if let id = editingRecipe?.id {
                                    recipeBook.deleteRecipe(id)
                                }
                                dismiss()
                            } label: {
                                Text("Delete Recipe")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.red.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
        }
        .onAppear {
            if let r = editingRecipe {
                name = r.name
                description = r.description
                mealType = r.mealType
                prepTime = r.prepTime
                calories = r.calories > 0 ? "\(r.calories)" : ""
                protein = r.protein > 0 ? "\(r.protein)" : ""
                carbs = r.carbs > 0 ? "\(r.carbs)" : ""
                fat = r.fat > 0 ? "\(r.fat)" : ""
                ingredients = r.ingredients
                instructions = r.instructions
                tags = r.tags
            }
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !ingredients.isEmpty
    }

    // MARK: - Actions

    private func addIngredient() {
        let trimmed = newIngredient.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        ingredients.append(trimmed)
        newIngredient = ""
    }

    private func addInstruction() {
        let trimmed = newInstruction.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        instructions.append(trimmed)
        newInstruction = ""
    }

    private func saveRecipe() {
        let recipe = Recipe(
            mealType: mealType,
            name: name.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            ingredients: ingredients,
            instructions: instructions,
            prepTime: prepTime,
            calories: Int(calories) ?? 0,
            protein: Int(protein) ?? 0,
            carbs: Int(carbs) ?? 0,
            fat: Int(fat) ?? 0,
            tags: tags
        )

        if editingRecipe != nil {
            // Delete old, save new (ID changes but that's fine for user recipes)
            if let oldId = editingRecipe?.id {
                recipeBook.deleteRecipe(oldId)
            }
            recipeBook.saveRecipe(recipe)
        } else {
            recipeBook.saveRecipe(recipe)
        }
        dismiss()
    }

    // MARK: - Helpers

    private func fieldSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(Theme.tertiaryText)
            content()
        }
    }

    private func macroField(_ label: String, text: Binding<String>) -> some View {
        VStack(spacing: 4) {
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(WyldeStyles.Colors.bronze)
                .frame(height: 40)
                .background(Theme.elevatedBG)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Theme.tertiaryText)
        }
    }
}

// MARK: - Recipe TextField Modifier

extension View {
    func recipeField() -> some View {
        self
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
