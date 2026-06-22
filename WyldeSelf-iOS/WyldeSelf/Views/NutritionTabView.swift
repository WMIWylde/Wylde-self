import SwiftUI

struct NutritionTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var tracker = MacroTrackerService.shared
    @State private var showFoodScanner = false
    @State private var showMealPlan = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nutrition")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Theme.text)
                            Text("Track your fuel")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.muted)
                        }
                        Spacer()
                    }
                    .padding(.top, 60)

                    // Quick actions
                    HStack(spacing: 10) {
                        Button { showFoodScanner = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14))
                                Text("Scan Meal")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: "1A1816"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "E6C886"), Color(hex: "A6834A")],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                        }

                        Button { showMealPlan = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                Text("Meal Plan")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(Theme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
                            macroRing(label: "Carbs", current: tracker.totalCarbs, goal: 250, unit: "g", color: Color(hex: "FF9A3C"))
                            macroRing(label: "Fat", current: tracker.totalFat, goal: 80, unit: "g", color: Color(hex: "B68BFF"))
                        }
                    }
                    .padding(20)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Today's meals
                    if !tracker.todaysMeals.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TODAY'S MEALS")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(Theme.muted)

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

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, Theme.screenPadding)
            }
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
