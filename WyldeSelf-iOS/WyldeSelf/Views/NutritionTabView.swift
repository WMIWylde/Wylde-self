import SwiftUI

struct NutritionTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var tracker = MacroTrackerService.shared
    @StateObject private var mealService = MealPlanService.shared
    @State private var showFoodScanner = false
    @State private var showFoodSearch = false
    @State private var showMealPlan = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    Text("Nutrition")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Theme.text)
                        .padding(.top, 60)

                    // Log food actions — prominent
                    HStack(spacing: 10) {
                        Button { showFoodSearch = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 20))
                                Text("Search Food")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: "F4F1E8"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color(hex: "5EE6D6").opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button { showFoodScanner = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20))
                                Text("Snap Meal")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: "F4F1E8"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color(hex: "C8A96E"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button { showMealPlan = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 20))
                                Text("Meal Plan")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: "F4F1E8"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color(hex: "FF9A3C"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    // Today's macros
                    VStack(alignment: .leading, spacing: 14) {
                        Text("TODAY'S MACROS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Theme.muted)

                        HStack(spacing: 0) {
                            macroRing(label: "Calories", current: appState.caloriesLogged, goal: appState.caloriesGoal, unit: "", color: Color(hex: "C8A96E"))
                            macroRing(label: "Protein", current: appState.proteinLogged, goal: appState.proteinGoal, unit: "g", color: Color(hex: "5EE6D6"))
                            macroRing(label: "Carbs", current: appState.carbsLogged, goal: appState.carbsGoal, unit: "g", color: Color(hex: "FF9A3C"))
                            macroRing(label: "Fat", current: appState.fatLogged, goal: appState.fatGoal, unit: "g", color: Color(hex: "B68BFF"))
                        }

                        if appState.caloriesBurned > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red.opacity(0.7))
                                Text("\(appState.caloriesBurned) cal burned")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Theme.muted)
                                Spacer()
                                Text("Net: \(appState.caloriesLogged - appState.caloriesBurned) cal")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Theme.text)
                            }
                        }
                    }
                    .padding(20)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Today's logged meals
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TODAY'S LOG")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Theme.muted)

                        if tracker.todaysMeals.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 28))
                                    .foregroundColor(Theme.muted.opacity(0.5))
                                Text("No meals logged yet")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.muted)
                                Text("Search a food, snap a photo, or scan a barcode")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.muted.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        } else {
                            ForEach(tracker.todaysMeals) { meal in
                                HStack(spacing: 12) {
                                    Image(systemName: meal.logged ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(meal.logged ? Theme.sage : Theme.muted)
                                        .font(.system(size: 18))
                                        .onTapGesture { tracker.toggleMealLogged(meal.id) }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(meal.mealType.rawValue) — \(meal.name)")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Theme.text)
                                            .lineLimit(1)
                                        Text("\(meal.calories) cal · \(meal.protein)g P · \(meal.carbs)g C · \(meal.fat)g F")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(Theme.muted)
                                    }
                                    Spacer()
                                }
                                .padding(14)
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    // Meal plan preview
                    if let today = mealService.todaysMeals() {
                        Button { showMealPlan = true } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "FF9A3C"))
                                    Text("TODAY'S MEAL PLAN")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(2)
                                        .foregroundColor(Color(hex: "FF9A3C"))
                                    Spacer()
                                    let done = today.meals.filter(\.completed).count
                                    Text("\(done)/\(today.meals.count)")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundColor(Theme.muted)
                                }
                                ForEach(today.meals.prefix(3)) { meal in
                                    HStack(spacing: 6) {
                                        Image(systemName: meal.completed ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 12))
                                            .foregroundColor(meal.completed ? Theme.sage : Theme.muted)
                                        Text("\(meal.mealType.rawValue) — \(meal.name)")
                                            .font(.system(size: 12))
                                            .foregroundColor(meal.completed ? Theme.muted : Theme.text)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(16)
                            .background(Theme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "FF9A3C").opacity(0.15), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, Theme.screenPadding)
            }
        }
        .fullScreenCover(isPresented: $showFoodSearch) {
            FoodSearchView().environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showFoodScanner) {
            FoodScannerView().environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showMealPlan) {
            MealPlanView().environmentObject(appState)
        }
    }

    private func macroRing(label: String, current: Int, goal: Int, unit: String, color: Color) -> some View {
        let progress = goal > 0 ? min(1.0, CGFloat(current) / CGFloat(goal)) : 0
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 4)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: current)
                Text("\(current)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.text)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: current)
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}
