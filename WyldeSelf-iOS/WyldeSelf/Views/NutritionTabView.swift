import SwiftUI

struct NutritionTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var tracker = MacroTrackerService.shared
    @StateObject private var mealService = MealPlanService.shared
    @StateObject private var prefsService = NutritionPreferencesService.shared
    @State private var showFoodScanner = false
    @State private var showFoodSearch = false
    @State private var showMealPlan = false
    @State private var showVoiceLog = false
    @State private var showPreferences = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Text("Nutrition")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Theme.text)
                        Spacer()
                        Button { showPreferences = true } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.muted)
                        }
                    }
                    .padding(.top, 60)
                    .onAppear {
                        #if DEBUG
                        print("[NutritionTab] View appeared")
                        #endif
                    }

                    // Current dietary direction
                    if let framework = prefsService.preferences.dietaryFramework {
                        HStack(spacing: 6) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 10))
                                .foregroundColor(WyldeStyles.Colors.sage)
                            Text(framework.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.text)
                            if let cal = prefsService.preferences.calorieTarget {
                                Text("· \(cal) cal target")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.muted)
                            }
                        }
                    }

                    // Log food actions — prominent
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        Button { showVoiceLog = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 20))
                                Text("Voice Log")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(WyldeStyles.Colors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(WyldeStyles.Colors.bronze)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button { showFoodSearch = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 20))
                                Text("Search Food")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(WyldeStyles.Colors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(WyldeStyles.Colors.vitalTeal.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button { showFoodScanner = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20))
                                Text("Snap Meal")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(WyldeStyles.Colors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(WyldeStyles.Colors.vitalOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button { showMealPlan = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 20))
                                Text("Meal Plan")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(WyldeStyles.Colors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(WyldeStyles.Colors.vitalPurple)
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
                            macroRing(label: "Calories", current: appState.caloriesLogged, goal: appState.caloriesGoal, unit: "", color: WyldeStyles.Colors.bronze)
                            macroRing(label: "Protein", current: appState.proteinLogged, goal: appState.proteinGoal, unit: "g", color: WyldeStyles.Colors.vitalTeal)
                            macroRing(label: "Carbs", current: appState.carbsLogged, goal: appState.carbsGoal, unit: "g", color: WyldeStyles.Colors.vitalOrange)
                            macroRing(label: "Fat", current: appState.fatLogged, goal: appState.fatGoal, unit: "g", color: WyldeStyles.Colors.vitalPurple)
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
                                        .foregroundColor(WyldeStyles.Colors.vitalOrange)
                                    Text("TODAY'S MEAL PLAN")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(2)
                                        .foregroundColor(WyldeStyles.Colors.vitalOrange)
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
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(WyldeStyles.Colors.vitalOrange.opacity(0.15), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }

                    // History
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RECENT HISTORY")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Theme.muted)

                        let historyDates = tracker.datesWithData(last: 14).filter {
                            Calendar.current.isDateInToday($0) == false
                        }

                        if historyDates.isEmpty {
                            Text("Log meals to build your nutrition history")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.muted.opacity(0.7))
                        } else {
                            ForEach(historyDates.prefix(7), id: \.self) { date in
                                let summary = tracker.summaryForDate(date)
                                let meals = tracker.mealsForDate(date)
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formatHistoryDate(date))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Theme.text)
                                        Text("\(meals.count) meals")
                                            .font(.system(size: 10))
                                            .foregroundColor(Theme.muted)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(summary.calories) cal")
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundColor(WyldeStyles.Colors.bronze)
                                        Text("\(summary.protein)g P · \(summary.carbs)g C · \(summary.fat)g F")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(Theme.muted)
                                    }
                                }
                                .padding(12)
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, Theme.screenPadding)
            }
        }
        .fullScreenCover(isPresented: $showVoiceLog) {
            VoiceFoodLogView().environmentObject(appState)
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
        .fullScreenCover(isPresented: $showPreferences) {
            NutritionPreferencesView().environmentObject(appState)
        }
    }

    private func formatHistoryDate(_ date: Date) -> String {
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
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
