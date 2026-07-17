import SwiftUI

struct MealPlanView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = MealPlanService.shared
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable {
        case plan = "Meal Plan"
        case groceries = "Grocery List"
    }

    @State private var selectedTab: Tab = .plan
    @State private var selectedDay: String? = nil
    @State private var expandedMeal: UUID? = nil

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
                } else if service.plan == nil {
                    emptyState
                } else {
                    switch selectedTab {
                    case .plan: planView
                    case .groceries: groceryView
                    }
                }
            }
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
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.5)
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "fork.knife")
                .font(.system(size: 44))
                .foregroundColor(WyldeStyles.Colors.bronze.opacity(0.5))

            Text("Your Weekly Meal Plan")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(Theme.primaryText)

            Text("AI-built around your goals, dietary preferences, and macros.")
                .font(.system(size: 14))
                .foregroundColor(Theme.secondaryText)
                .multilineTextAlignment(.center)

            GoldButton(label: "Generate Meal Plan") {
                Task { await service.generatePlan(appState: appState) }
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

    // MARK: - Plan View

    private var planView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                // Day selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(service.plan?.days ?? [], id: \.id) { day in
                            dayTab(day)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 12)

                // Selected day's meals
                if let dayId = selectedDay ?? service.todaysMeals()?.id,
                   let day = service.plan?.days.first(where: { $0.id == dayId }) {

                    // Daily totals
                    HStack(spacing: 0) {
                        miniMacro(label: "Cal", value: "\(day.totalCalories)")
                        miniMacro(label: "Protein", value: "\(day.totalProtein)g")
                    }
                    .background(Theme.elevatedBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)

                    // Meals
                    ForEach(day.meals) { meal in
                        mealCard(meal, dayId: day.id)
                            .padding(.horizontal, 20)
                    }
                }

                // Regenerate
                Button {
                    service.resetPlan()
                    Task { await service.generatePlan(appState: appState) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                        Text("Generate new plan")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Theme.secondaryText)
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
            Button {
                service.toggleMeal(dayId: dayId, mealId: meal.id)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: meal.completed ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(meal.completed ? WyldeStyles.Colors.sage : Theme.tertiaryText)
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.mealType.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(WyldeStyles.Colors.bronze)
                        Text(meal.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(meal.completed ? Theme.tertiaryText : Theme.primaryText)
                            .strikethrough(meal.completed, color: Theme.tertiaryText)
                    }
                    Spacer()
                    Text("\(meal.calories) cal")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.secondaryText)
                }
            }
            .buttonStyle(.plain)
            .padding(14)

            // Expandable recipe
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedMeal = expandedMeal == meal.id ? nil : meal.id
                }
            } label: {
                HStack {
                    Text("\(meal.protein)g P · \(meal.carbs)g C · \(meal.fat)g F · \(meal.prepTime) min")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.tertiaryText)
                    Spacer()
                    Image(systemName: expandedMeal == meal.id ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.tertiaryText)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .buttonStyle(.plain)

            if expandedMeal == meal.id {
                VStack(alignment: .leading, spacing: 10) {
                    if !meal.ingredients.isEmpty {
                        Text("INGREDIENTS")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(Theme.tertiaryText)
                        ForEach(meal.ingredients, id: \.self) { item in
                            Text("· \(item)")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.secondaryText)
                        }
                    }
                    if !meal.instructions.isEmpty {
                        Text("HOW TO MAKE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(Theme.tertiaryText)
                            .padding(.top, 4)
                        ForEach(Array(meal.instructions.enumerated()), id: \.offset) { i, step in
                            Text("\(i + 1). \(step)")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.secondaryText)
                                .lineSpacing(2)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(Theme.elevatedBG)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.primaryText.opacity(0.06), lineWidth: 1)
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

    private var groceryView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(service.plan?.groceryList ?? []) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.category.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(WyldeStyles.Colors.bronze)

                        ForEach(section.items) { item in
                            Button {
                                service.toggleGrocery(sectionId: section.id, itemId: item.id)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: item.checked ? "checkmark.square.fill" : "square")
                                        .foregroundColor(item.checked ? WyldeStyles.Colors.sage : Theme.tertiaryText)
                                        .font(.system(size: 16))
                                    Text(item.name)
                                        .font(.system(size: 14))
                                        .foregroundColor(item.checked ? Theme.tertiaryText : Theme.primaryText)
                                        .strikethrough(item.checked, color: Theme.tertiaryText)
                                    Spacer()
                                    Text(item.quantity)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(Theme.secondaryText)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(Theme.elevatedBG)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }
}
