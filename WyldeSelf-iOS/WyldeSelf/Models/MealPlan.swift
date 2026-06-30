import Foundation

struct WeeklyMealPlan: Codable {
    var days: [DayMealPlan]
    var groceryList: [GrocerySection]
    let generatedAt: Date
    let goal: String
}

struct DayMealPlan: Identifiable, Codable {
    let id: String  // "monday", "tuesday", etc.
    let dayName: String
    var meals: [PlannedMeal]

    var totalCalories: Int { meals.reduce(0) { $0 + $1.calories } }
    var totalProtein: Int { meals.reduce(0) { $0 + $1.protein } }
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

    init(mealType: MealType, name: String, description: String = "", ingredients: [String] = [], instructions: [String] = [], prepTime: Int = 15, calories: Int, protein: Int, carbs: Int, fat: Int) {
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
    let quantity: String
    var checked: Bool

    init(name: String, quantity: String) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.checked = false
    }
}
