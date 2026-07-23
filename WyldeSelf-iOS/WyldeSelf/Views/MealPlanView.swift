import SwiftUI

struct MealPlanView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = MealPlanService.shared
    @StateObject private var recipeBook = RecipeBookService.shared
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable {
        case plan = "Meal Plan"
        case recipes = "Recipe Book"
        case groceries = "Grocery List"
    }

    @State private var selectedTab: Tab = .plan
    @State private var selectedDay: String? = nil
    @State private var expandedMeal: UUID? = nil

    // Manual plan builder state
    @State private var isBuilding = false
    @State private var buildDays: [DayMealPlan] = []
    @State private var buildingDayIndex: Int = 0
    @State private var showRecipePicker = false
    @State private var pickerMealType: MealType = .breakfast
    @State private var showPreferences = false
    @State private var showMealDetail = false
    @State private var detailMealId: UUID? = nil
    @State private var detailDayId: String = ""
    @State private var showReplaceConfirm = false
    @State private var pendingReplaceAction: (() -> Void)? = nil

    private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        ZStack {
            Theme.appBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Text("WEEKLY NUTRITION")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(WyldeStyles.Colors.bronze)
                    Spacer()
                    Button { showPreferences = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.secondaryText)
                            .frame(width: 36, height: 36)
                            .background(Theme.elevatedBG)
                            .clipShape(Circle())
                    }
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

                // Tab picker
                tabPicker
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                if service.isGenerating {
                    generatingView
                } else if service.plan == nil && !isBuilding {
                    emptyState
                } else {
                    switch selectedTab {
                    case .plan:
                        if isBuilding {
                            manualBuilderView
                        } else {
                            planView
                        }
                    case .recipes: recipeBookView
                    case .groceries: groceryView
                    }
                }
            }
        }
        .sheet(isPresented: $showRecipePicker) {
            recipePickerSheet
        }
        .fullScreenCover(isPresented: $showPreferences) {
            NutritionPreferencesView().environmentObject(appState)
        }
        .sheet(isPresented: $showMealDetail) {
            if let mealId = detailMealId {
                MealDetailView(dayId: detailDayId, mealId: mealId)
                    .environmentObject(appState)
            }
        }
        .alert("Replace current plan?", isPresented: $showReplaceConfirm) {
            Button("Replace", role: .destructive) {
                pendingReplaceAction?()
                pendingReplaceAction = nil
            }
            Button("Cancel", role: .cancel) {
                pendingReplaceAction = nil
            }
        } message: {
            Text("You have completed meals, edits, or checked grocery items. Replacing will lose this progress.")
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.3)
                        .foregroundColor(selectedTab == tab ? Theme.primaryText : Theme.tertiaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == tab ? Theme.chipBG : .clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.elevatedBG)
        .clipShape(Capsule())
    }

    // MARK: - Empty State (Choice)

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "fork.knife")
                .font(.system(size: 44))
                .foregroundColor(WyldeStyles.Colors.bronze.opacity(0.5))

            Text("Your Weekly Meal Plan")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(Theme.primaryText)

            Text("Let AI build your plan, or choose your own meals from the recipe book.")
                .font(.system(size: 14))
                .foregroundColor(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // AI Generate
            GoldButton(label: "Generate with AI") {
                Task { await service.generatePlan(appState: appState) }
            }
            .padding(.horizontal, 40)

            // Manual Build
            Button {
                startManualBuild()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 14))
                    Text("Build My Own Plan")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(WyldeStyles.Colors.bronze)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(WyldeStyles.Colors.bronze.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(WyldeStyles.Colors.bronze.opacity(0.3), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Generating

    private var generatingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().tint(WyldeStyles.Colors.bronze).scaleEffect(1.2)
            Text("Building your meal plan...")
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundColor(Theme.primaryText)
            Text("Recipes, macros, and grocery list")
                .font(.system(size: 13))
                .foregroundColor(Theme.secondaryText)
            Spacer()
        }
    }

    // MARK: - Manual Builder

    private func startManualBuild() {
        buildDays = dayNames.map { day in
            DayMealPlan(id: day.lowercased(), dayName: day, meals: [])
        }
        buildingDayIndex = 0
        isBuilding = true
        selectedTab = .plan
    }

    private var manualBuilderView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Day selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { i in
                            buildDayTab(index: i)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 12)

                // Macro meter for current day
                let day = buildDays[buildingDayIndex]
                macroMeter(for: day)
                    .padding(.horizontal, 20)

                // Current day's selected meals
                if day.meals.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.dashed")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.tertiaryText)
                        Text("Add meals for \(day.dayName)")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(day.meals) { meal in
                        buildMealCard(meal)
                            .padding(.horizontal, 20)
                    }
                }

                // Add meal buttons
                VStack(spacing: 8) {
                    let types: [MealType] = [.breakfast, .lunch, .dinner, .snack]
                    ForEach(types, id: \.self) { type in
                        let hasType = day.meals.contains { $0.mealType == type }
                        if !hasType || type == .snack {
                            Button {
                                pickerMealType = type
                                showRecipePicker = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14))
                                    Text("Add \(type.rawValue)")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(WyldeStyles.Colors.bronze)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(WyldeStyles.Colors.bronze.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Copy previous day
                if buildingDayIndex > 0 {
                    Button {
                        copyPreviousDay()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                            Text("Copy from \(dayNames[buildingDayIndex - 1])")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 4)
                }

                // Save plan button
                let filledDays = buildDays.filter { !$0.meals.isEmpty }.count
                if filledDays >= 1 {
                    GoldButton(label: "Save Meal Plan (\(filledDays)/7 days)") {
                        saveManualPlan()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }

                // Cancel
                Button {
                    isBuilding = false
                } label: {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.tertiaryText)
                }
                .padding(.top, 4)

                Spacer().frame(height: 100)
            }
        }
    }

    private func buildDayTab(index: Int) -> some View {
        let day = buildDays[index]
        let isSelected = buildingDayIndex == index
        let mealCount = day.meals.count

        return Button { buildingDayIndex = index } label: {
            VStack(spacing: 4) {
                Text(String(day.dayName.prefix(3)))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? WyldeStyles.Colors.bronze : Theme.secondaryText)
                if mealCount > 0 {
                    Text("\(mealCount)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(WyldeStyles.Colors.sage)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.tertiaryText)
                }
            }
            .frame(width: 48, height: 48)
            .background(isSelected ? WyldeStyles.Colors.bronze.opacity(0.10) : Theme.elevatedBG)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Macro Meter

    private func macroMeter(for day: DayMealPlan) -> some View {
        let calGoal = appState.caloriesGoal
        let protGoal = appState.proteinGoal
        let carbGoal = appState.carbsGoal
        let fatGoal = appState.fatGoal

        let totalCal = day.meals.reduce(0) { $0 + $1.calories }
        let totalProt = day.meals.reduce(0) { $0 + $1.protein }
        let totalCarb = day.meals.reduce(0) { $0 + $1.carbs }
        let totalFat = day.meals.reduce(0) { $0 + $1.fat }

        return VStack(spacing: 10) {
            Text("\(day.dayName.uppercased()) MACROS")
                .font(.system(size: 9, weight: .bold))
                .tracking(2)
                .foregroundColor(Theme.tertiaryText)

            HStack(spacing: 0) {
                macroBar(label: "Cal", current: totalCal, goal: calGoal, color: WyldeStyles.Colors.bronze)
                macroBar(label: "Protein", current: totalProt, goal: protGoal, color: WyldeStyles.Colors.vitalTeal, unit: "g")
                macroBar(label: "Carbs", current: totalCarb, goal: carbGoal, color: WyldeStyles.Colors.vitalOrange, unit: "g")
                macroBar(label: "Fat", current: totalFat, goal: fatGoal, color: WyldeStyles.Colors.vitalPurple, unit: "g")
            }
        }
        .padding(14)
        .background(Theme.elevatedBG)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func macroBar(label: String, current: Int, goal: Int, color: Color, unit: String = "") -> some View {
        let progress = goal > 0 ? min(1.0, CGFloat(current) / CGFloat(goal)) : 0
        let isOver = current > goal && goal > 0

        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 3.5)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(isOver ? .red.opacity(0.8) : color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                Text("\(current)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isOver ? .red.opacity(0.8) : Theme.primaryText)
            }
            Text("\(label)")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Theme.tertiaryText)
            Text("\(goal)\(unit)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Theme.tertiaryText.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private func buildMealCard(_ meal: PlannedMeal) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.mealType.rawValue)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(WyldeStyles.Colors.bronze)
                Text(meal.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                Text("\(meal.calories) cal · \(meal.protein)g P · \(meal.carbs)g C · \(meal.fat)g F")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.tertiaryText)
            }
            Spacer()
            Button {
                removeMealFromBuild(meal)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.tertiaryText)
            }
        }
        .padding(12)
        .background(Theme.elevatedBG)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func removeMealFromBuild(_ meal: PlannedMeal) {
        buildDays[buildingDayIndex].meals.removeAll { $0.id == meal.id }
    }

    private func copyPreviousDay() {
        let previous = buildDays[buildingDayIndex - 1]
        let copied = previous.meals.map { m in
            PlannedMeal(mealType: m.mealType, name: m.name, description: m.description, ingredients: m.ingredients, instructions: m.instructions, prepTime: m.prepTime, calories: m.calories, protein: m.protein, carbs: m.carbs, fat: m.fat)
        }
        buildDays[buildingDayIndex].meals = copied
    }

    private func saveManualPlan() {
        service.buildManualPlan(
            days: buildDays,
            goal: appState.goals.first ?? "Custom plan"
        )
        isBuilding = false
    }

    // MARK: - Recipe Picker Sheet

    private var recipePickerSheet: some View {
        NavigationView {
            ZStack {
                Theme.appBG.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Show macro status for current day
                        let day = buildDays[buildingDayIndex]
                        macroMeter(for: day)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        let recipes = recipeBook.recipes(for: pickerMealType)
                        ForEach(recipes) { recipe in
                            Button {
                                addRecipeToBuild(recipe)
                                showRecipePicker = false
                            } label: {
                                recipePickerCard(recipe)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }

                        Spacer().frame(height: 40)
                    }
                }
            }
            .navigationTitle("Choose \(pickerMealType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showRecipePicker = false }
                        .foregroundColor(WyldeStyles.Colors.bronze)
                }
            }
        }
    }

    private func recipePickerCard(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recipe.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                Spacer()
                Text("\(recipe.prepTime) min")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.tertiaryText)
            }

            if !recipe.description.isEmpty {
                Text(recipe.description)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.secondaryText)
            }

            HStack(spacing: 12) {
                macroChip(label: "\(recipe.calories) cal", color: WyldeStyles.Colors.bronze)
                macroChip(label: "\(recipe.protein)g P", color: WyldeStyles.Colors.vitalTeal)
                macroChip(label: "\(recipe.carbs)g C", color: WyldeStyles.Colors.vitalOrange)
                macroChip(label: "\(recipe.fat)g F", color: WyldeStyles.Colors.vitalPurple)
                Spacer()
            }

            if !recipe.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(recipe.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Theme.tertiaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.chipBG)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.elevatedBG)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.primaryText.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func macroChip(label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(color)
    }

    private func addRecipeToBuild(_ recipe: Recipe) {
        buildDays[buildingDayIndex].meals.append(recipe.toPlannedMeal())
    }

    private func confirmReplace(_ action: @escaping () -> Void) {
        if service.planHasActiveEdits {
            pendingReplaceAction = action
            showReplaceConfirm = true
        } else {
            action()
        }
    }

    private func openMealDetail(dayId: String, mealId: UUID) {
        detailDayId = dayId
        detailMealId = mealId
        showMealDetail = true
    }

    // MARK: - Recipe Book View (Browse Only)

    private var recipeBookView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Create recipe button
                Button { showCreateRecipe = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create Your Own Recipe")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Add your favorites to the recipe book")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.tertiaryText)
                    }
                    .foregroundColor(WyldeStyles.Colors.bronze)
                    .padding(14)
                    .background(WyldeStyles.Colors.bronze.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(WyldeStyles.Colors.bronze.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)

                // Saved recipes section
                if !recipeBook.savedRecipes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("MY RECIPES")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(WyldeStyles.Colors.vitalTeal)
                            Spacer()
                            Text("\(recipeBook.savedRecipes.count)")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(Theme.tertiaryText)
                        }
                        .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(recipeBook.savedRecipes) { recipe in
                                    savedRecipeCard(recipe)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                // If no plan yet, prompt to build
                if service.plan == nil && !isBuilding {
                    HStack(spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 14))
                            .foregroundColor(WyldeStyles.Colors.vitalOrange)
                        Text("Browse recipes below, or tap \"Build My Own Plan\" to pick meals for each day with macro tracking.")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(14)
                    .background(Theme.elevatedBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                }

                // Built-in recipes by meal type
                let mealTypes: [MealType] = [.breakfast, .lunch, .dinner, .snack]
                ForEach(mealTypes, id: \.self) { type in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(type.rawValue.uppercased() + "S")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(WyldeStyles.Colors.bronze)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(recipeBook.builtInRecipes(for: type)) { recipe in
                                    recipeCard(recipe)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                Spacer().frame(height: 100)
            }
            .padding(.top, 12)
        }
        .fullScreenCover(isPresented: $showCreateRecipe) {
            CreateRecipeView()
        }
        .fullScreenCover(item: $editingRecipe) { recipe in
            CreateRecipeView(editingRecipe: recipe)
        }
    }

    private func savedRecipeCard(_ recipe: Recipe) -> some View {
        Button {
            editingRecipe = recipe
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(recipe.mealType.rawValue)
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundColor(WyldeStyles.Colors.vitalTeal)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(WyldeStyles.Colors.vitalTeal.opacity(0.12))
                        .clipShape(Capsule())
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.tertiaryText)
                }

                Text(recipe.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    if recipe.calories > 0 {
                        Text("\(recipe.calories) cal")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(WyldeStyles.Colors.bronze)
                    }
                    Text("\(recipe.protein)g P · \(recipe.carbs)g C · \(recipe.fat)g F")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Theme.tertiaryText)
                }
            }
            .padding(14)
            .frame(width: 170, height: 160, alignment: .topLeading)
            .background(Theme.elevatedBG)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(WyldeStyles.Colors.vitalTeal.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func recipeCard(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.primaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !recipe.description.isEmpty {
                Text(recipe.description)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text("\(recipe.calories) cal")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(WyldeStyles.Colors.bronze)
                Text("\(recipe.protein)g P · \(recipe.carbs)g C · \(recipe.fat)g F")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.tertiaryText)
            }

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                Text("\(recipe.prepTime) min")
                    .font(.system(size: 10))
            }
            .foregroundColor(Theme.tertiaryText)
        }
        .padding(14)
        .frame(width: 170, height: 160, alignment: .topLeading)
        .background(Theme.elevatedBG)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.primaryText.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Plan View (existing plan)

    private var planView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                // Source badge
                if let plan = service.plan {
                    HStack(spacing: 6) {
                        Image(systemName: plan.source == .ai ? "wand.and.stars" : "hand.raised.fill")
                            .font(.system(size: 10))
                        Text(plan.source == .ai ? "AI-Generated Plan" : "Custom Plan")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(Theme.tertiaryText)
                    .padding(.top, 8)
                }

                // Day selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(service.plan?.days ?? [], id: \.id) { day in
                            dayTab(day)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 4)

                // Selected day's meals
                if let dayId = selectedDay ?? service.todaysMeals()?.id,
                   let day = service.plan?.days.first(where: { $0.id == dayId }) {

                    // Daily totals
                    HStack(spacing: 0) {
                        miniMacro(label: "Cal", value: "\(day.totalCalories)")
                        miniMacro(label: "Protein", value: "\(day.totalProtein)g")
                        miniMacro(label: "Carbs", value: "\(day.totalCarbs)g")
                        miniMacro(label: "Fat", value: "\(day.totalFat)g")
                    }
                    .background(Theme.elevatedBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)

                    // Meals
                    ForEach(day.meals) { meal in
                        mealCard(meal, dayId: day.id)
                            .padding(.horizontal, 20)
                    }

                    // Regenerate day
                    if service.isRegeneratingDay {
                        HStack(spacing: 8) {
                            ProgressView().tint(WyldeStyles.Colors.bronze)
                            Text("Regenerating \(day.dayName)...")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.secondaryText)
                        }
                        .padding(.top, 8)
                    } else {
                        Button {
                            Task {
                                await service.regenerateDay(dayId: dayId, appState: appState)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11))
                                Text("Regenerate \(day.dayName)")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(WyldeStyles.Colors.bronze)
                        }
                        .padding(.top, 4)

                        let lockedCount = day.meals.filter(\.isLocked).count
                        if lockedCount > 0 {
                            Text("\(lockedCount) meal\(lockedCount > 1 ? "s" : "") locked — won't change")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.tertiaryText)
                        }
                    }
                }

                // Actions
                HStack(spacing: 16) {
                    Button {
                        confirmReplace {
                            service.resetPlan()
                            Task { await service.generatePlan(appState: appState) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 11))
                            Text("New AI plan")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Theme.secondaryText)
                    }

                    Button {
                        confirmReplace {
                            service.resetPlan()
                            startManualBuild()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 11))
                            Text("Build my own")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Theme.secondaryText)
                    }
                }
                .padding(.top, 12)

                Spacer().frame(height: 100)
            }
        }
    }

    private func dayTab(_ day: DayMealPlan) -> some View {
        let isToday = day.id == (service.todaysMeals()?.id ?? "")
        let isSelected = (selectedDay ?? service.todaysMeals()?.id) == day.id
        let completedCount = day.meals.filter(\.completed).count

        return Button { selectedDay = day.id } label: {
            VStack(spacing: 4) {
                Text(String(day.dayName.prefix(3)))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? WyldeStyles.Colors.bronze : Theme.secondaryText)
                if completedCount == day.meals.count && !day.meals.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(WyldeStyles.Colors.sage)
                } else {
                    Text("\(completedCount)/\(day.meals.count)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Theme.tertiaryText)
                }
            }
            .frame(width: 48, height: 48)
            .background(isSelected ? WyldeStyles.Colors.bronze.opacity(0.10) : Theme.elevatedBG)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isToday ? WyldeStyles.Colors.bronze.opacity(0.3) : .clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func mealCard(_ meal: PlannedMeal, dayId: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — tap to toggle complete
            HStack(spacing: 12) {
                Button {
                    service.toggleMeal(dayId: dayId, mealId: meal.id)
                } label: {
                    Image(systemName: meal.completed ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(meal.completed ? WyldeStyles.Colors.sage : Theme.tertiaryText)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)

                Button {
                    openMealDetail(dayId: dayId, mealId: meal.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(meal.mealType.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(WyldeStyles.Colors.bronze)
                            if meal.isSwapped {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 8))
                                    .foregroundColor(WyldeStyles.Colors.vitalTeal)
                            }
                        }
                        Text(meal.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(meal.completed ? Theme.tertiaryText : Theme.primaryText)
                            .strikethrough(meal.completed, color: Theme.tertiaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        if meal.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red.opacity(0.6))
                        }
                        if meal.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(WyldeStyles.Colors.bronze.opacity(0.6))
                        }
                        Text("\(meal.calories) cal")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Theme.secondaryText)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.tertiaryText)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(14)

            // Identity reason (if present)
            if !meal.identityReason.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundColor(WyldeStyles.Colors.bronze.opacity(0.6))
                    Text(meal.identityReason)
                        .font(.system(size: 10, design: .serif))
                        .foregroundColor(Theme.tertiaryText)
                        .italic()
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }

            // Macro summary
            HStack {
                Text("\(meal.protein)g P · \(meal.carbs)g C · \(meal.fat)g F · \(meal.prepTime) min")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.tertiaryText)
                Spacer()
                if !meal.dietaryTags.isEmpty {
                    Text(meal.dietaryTags.prefix(2).joined(separator: " · "))
                        .font(.system(size: 9))
                        .foregroundColor(Theme.tertiaryText.opacity(0.7))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(Theme.elevatedBG)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(meal.isLocked ? WyldeStyles.Colors.bronze.opacity(0.15) : Theme.primaryText.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func miniMacro(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(WyldeStyles.Colors.bronze)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Grocery View

    @State private var showCreateRecipe = false
    @State private var editingRecipe: Recipe? = nil
    @State private var showAddItem = false
    @State private var newItemName = ""
    @State private var newItemCategory = "Other"
    @State private var showShareSheet = false

    private var groceryView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if service.plan == nil {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 40)
                        Image(systemName: "cart")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.tertiaryText)
                        Text("Generate or build a meal plan to see your weekly grocery list")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                } else {
                    // Header with progress
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "cart.fill")
                                .font(.system(size: 12))
                            Text("WEEKLY GROCERY LIST")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                        }
                        .foregroundColor(WyldeStyles.Colors.bronze)

                        Spacer()

                        let progress = service.groceryProgress
                        if progress.total > 0 {
                            Text("\(progress.checked)/\(progress.total)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(progress.checked == progress.total ? WyldeStyles.Colors.sage : Theme.secondaryText)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Action bar
                    HStack(spacing: 10) {
                        Button {
                            showAddItem = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 12))
                                Text("Add item")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(WyldeStyles.Colors.bronze)
                        }

                        Spacer()

                        Button {
                            service.regenerateGroceryList()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10))
                                Text("Refresh")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(Theme.secondaryText)
                        }

                        Button {
                            shareGroceryList()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 10))
                                Text("Share")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(Theme.secondaryText)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Sections
                    ForEach(service.plan?.groceryList ?? []) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(section.category.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(2)
                                    .foregroundColor(WyldeStyles.Colors.bronze)
                                Spacer()
                                let sectionChecked = section.items.filter(\.checked).count
                                if sectionChecked > 0 {
                                    Text("\(sectionChecked)/\(section.items.count)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(Theme.tertiaryText)
                                }
                            }

                            ForEach(section.items) { item in
                                groceryItemRow(item: item, sectionId: section.id)
                            }
                        }
                        .padding(14)
                        .background(Theme.elevatedBG)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .alert("Add Grocery Item", isPresented: $showAddItem) {
            TextField("Item name", text: $newItemName)
            Button("Add") {
                service.addCustomGroceryItem(name: newItemName, category: newItemCategory)
                newItemName = ""
            }
            Button("Cancel", role: .cancel) { newItemName = "" }
        } message: {
            Text("Add a custom item to your grocery list.")
        }
    }

    private func groceryItemRow(item: GroceryItem, sectionId: UUID) -> some View {
        HStack(spacing: 10) {
            // Checkbox
            Button {
                service.toggleGrocery(sectionId: sectionId, itemId: item.id)
            } label: {
                Image(systemName: item.checked ? "checkmark.square.fill" : "square")
                    .foregroundColor(item.checked ? WyldeStyles.Colors.sage : Theme.tertiaryText)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)

            // Item info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 14))
                        .foregroundColor(item.checked ? Theme.tertiaryText : Theme.primaryText)
                        .strikethrough(item.checked, color: Theme.tertiaryText)

                    if item.isPantryItem {
                        Text("PANTRY")
                            .font(.system(size: 7, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(WyldeStyles.Colors.bronze)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(WyldeStyles.Colors.bronze.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    if item.isCustom {
                        Text("ADDED")
                            .font(.system(size: 7, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(WyldeStyles.Colors.vitalTeal)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(WyldeStyles.Colors.vitalTeal.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }

                // Source meals
                if !item.sourceMealNames.isEmpty {
                    Text(item.sourceMealNames.prefix(2).joined(separator: ", "))
                        .font(.system(size: 9))
                        .foregroundColor(Theme.tertiaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Quantity
            if !item.quantity.isEmpty {
                Text(item.quantity)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.secondaryText)
            }

            // Context menu trigger
            Menu {
                Button {
                    service.togglePantryItem(sectionId: sectionId, itemId: item.id)
                } label: {
                    Label(
                        item.isPantryItem ? "Unmark as Pantry" : "I Already Have This",
                        systemImage: item.isPantryItem ? "house" : "house.fill"
                    )
                }

                Button(role: .destructive) {
                    service.removeGroceryItem(sectionId: sectionId, itemId: item.id)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.tertiaryText)
                    .frame(width: 24, height: 24)
            }
        }
    }

    private func shareGroceryList() {
        guard let plan = service.plan else { return }
        var text = "🛒 Wylde Self — Weekly Grocery List\n\n"
        for section in plan.groceryList {
            text += "\(section.category.uppercased())\n"
            for item in section.items {
                let check = item.checked ? "✓" : "○"
                let qty = item.quantity.isEmpty ? "" : " — \(item.quantity)"
                text += "\(check) \(item.name)\(qty)\n"
            }
            text += "\n"
        }

        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(av, animated: true)
        }
    }
}
