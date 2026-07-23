import SwiftUI

struct MealDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = MealPlanService.shared
    @Environment(\.dismiss) private var dismiss

    let dayId: String
    let mealId: UUID

    @State private var showSwapConfirm = false

    private var meal: PlannedMeal? {
        service.plan?.days.first(where: { $0.id == dayId })?.meals.first(where: { $0.id == mealId })
    }

    var body: some View {
        ZStack {
            Theme.appBG.ignoresSafeArea()

            if let meal = meal {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        headerSection(meal)

                        // Identity reason
                        if !meal.identityReason.isEmpty {
                            identitySection(meal)
                        }

                        // Macros
                        macroSection(meal)

                        // Tags
                        if !meal.dietaryTags.isEmpty {
                            tagsSection(meal)
                        }

                        // Ingredients
                        if !meal.ingredients.isEmpty {
                            ingredientsSection(meal)
                        }

                        // Instructions
                        if !meal.instructions.isEmpty {
                            instructionsSection(meal)
                        }

                        // Actions
                        actionsSection(meal)

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(Theme.elevatedBG)
                    .clipShape(Circle())
            }
            .padding(.trailing, 20)
            .padding(.top, 16)
        }
        .alert("Swap this meal?", isPresented: $showSwapConfirm) {
            Button("Swap", role: .destructive) {
                Task { await service.swapMeal(dayId: dayId, mealId: mealId, appState: appState) }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("AI will generate a new meal with the same type and your dietary preferences.")
        }
    }

    // MARK: - Header

    private func headerSection(_ meal: PlannedMeal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(meal.mealType.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(WyldeStyles.Colors.bronze)

                if meal.isSwapped {
                    Text("SWAPPED")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundColor(WyldeStyles.Colors.vitalTeal)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(WyldeStyles.Colors.vitalTeal.opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer()

                if meal.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(WyldeStyles.Colors.bronze)
                }
            }

            Text(meal.name)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(Theme.primaryText)

            if !meal.description.isEmpty {
                Text(meal.description)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.secondaryText)
            }

            HStack(spacing: 12) {
                Label("\(meal.prepTime) min", systemImage: "clock")
                Label("\(meal.servings) serving\(meal.servings > 1 ? "s" : "")", systemImage: "person")
            }
            .font(.system(size: 12))
            .foregroundColor(Theme.tertiaryText)
        }
    }

    // MARK: - Identity

    private func identitySection(_ meal: PlannedMeal) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(WyldeStyles.Colors.bronze)
            Text(meal.identityReason)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundColor(Theme.primaryText)
                .italic()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WyldeStyles.Colors.bronze.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Macros

    private func macroSection(_ meal: PlannedMeal) -> some View {
        HStack(spacing: 0) {
            macroCell(value: "\(meal.calories)", label: "Cal", color: WyldeStyles.Colors.bronze)
            macroCell(value: "\(meal.protein)g", label: "Protein", color: WyldeStyles.Colors.vitalTeal)
            macroCell(value: "\(meal.carbs)g", label: "Carbs", color: WyldeStyles.Colors.vitalOrange)
            macroCell(value: "\(meal.fat)g", label: "Fat", color: WyldeStyles.Colors.vitalPurple)
        }
        .padding(.vertical, 14)
        .background(Theme.elevatedBG)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func macroCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tags

    private func tagsSection(_ meal: PlannedMeal) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(meal.dietaryTags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.chipBG)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Ingredients

    private func ingredientsSection(_ meal: PlannedMeal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INGREDIENTS")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(Theme.tertiaryText)

            ForEach(meal.ingredients, id: \.self) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(WyldeStyles.Colors.bronze.opacity(0.4))
                        .frame(width: 5, height: 5)
                    Text(item)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.primaryText)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.elevatedBG)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Instructions

    private func instructionsSection(_ meal: PlannedMeal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW TO MAKE")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(Theme.tertiaryText)

            ForEach(Array(meal.instructions.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(WyldeStyles.Colors.bronze)
                        .frame(width: 20)
                    Text(step)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.primaryText)
                        .lineSpacing(3)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.elevatedBG)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Actions

    private func actionsSection(_ meal: PlannedMeal) -> some View {
        VStack(spacing: 10) {
            // Complete
            Button {
                service.toggleMeal(dayId: dayId, mealId: mealId)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: meal.completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                    Text(meal.completed ? "Completed" : "Mark as Eaten")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(meal.completed ? WyldeStyles.Colors.sage : Theme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(meal.completed ? WyldeStyles.Colors.sage.opacity(0.10) : Theme.elevatedBG)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 10) {
                // Swap
                Button {
                    if meal.isLocked {
                        return
                    }
                    showSwapConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12))
                        Text("Swap")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(meal.isLocked ? Theme.tertiaryText : Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.elevatedBG)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(meal.isLocked)

                // Lock
                Button {
                    service.toggleLock(dayId: dayId, mealId: mealId)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: meal.isLocked ? "lock.fill" : "lock.open")
                            .font(.system(size: 12))
                        Text(meal.isLocked ? "Locked" : "Lock")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(meal.isLocked ? WyldeStyles.Colors.bronze : Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.elevatedBG)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Favorite
                Button {
                    service.toggleFavorite(dayId: dayId, mealId: mealId)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: meal.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 12))
                        Text(meal.isFavorite ? "Saved" : "Save")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(meal.isFavorite ? .red.opacity(0.7) : Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.elevatedBG)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            if service.isSwapping {
                HStack(spacing: 8) {
                    ProgressView().tint(WyldeStyles.Colors.bronze)
                    Text("Finding a replacement...")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.secondaryText)
                }
                .padding(.top, 8)
            }
        }
    }
}
