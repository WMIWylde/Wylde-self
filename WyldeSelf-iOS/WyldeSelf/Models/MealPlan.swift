import Foundation

enum MealPlanSource: String, Codable {
    case ai = "ai"
    case manual = "manual"
}

struct WeeklyMealPlan: Codable {
    var days: [DayMealPlan]
    var groceryList: [GrocerySection]
    let generatedAt: Date
    let goal: String
    var source: MealPlanSource

    init(days: [DayMealPlan], groceryList: [GrocerySection], generatedAt: Date, goal: String, source: MealPlanSource = .ai) {
        self.days = days
        self.groceryList = groceryList
        self.generatedAt = generatedAt
        self.goal = goal
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        days = try container.decode([DayMealPlan].self, forKey: .days)
        groceryList = try container.decode([GrocerySection].self, forKey: .groceryList)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        goal = try container.decode(String.self, forKey: .goal)
        source = try container.decodeIfPresent(MealPlanSource.self, forKey: .source) ?? .ai
    }
}

// MARK: - Recipe Book

struct Recipe: Identifiable, Codable {
    let id: UUID
    let mealType: MealType
    let name: String
    let description: String
    let ingredients: [String]
    let instructions: [String]
    let prepTime: Int
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let tags: [String] // e.g. "high-protein", "quick", "vegetarian"

    init(id: UUID = UUID(), mealType: MealType, name: String, description: String = "", ingredients: [String] = [], instructions: [String] = [], prepTime: Int = 15, calories: Int, protein: Int, carbs: Int, fat: Int, tags: [String] = []) {
        self.id = id
        self.mealType = mealType
        self.name = name
        self.description = description
        self.ingredients = ingredients
        self.instructions = instructions
        self.prepTime = prepTime
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.tags = tags
    }

    func toPlannedMeal() -> PlannedMeal {
        PlannedMeal(mealType: mealType, name: name, description: description, ingredients: ingredients, instructions: instructions, prepTime: prepTime, calories: calories, protein: protein, carbs: carbs, fat: fat, dietaryTags: tags)
    }
}

struct DayMealPlan: Identifiable, Codable {
    let id: String  // "monday", "tuesday", etc.
    let dayName: String
    var meals: [PlannedMeal]

    var totalCalories: Int { meals.reduce(0) { $0 + $1.calories } }
    var totalProtein: Int { meals.reduce(0) { $0 + $1.protein } }
    var totalCarbs: Int { meals.reduce(0) { $0 + $1.carbs } }
    var totalFat: Int { meals.reduce(0) { $0 + $1.fat } }
}

struct PlannedMeal: Identifiable, Codable {
    let id: UUID
    let mealType: MealType
    let name: String
    let description: String
    let ingredients: [String]
    let instructions: [String]
    let prepTime: Int  // minutes
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    var completed: Bool
    var identityReason: String
    var isSwapped: Bool
    var isLocked: Bool
    var isFavorite: Bool
    var servings: Int
    var dietaryTags: [String]

    init(mealType: MealType, name: String, description: String = "", ingredients: [String] = [], instructions: [String] = [], prepTime: Int = 15, calories: Int, protein: Int, carbs: Int, fat: Int, identityReason: String = "", dietaryTags: [String] = []) {
        self.id = UUID()
        self.mealType = mealType
        self.name = name
        self.description = description
        self.ingredients = ingredients
        self.instructions = instructions
        self.prepTime = prepTime
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.completed = false
        self.identityReason = identityReason
        self.isSwapped = false
        self.isLocked = false
        self.isFavorite = false
        self.servings = 1
        self.dietaryTags = dietaryTags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        mealType = try container.decode(MealType.self, forKey: .mealType)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        ingredients = try container.decode([String].self, forKey: .ingredients)
        instructions = try container.decode([String].self, forKey: .instructions)
        prepTime = try container.decode(Int.self, forKey: .prepTime)
        calories = try container.decode(Int.self, forKey: .calories)
        protein = try container.decode(Int.self, forKey: .protein)
        carbs = try container.decode(Int.self, forKey: .carbs)
        fat = try container.decode(Int.self, forKey: .fat)
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        identityReason = try container.decodeIfPresent(String.self, forKey: .identityReason) ?? ""
        isSwapped = try container.decodeIfPresent(Bool.self, forKey: .isSwapped) ?? false
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        servings = try container.decodeIfPresent(Int.self, forKey: .servings) ?? 1
        dietaryTags = try container.decodeIfPresent([String].self, forKey: .dietaryTags) ?? []
    }
}

struct GrocerySection: Identifiable, Codable {
    let id: UUID
    let category: String  // "Protein", "Produce", "Pantry", etc.
    var items: [GroceryItem]

    init(category: String, items: [GroceryItem]) {
        self.id = UUID()
        self.category = category
        self.items = items
    }
}

struct GroceryItem: Identifiable, Codable {
    let id: UUID
    let name: String
    var quantity: String
    var checked: Bool
    var isPantryItem: Bool
    var isCustom: Bool
    var sourceMealNames: [String]

    init(name: String, quantity: String, sourceMealNames: [String] = [], isCustom: Bool = false) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.checked = false
        self.isPantryItem = false
        self.isCustom = isCustom
        self.sourceMealNames = sourceMealNames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        quantity = try container.decode(String.self, forKey: .quantity)
        checked = try container.decodeIfPresent(Bool.self, forKey: .checked) ?? false
        isPantryItem = try container.decodeIfPresent(Bool.self, forKey: .isPantryItem) ?? false
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        sourceMealNames = try container.decodeIfPresent([String].self, forKey: .sourceMealNames) ?? []
    }
}
