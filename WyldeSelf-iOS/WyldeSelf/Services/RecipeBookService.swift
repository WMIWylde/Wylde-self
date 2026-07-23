import Foundation
import Supabase

// ════════════════════════════════════════════════════════════════════
//  Supabase row types — snake_case to match DB columns
// ════════════════════════════════════════════════════════════════════

private struct RecipeRow: Decodable {
    let id: UUID
    let user_id: String?
    let source: String
    let meal_type: String
    let name: String
    let description: String?
    let ingredients: [String]
    let instructions: [String]
    let prep_time: Int?
    let calories: Int?
    let protein: Int?
    let carbs: Int?
    let fat: Int?
    let tags: [String]?

    func toRecipe() -> Recipe? {
        guard let mealType = MealType(rawValue: meal_type.capitalized) else { return nil }
        return Recipe(
            id: id,
            mealType: mealType,
            name: name,
            description: description ?? "",
            ingredients: ingredients,
            instructions: instructions,
            prepTime: prep_time ?? 15,
            calories: calories ?? 0,
            protein: protein ?? 0,
            carbs: carbs ?? 0,
            fat: fat ?? 0,
            tags: tags ?? []
        )
    }
}

private struct SavedRecipeRow: Decodable {
    let recipe_id: UUID
}

private struct SavedRecipeInsert: Encodable {
    let user_id: String
    let recipe_id: UUID
}

private struct RecipeInsertRow: Encodable {
    let user_id: String
    let source: String
    let meal_type: String
    let name: String
    let description: String
    let ingredients: [String]
    let instructions: [String]
    let prep_time: Int
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let tags: [String]
}

@MainActor
final class RecipeBookService: ObservableObject {
    static let shared = RecipeBookService()

    /// Built-in recipes (from Supabase, falls back to hardcoded)
    @Published var builtInRecipes: [Recipe] = []
    /// User-created or AI-generated recipes
    @Published var savedRecipes: [Recipe] = []
    /// IDs of recipes the user has saved/favorited
    @Published var savedRecipeIDs: Set<UUID> = []
    @Published var isLoading = false

    private let storageKey = "wylde_saved_recipes"
    private let builtInCacheKey = "wylde_builtin_recipes_cache"
    private let secure = SecureStorage.shared

    private init() {
        // Load local cache immediately for instant UI
        loadLocalCache()
        loadSavedRecipes()
    }

    // MARK: - All Recipes (built-in + saved)

    var allRecipes: [Recipe] {
        let builtIns = builtInRecipes.isEmpty ? Self.recipes : builtInRecipes
        return builtIns + savedRecipes
    }

    func recipes(for mealType: MealType) -> [Recipe] {
        allRecipes.filter { $0.mealType == mealType }
    }

    func builtInRecipes(for mealType: MealType) -> [Recipe] {
        let builtIns = builtInRecipes.isEmpty ? Self.recipes : builtInRecipes
        return builtIns.filter { $0.mealType == mealType }
    }

    func userRecipes(for mealType: MealType) -> [Recipe] {
        savedRecipes.filter { $0.mealType == mealType }
    }

    // MARK: - Supabase Sync

    /// Fetch all recipes from Supabase (built-in + user's own)
    func loadFromSupabase() async {
        isLoading = true
        defer { isLoading = false }

        // 1. Fetch built-in recipes
        do {
            let rows: [RecipeRow] = try await SupabaseService.shared
                .from("recipes")
                .select()
                .eq("source", value: "builtin")
                .eq("is_active", value: true)
                .execute().value

            let fetched = rows.compactMap { $0.toRecipe() }
            if !fetched.isEmpty {
                builtInRecipes = fetched
                cacheBuiltIns(fetched)
            }
        } catch {
            #if DEBUG
            print("[Recipes] Failed to load built-ins from Supabase: \(error.localizedDescription)")
            #endif
        }

        // 2. Fetch user's own recipes + saved/favorited IDs
        guard let uid = AuthService.shared.userID else { return }

        do {
            let userRows: [RecipeRow] = try await SupabaseService.shared
                .from("recipes")
                .select()
                .eq("user_id", value: uid)
                .eq("is_active", value: true)
                .execute().value

            let fetched = userRows.compactMap { $0.toRecipe() }
            savedRecipes = fetched
            persistSavedRecipes()
        } catch {
            #if DEBUG
            print("[Recipes] Failed to load user recipes: \(error.localizedDescription)")
            #endif
        }

        do {
            let savedRows: [SavedRecipeRow] = try await SupabaseService.shared
                .from("user_saved_recipes")
                .select("recipe_id")
                .eq("user_id", value: uid)
                .execute().value

            savedRecipeIDs = Set(savedRows.map(\.recipe_id))
        } catch {
            #if DEBUG
            print("[Recipes] Failed to load saved recipe IDs: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Saved Recipes CRUD

    func saveRecipe(_ recipe: Recipe) {
        savedRecipes.append(recipe)
        persistSavedRecipes()

        Task { await syncSaveRecipe(recipe) }
    }

    func updateRecipe(_ recipe: Recipe) {
        if let idx = savedRecipes.firstIndex(where: { $0.id == recipe.id }) {
            savedRecipes[idx] = recipe
            persistSavedRecipes()

            Task { await syncUpdateRecipe(recipe) }
        }
    }

    func deleteRecipe(_ recipeId: UUID) {
        savedRecipes.removeAll { $0.id == recipeId }
        persistSavedRecipes()

        Task { await syncDeleteRecipe(recipeId) }
    }

    func isSavedRecipe(_ recipeId: UUID) -> Bool {
        savedRecipeIDs.contains(recipeId) || savedRecipes.contains { $0.id == recipeId }
    }

    /// Save a built-in or AI-generated recipe to the user's collection
    func saveToCollection(_ recipe: Recipe) {
        guard !savedRecipeIDs.contains(recipe.id) else { return }
        savedRecipeIDs.insert(recipe.id)

        // If it's not already in savedRecipes (e.g. a built-in), just track the ID
        if !savedRecipes.contains(where: { $0.id == recipe.id }) {
            // For built-in recipes, we only need the junction table entry
        }

        Task { await syncSaveToCollection(recipe.id) }
    }

    func removeFromCollection(_ recipeId: UUID) {
        savedRecipeIDs.remove(recipeId)

        Task { await syncRemoveFromCollection(recipeId) }
    }

    // MARK: - Supabase Write Operations

    private func syncSaveRecipe(_ recipe: Recipe) async {
        guard let uid = AuthService.shared.userID else { return }
        do {
            let row = RecipeInsertRow(
                user_id: uid,
                source: "user",
                meal_type: recipe.mealType.rawValue.lowercased(),
                name: recipe.name,
                description: recipe.description,
                ingredients: recipe.ingredients,
                instructions: recipe.instructions,
                prep_time: recipe.prepTime,
                calories: recipe.calories,
                protein: recipe.protein,
                carbs: recipe.carbs,
                fat: recipe.fat,
                tags: recipe.tags
            )
            let query = try SupabaseService.shared
                .from("recipes")
                .insert(row)
            try await query.execute()
        } catch {
            #if DEBUG
            print("[Recipes] Supabase insert failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func syncUpdateRecipe(_ recipe: Recipe) async {
        guard let uid = AuthService.shared.userID else { return }
        do {
            let row = RecipeInsertRow(
                user_id: uid,
                source: "user",
                meal_type: recipe.mealType.rawValue.lowercased(),
                name: recipe.name,
                description: recipe.description,
                ingredients: recipe.ingredients,
                instructions: recipe.instructions,
                prep_time: recipe.prepTime,
                calories: recipe.calories,
                protein: recipe.protein,
                carbs: recipe.carbs,
                fat: recipe.fat,
                tags: recipe.tags
            )
            let query = try SupabaseService.shared
                .from("recipes")
                .update(row)
                .eq("id", value: recipe.id.uuidString)
            try await query.execute()
        } catch {
            #if DEBUG
            print("[Recipes] Supabase update failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func syncDeleteRecipe(_ recipeId: UUID) async {
        guard AuthService.shared.userID != nil else { return }
        do {
            try await SupabaseService.shared
                .from("recipes")
                .delete()
                .eq("id", value: recipeId.uuidString)
                .execute()
        } catch {
            #if DEBUG
            print("[Recipes] Supabase delete failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func syncSaveToCollection(_ recipeId: UUID) async {
        guard let uid = AuthService.shared.userID else { return }
        do {
            let query = try SupabaseService.shared
                .from("user_saved_recipes")
                .upsert(SavedRecipeInsert(user_id: uid, recipe_id: recipeId))
            try await query.execute()
        } catch {
            #if DEBUG
            print("[Recipes] Supabase save-to-collection failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func syncRemoveFromCollection(_ recipeId: UUID) async {
        guard let uid = AuthService.shared.userID else { return }
        do {
            try await SupabaseService.shared
                .from("user_saved_recipes")
                .delete()
                .eq("user_id", value: uid)
                .eq("recipe_id", value: recipeId.uuidString)
                .execute()
        } catch {
            #if DEBUG
            print("[Recipes] Supabase remove-from-collection failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Local Cache

    private func persistSavedRecipes() {
        secure.setCodable(savedRecipes, forKey: storageKey)
    }

    private func loadSavedRecipes() {
        if let saved = secure.getCodable([Recipe].self, forKey: storageKey) {
            savedRecipes = saved
        }
    }

    private func cacheBuiltIns(_ recipes: [Recipe]) {
        secure.setCodable(recipes, forKey: builtInCacheKey)
    }

    private func loadLocalCache() {
        if let cached = secure.getCodable([Recipe].self, forKey: builtInCacheKey) {
            builtInRecipes = cached
        }
    }

    // MARK: - Build Grocery List from Meals

    struct GroceryEntry {
        var name: String
        var quantities: [String]
        var sourceMeals: Set<String>
        var category: String
    }

    func buildGroceryList(from days: [DayMealPlan], householdSize: Int = 0) -> [GrocerySection] {
        let effectiveHousehold = householdSize > 0 ? householdSize : max(1, NutritionPreferencesService.shared.preferences.householdSize)
        var entries: [String: GroceryEntry] = [:]  // normalized name -> entry

        for day in days {
            for meal in day.meals {
                for ingredient in meal.ingredients {
                    let normalized = normalizeIngredient(ingredient)
                    let category = categorize(normalized)
                    let qty = extractQuantity(ingredient, householdSize: effectiveHousehold)

                    if var existing = entries[normalized] {
                        if !qty.isEmpty { existing.quantities.append(qty) }
                        existing.sourceMeals.insert(meal.name)
                        entries[normalized] = existing
                    } else {
                        entries[normalized] = GroceryEntry(
                            name: ingredient,
                            quantities: qty.isEmpty ? [] : [qty],
                            sourceMeals: [meal.name],
                            category: category
                        )
                    }
                }
            }
        }

        let order = ["Protein", "Produce", "Dairy & Alternatives", "Grains", "Frozen", "Spices & Condiments", "Pantry", "Beverages", "Supplements", "Other"]

        return order.compactMap { cat in
            let items = entries.values
                .filter { $0.category == cat }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map { entry in
                    GroceryItem(
                        name: entry.name,
                        quantity: consolidateQuantities(entry.quantities),
                        sourceMealNames: Array(entry.sourceMeals).sorted()
                    )
                }
            guard !items.isEmpty else { return nil }
            return GrocerySection(category: cat, items: items)
        }
    }

    // MARK: - Ingredient Normalization

    private func normalizeIngredient(_ ingredient: String) -> String {
        var s = ingredient.lowercased()
            .trimmingCharacters(in: .whitespaces)

        // Strip leading quantities: "2 cups", "1/2 lb", "3 large"
        let quantityPattern = #"^[\d/\.]+\s*(cups?|tbsp|tsp|oz|lbs?|large|medium|small|bunch|head|cloves?|slices?|pieces?|cans?|bottles?|stalks?|sprigs?|pinch|dash|pint|quart|gallons?|fl\s*oz)?\s*"#
        if let range = s.range(of: quantityPattern, options: .regularExpression) {
            s = String(s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        // Normalize common variants
        let normalizations: [String: String] = [
            "greek yogurt": "greek yogurt",
            "plain greek yogurt": "greek yogurt",
            "nonfat greek yogurt": "greek yogurt",
            "mixed greens": "mixed greens",
            "baby spinach": "spinach",
            "fresh spinach": "spinach",
            "cherry tomatoes": "cherry tomatoes",
            "roma tomatoes": "tomatoes",
            "diced tomatoes": "tomatoes",
            "olive oil": "olive oil",
            "extra virgin olive oil": "olive oil",
            "evoo": "olive oil",
            "ground beef": "ground beef",
            "lean ground beef": "ground beef",
            "ground beef (90/10)": "ground beef",
            "chicken breast": "chicken breast",
            "boneless skinless chicken breast": "chicken breast",
            "white rice": "white rice",
            "jasmine rice": "jasmine rice",
            "brown rice": "brown rice",
            "almond milk": "almond milk",
            "unsweetened almond milk": "almond milk",
        ]

        return normalizations[s] ?? s
    }

    private func extractQuantity(_ ingredient: String, householdSize: Int) -> String {
        let quantityPattern = #"^([\d/\.]+\s*(?:cups?|tbsp|tsp|oz|lbs?|large|medium|small|bunch|head|cloves?|slices?|pieces?|cans?|bottles?|pint|quart)?)"#
        guard let match = ingredient.range(of: quantityPattern, options: .regularExpression) else {
            return householdSize > 1 ? "×\(householdSize)" : ""
        }
        let base = String(ingredient[match])
        if householdSize > 1 {
            return "\(base) ×\(householdSize)"
        }
        return base
    }

    private func consolidateQuantities(_ quantities: [String]) -> String {
        if quantities.isEmpty { return "" }
        if quantities.count == 1 { return quantities[0] }

        // Try to sum numeric quantities
        var total: Double = 0
        var unit = ""
        var canSum = true

        for q in quantities {
            let parts = q.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if let num = parseNumber(parts.first ?? "") {
                total += num
                if parts.count > 1 {
                    let u = parts.dropFirst().joined(separator: " ").replacingOccurrences(of: "×\\d+", with: "", options: .regularExpression)
                    if unit.isEmpty { unit = u }
                    else if unit != u { canSum = false }
                }
            } else {
                canSum = false
            }
        }

        if canSum && total > 0 {
            let formatted = total.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(total))" : String(format: "%.1f", total)
            return unit.isEmpty ? formatted : "\(formatted) \(unit)".trimmingCharacters(in: .whitespaces)
        }

        return quantities.joined(separator: " + ")
    }

    private func parseNumber(_ s: String) -> Double? {
        if let d = Double(s) { return d }
        // Handle fractions like "1/2"
        let parts = s.components(separatedBy: "/")
        if parts.count == 2, let num = Double(parts[0]), let den = Double(parts[1]), den != 0 {
            return num / den
        }
        return nil
    }

    // MARK: - Categorization

    private func categorize(_ normalized: String) -> String {
        let s = normalized.lowercased()

        let categories: [(String, [String])] = [
            ("Protein", ["chicken", "salmon", "beef", "turkey", "shrimp", "tuna", "egg", "steak", "pork", "cod", "tilapia", "tofu", "tempeh", "sausage", "bacon", "lamb", "ground beef", "flank", "sirloin", "thigh", "breast", "fish", "lobster", "crab", "scallop"]),
            ("Produce", ["spinach", "broccoli", "avocado", "banana", "berry", "berries", "tomato", "lettuce", "greens", "pepper", "onion", "garlic", "lemon", "lime", "apple", "orange", "cucumber", "zucchini", "sweet potato", "potato", "mushroom", "kale", "arugula", "asparagus", "carrot", "celery", "mango", "pineapple", "strawberry", "blueberry", "cilantro", "basil", "parsley", "rosemary", "thyme", "ginger", "jalapeño", "corn", "snap peas", "edamame", "green onion"]),
            ("Dairy & Alternatives", ["yogurt", "cheese", "milk", "butter", "cream", "mozzarella", "parmesan", "feta", "cottage", "sour cream", "ricotta", "ghee", "almond milk", "oat milk", "coconut milk"]),
            ("Grains", ["rice", "bread", "oats", "tortilla", "pasta", "quinoa", "wrap", "english muffin", "bagel", "pita", "noodle", "granola", "couscous", "farro", "sourdough", "rice cake"]),
            ("Frozen", ["frozen", "ice"]),
            ("Spices & Condiments", ["salt", "pepper", "cinnamon", "cumin", "paprika", "oregano", "italian seasoning", "taco seasoning", "everything bagel seasoning", "red pepper flakes", "soy sauce", "teriyaki", "hot sauce", "sriracha", "mustard", "ketchup", "vinaigrette", "balsamic", "dressing", "marinara", "salsa", "hummus", "capers", "mayo"]),
            ("Supplements", ["whey", "protein powder", "collagen", "creatine", "supplement", "protein bar", "bcaa"]),
            ("Beverages", ["coffee", "tea", "juice", "water", "sparkling"]),
        ]

        for (category, keywords) in categories {
            if keywords.contains(where: { s.contains($0) }) {
                return category
            }
        }

        // Check for pantry staples
        let pantryKeywords = ["olive oil", "coconut oil", "sesame oil", "honey", "maple syrup", "vinegar", "flour", "sugar", "baking", "cocoa", "vanilla", "almond butter", "peanut butter", "tahini", "soy sauce", "nuts", "seeds", "chia", "flax"]
        if pantryKeywords.contains(where: { s.contains($0) }) {
            return "Pantry"
        }

        return "Other"
    }

    // MARK: - Recipe Database

    // swiftlint:disable function_body_length
    static let recipes: [Recipe] = {
        var r: [Recipe] = []

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // BREAKFASTS (20)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        r.append(Recipe(mealType: .breakfast, name: "Scrambled Eggs & Avocado Toast", description: "Classic high-protein start", ingredients: ["3 eggs", "1 avocado", "2 slices sourdough", "salt & pepper", "everything bagel seasoning"], instructions: ["Scramble eggs over medium heat", "Toast bread", "Mash avocado on toast", "Top with eggs and seasoning"], prepTime: 8, calories: 520, protein: 28, carbs: 32, fat: 32, tags: ["quick", "high-protein"]))

        r.append(Recipe(mealType: .breakfast, name: "Protein Oatmeal Bowl", description: "Creamy oats with whey and berries", ingredients: ["1 cup rolled oats", "1 scoop whey protein", "1/2 cup blueberries", "1 tbsp almond butter", "1 cup almond milk"], instructions: ["Cook oats with almond milk", "Stir in protein powder", "Top with berries and almond butter"], prepTime: 7, calories: 480, protein: 35, carbs: 52, fat: 16, tags: ["high-protein", "meal-prep"]))

        r.append(Recipe(mealType: .breakfast, name: "Greek Yogurt Parfait", description: "Layered yogurt with granola and fruit", ingredients: ["1.5 cups Greek yogurt", "1/3 cup granola", "1/2 cup strawberries", "1 tbsp honey", "1 tbsp chia seeds"], instructions: ["Layer yogurt, granola, and fruit", "Drizzle with honey", "Top with chia seeds"], prepTime: 5, calories: 420, protein: 32, carbs: 48, fat: 12, tags: ["quick", "no-cook"]))

        r.append(Recipe(mealType: .breakfast, name: "Turkey Sausage & Egg Wrap", description: "Savory breakfast wrap", ingredients: ["2 turkey sausage links", "3 eggs", "1 whole wheat tortilla", "1/4 cup shredded cheese", "hot sauce"], instructions: ["Cook sausage and slice", "Scramble eggs", "Warm tortilla, fill with eggs, sausage, cheese", "Roll and serve with hot sauce"], prepTime: 10, calories: 490, protein: 38, carbs: 28, fat: 24, tags: ["high-protein", "portable"]))

        r.append(Recipe(mealType: .breakfast, name: "Banana Protein Pancakes", description: "Fluffy pancakes packed with protein", ingredients: ["1 banana", "2 eggs", "1 scoop protein powder", "1/4 cup oats", "1 tsp cinnamon", "maple syrup"], instructions: ["Blend banana, eggs, protein powder, oats", "Cook on medium griddle 2 min each side", "Stack and top with syrup"], prepTime: 12, calories: 440, protein: 34, carbs: 46, fat: 14, tags: ["high-protein"]))

        r.append(Recipe(mealType: .breakfast, name: "Smoked Salmon & Cream Cheese Bagel", description: "Lox bagel with capers", ingredients: ["1 everything bagel", "3 oz smoked salmon", "2 tbsp cream cheese", "capers", "red onion slices", "lemon wedge"], instructions: ["Toast bagel", "Spread cream cheese", "Layer salmon, capers, onion", "Squeeze lemon over top"], prepTime: 5, calories: 460, protein: 28, carbs: 42, fat: 20, tags: ["quick", "no-cook"]))

        r.append(Recipe(mealType: .breakfast, name: "Veggie Egg Scramble", description: "Loaded vegetable scramble", ingredients: ["3 eggs", "1/2 cup spinach", "1/4 cup bell peppers diced", "1/4 cup mushrooms", "1 oz feta cheese", "olive oil"], instructions: ["Sauté veggies in olive oil 3 min", "Add beaten eggs", "Scramble until set", "Top with crumbled feta"], prepTime: 8, calories: 380, protein: 26, carbs: 8, fat: 28, tags: ["low-carb", "vegetarian"]))

        r.append(Recipe(mealType: .breakfast, name: "Overnight Oats", description: "Prep the night before, grab and go", ingredients: ["1 cup rolled oats", "1 cup milk", "1 scoop protein powder", "1 tbsp peanut butter", "1/2 banana sliced"], instructions: ["Mix oats, milk, and protein powder in jar", "Refrigerate overnight", "Top with peanut butter and banana in the morning"], prepTime: 5, calories: 500, protein: 36, carbs: 56, fat: 16, tags: ["meal-prep", "no-cook"]))

        r.append(Recipe(mealType: .breakfast, name: "Shakshuka", description: "Eggs poached in spiced tomato sauce", ingredients: ["3 eggs", "1 can diced tomatoes", "1/2 onion diced", "2 cloves garlic", "1 tsp cumin", "1 tsp paprika", "olive oil", "crusty bread"], instructions: ["Sauté onion and garlic in olive oil", "Add tomatoes, cumin, paprika, simmer 10 min", "Make wells, crack eggs in", "Cover and cook 5 min until set", "Serve with bread"], prepTime: 20, calories: 420, protein: 22, carbs: 36, fat: 22, tags: ["mediterranean", "vegetarian"]))

        r.append(Recipe(mealType: .breakfast, name: "Acai Bowl", description: "Thick smoothie bowl with toppings", ingredients: ["1 packet frozen acai", "1/2 banana", "1/2 cup frozen berries", "1/4 cup almond milk", "granola", "sliced banana", "coconut flakes", "honey"], instructions: ["Blend acai, frozen banana, berries, and almond milk until thick", "Pour into bowl", "Top with granola, banana, coconut, and honey"], prepTime: 8, calories: 380, protein: 8, carbs: 62, fat: 14, tags: ["vegan", "no-cook", "antioxidant"]))

        r.append(Recipe(mealType: .breakfast, name: "Egg & Cheese Muffin Cups", description: "Meal-prep friendly baked egg cups", ingredients: ["6 eggs", "1/4 cup cheddar cheese", "1/4 cup bell peppers", "2 slices turkey bacon", "salt & pepper"], instructions: ["Preheat oven to 375F", "Grease muffin tin", "Whisk eggs, add cheese, peppers, diced bacon", "Pour into 6 cups", "Bake 18 min"], prepTime: 25, calories: 350, protein: 28, carbs: 4, fat: 24, tags: ["meal-prep", "low-carb", "high-protein"]))

        r.append(Recipe(mealType: .breakfast, name: "Sweet Potato & Black Bean Hash", description: "Hearty plant-forward hash", ingredients: ["1 large sweet potato diced", "1/2 cup black beans", "1/2 bell pepper diced", "1/4 onion diced", "2 eggs", "cumin", "olive oil", "cilantro"], instructions: ["Sauté sweet potato in olive oil 8 min", "Add pepper, onion, cumin, cook 3 min", "Add black beans, warm through", "Fry eggs, serve on top", "Garnish with cilantro"], prepTime: 18, calories: 460, protein: 22, carbs: 52, fat: 18, tags: ["high-fiber", "vegetarian"]))

        r.append(Recipe(mealType: .breakfast, name: "Chia Pudding", description: "Creamy make-ahead pudding", ingredients: ["3 tbsp chia seeds", "1 cup coconut milk", "1 tbsp maple syrup", "1/2 tsp vanilla", "mango slices", "coconut flakes"], instructions: ["Mix chia seeds, coconut milk, maple syrup, vanilla", "Refrigerate 4 hours or overnight", "Top with mango and coconut"], prepTime: 5, calories: 340, protein: 8, carbs: 34, fat: 20, tags: ["vegan", "no-cook", "meal-prep"]))

        r.append(Recipe(mealType: .breakfast, name: "Breakfast Quesadilla", description: "Crispy tortilla with eggs and cheese", ingredients: ["2 eggs scrambled", "1 flour tortilla", "1/4 cup shredded cheese", "2 tbsp salsa", "1/4 avocado"], instructions: ["Scramble eggs", "Place tortilla in pan, add cheese on half", "Add eggs, fold, cook 2 min each side", "Serve with salsa and avocado"], prepTime: 8, calories: 440, protein: 24, carbs: 30, fat: 26, tags: ["quick", "portable"]))

        r.append(Recipe(mealType: .breakfast, name: "Tofu Scramble", description: "Plant-based egg alternative", ingredients: ["1 block firm tofu crumbled", "1/2 cup spinach", "1/4 cup bell pepper", "1/4 tsp turmeric", "nutritional yeast", "olive oil", "salt & pepper"], instructions: ["Press and crumble tofu", "Sauté in olive oil with turmeric 5 min", "Add veggies, cook 3 min", "Season with nutritional yeast, salt, pepper"], prepTime: 12, calories: 280, protein: 22, carbs: 8, fat: 18, tags: ["vegan", "high-protein", "low-carb"]))

        r.append(Recipe(mealType: .breakfast, name: "Cottage Cheese Toast", description: "High-protein savory toast", ingredients: ["2 slices whole grain bread", "1 cup cottage cheese", "1/2 avocado", "everything bagel seasoning", "red pepper flakes"], instructions: ["Toast bread", "Spread cottage cheese on each slice", "Top with avocado slices", "Sprinkle seasoning and pepper flakes"], prepTime: 5, calories: 420, protein: 30, carbs: 34, fat: 18, tags: ["quick", "high-protein", "no-cook"]))

        r.append(Recipe(mealType: .breakfast, name: "Korean Rice Bowl (Bibimbap Breakfast)", description: "Rice with veggies, egg, and gochujang", ingredients: ["1 cup rice cooked", "1 fried egg", "1/2 cup kimchi", "1/4 cup spinach sautéed", "1/4 cup shredded carrot", "gochujang", "sesame oil", "sesame seeds"], instructions: ["Warm rice in bowl", "Arrange veggies and kimchi around rice", "Top with fried egg", "Drizzle gochujang and sesame oil", "Sprinkle sesame seeds"], prepTime: 12, calories: 440, protein: 16, carbs: 58, fat: 16, tags: ["korean", "vegetarian"]))

        r.append(Recipe(mealType: .breakfast, name: "Egg White & Spinach Omelette", description: "Light and clean protein-focused omelette", ingredients: ["5 egg whites", "1 cup spinach", "1/4 cup mushrooms", "1 oz goat cheese", "salt & pepper"], instructions: ["Whisk egg whites", "Sauté spinach and mushrooms", "Pour egg whites in pan, cook 3 min", "Add veggies and goat cheese, fold", "Cook 1 more min"], prepTime: 10, calories: 220, protein: 28, carbs: 4, fat: 10, tags: ["low-calorie", "high-protein", "low-carb"]))

        r.append(Recipe(mealType: .breakfast, name: "Avocado & Black Bean Breakfast Bowl", description: "Mexican-inspired plant-based bowl", ingredients: ["1/2 cup black beans", "1/2 avocado", "1/4 cup corn", "salsa", "1 tbsp lime juice", "cilantro", "1 corn tortilla"], instructions: ["Warm beans and corn", "Mash avocado with lime juice", "Layer beans, corn, avocado in bowl", "Top with salsa and cilantro", "Serve with toasted tortilla"], prepTime: 8, calories: 380, protein: 14, carbs: 48, fat: 16, tags: ["vegan", "high-fiber", "mexican"]))

        r.append(Recipe(mealType: .breakfast, name: "PB & J Protein Smoothie", description: "Tastes like a classic PB&J", ingredients: ["1 scoop vanilla protein", "1 cup milk", "1 tbsp peanut butter", "1/2 cup frozen strawberries", "1/2 banana", "ice"], instructions: ["Blend all ingredients until smooth"], prepTime: 3, calories: 400, protein: 32, carbs: 40, fat: 14, tags: ["quick", "post-workout", "high-protein"]))

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // LUNCHES (20)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        r.append(Recipe(mealType: .lunch, name: "Grilled Chicken Caesar Salad", description: "Classic caesar with grilled chicken", ingredients: ["6 oz chicken breast", "romaine lettuce", "2 tbsp caesar dressing", "1/4 cup parmesan", "croutons"], instructions: ["Grill chicken 6 min each side", "Chop romaine", "Slice chicken over greens", "Dress and top with parmesan and croutons"], prepTime: 15, calories: 480, protein: 44, carbs: 16, fat: 26, tags: ["high-protein", "classic"]))

        r.append(Recipe(mealType: .lunch, name: "Turkey & Avocado Wrap", description: "Clean wrap with lean turkey", ingredients: ["5 oz sliced turkey breast", "1 whole wheat tortilla", "1/2 avocado", "lettuce", "tomato", "mustard"], instructions: ["Layer turkey, avocado, lettuce, tomato on tortilla", "Drizzle mustard", "Roll tight and cut in half"], prepTime: 5, calories: 440, protein: 36, carbs: 30, fat: 20, tags: ["quick", "portable", "meal-prep"]))

        r.append(Recipe(mealType: .lunch, name: "Salmon Poke Bowl", description: "Fresh poke bowl with sushi rice", ingredients: ["5 oz sushi-grade salmon diced", "1 cup sushi rice cooked", "1/2 avocado", "edamame", "cucumber", "soy sauce", "sesame seeds"], instructions: ["Cook and cool sushi rice", "Dice salmon", "Arrange rice, salmon, avocado, edamame, cucumber", "Drizzle soy sauce and sesame seeds"], prepTime: 15, calories: 540, protein: 38, carbs: 48, fat: 22, tags: ["japanese", "high-protein"]))

        r.append(Recipe(mealType: .lunch, name: "Chicken Burrito Bowl", description: "Chipotle-style bowl at home", ingredients: ["6 oz chicken thigh", "1 cup brown rice", "1/2 cup black beans", "salsa", "1/4 avocado", "lime", "cilantro"], instructions: ["Season and cook chicken 5 min each side", "Warm rice and beans", "Slice chicken and build bowl", "Top with salsa, avocado, cilantro, lime"], prepTime: 18, calories: 580, protein: 42, carbs: 56, fat: 18, tags: ["meal-prep", "high-protein", "mexican"]))

        r.append(Recipe(mealType: .lunch, name: "Tuna Stuffed Sweet Potato", description: "Loaded sweet potato with tuna salad", ingredients: ["1 large sweet potato", "1 can tuna", "2 tbsp Greek yogurt", "celery diced", "red onion", "salt & pepper"], instructions: ["Bake sweet potato 45 min at 400F (or microwave 8 min)", "Mix tuna with yogurt, celery, onion", "Split potato and fill with tuna mix"], prepTime: 12, calories: 420, protein: 36, carbs: 46, fat: 8, tags: ["low-fat", "meal-prep"]))

        r.append(Recipe(mealType: .lunch, name: "Steak & Arugula Salad", description: "Peppery arugula with sliced steak", ingredients: ["5 oz flank steak", "arugula", "cherry tomatoes", "shaved parmesan", "balsamic vinaigrette", "red onion"], instructions: ["Season steak, sear 4 min each side for medium", "Rest 5 min, slice thin", "Toss arugula, tomatoes, onion with vinaigrette", "Top with steak and parmesan"], prepTime: 15, calories: 460, protein: 38, carbs: 12, fat: 28, tags: ["high-protein", "low-carb"]))

        r.append(Recipe(mealType: .lunch, name: "Mediterranean Chicken Pita", description: "Grilled chicken in warm pita", ingredients: ["5 oz chicken breast", "1 whole wheat pita", "hummus", "cucumber", "tomato", "red onion", "feta"], instructions: ["Grill chicken with Mediterranean seasoning", "Warm pita", "Spread hummus in pita", "Fill with sliced chicken, veggies, feta"], prepTime: 15, calories: 490, protein: 40, carbs: 38, fat: 18, tags: ["mediterranean"]))

        r.append(Recipe(mealType: .lunch, name: "Shrimp Stir-Fry", description: "Quick shrimp and veggie stir-fry", ingredients: ["6 oz shrimp peeled", "1 cup broccoli florets", "1/2 cup snap peas", "1 cup jasmine rice", "soy sauce", "garlic", "sesame oil"], instructions: ["Cook rice", "Sauté garlic in sesame oil", "Add shrimp, cook 2 min each side", "Add veggies, stir-fry 3 min", "Splash soy sauce, serve over rice"], prepTime: 15, calories: 480, protein: 36, carbs: 52, fat: 12, tags: ["quick", "high-protein", "asian"]))

        r.append(Recipe(mealType: .lunch, name: "Thai Peanut Chicken Lettuce Wraps", description: "Crunchy wraps with peanut sauce", ingredients: ["5 oz chicken breast diced", "butter lettuce leaves", "1/4 cup shredded carrot", "cucumber sliced", "peanuts chopped", "2 tbsp peanut butter", "1 tbsp soy sauce", "lime juice", "sriracha"], instructions: ["Cook diced chicken 5 min", "Mix peanut butter, soy sauce, lime, sriracha for sauce", "Fill lettuce cups with chicken, carrot, cucumber", "Drizzle peanut sauce, top with peanuts"], prepTime: 12, calories: 420, protein: 38, carbs: 16, fat: 24, tags: ["thai", "low-carb", "high-protein"]))

        r.append(Recipe(mealType: .lunch, name: "Lentil Soup", description: "Hearty one-pot lentil soup", ingredients: ["1 cup red lentils", "1 can diced tomatoes", "1 carrot diced", "1 onion diced", "2 cloves garlic", "1 tsp cumin", "4 cups vegetable broth", "olive oil", "lemon"], instructions: ["Sauté onion, carrot, garlic in olive oil 5 min", "Add lentils, tomatoes, broth, cumin", "Simmer 20 min until lentils are soft", "Squeeze lemon, season to taste"], prepTime: 30, calories: 380, protein: 22, carbs: 56, fat: 6, tags: ["vegan", "high-fiber", "one-pot", "meal-prep"]))

        r.append(Recipe(mealType: .lunch, name: "Chicken Shawarma Bowl", description: "Middle Eastern spiced chicken with tahini", ingredients: ["6 oz chicken thigh", "1 cup basmati rice", "cucumber", "tomato", "pickled onion", "tahini", "cumin", "paprika", "garlic powder", "olive oil"], instructions: ["Season chicken with cumin, paprika, garlic powder", "Cook chicken 5 min each side, slice", "Cook rice", "Build bowl with rice, chicken, veggies", "Drizzle tahini"], prepTime: 20, calories: 560, protein: 40, carbs: 52, fat: 20, tags: ["middle-eastern", "high-protein", "meal-prep"]))

        r.append(Recipe(mealType: .lunch, name: "Veggie Buddha Bowl", description: "Colorful grain bowl with tahini dressing", ingredients: ["1 cup quinoa cooked", "1/2 cup roasted sweet potato", "1/2 cup chickpeas", "1/2 avocado", "1/2 cup kale massaged", "tahini", "lemon juice"], instructions: ["Cook quinoa", "Roast sweet potato cubes at 400F 20 min", "Warm chickpeas", "Arrange all in bowl", "Drizzle tahini and lemon"], prepTime: 25, calories: 520, protein: 18, carbs: 64, fat: 22, tags: ["vegan", "high-fiber", "mediterranean"]))

        r.append(Recipe(mealType: .lunch, name: "Japanese Teriyaki Salmon Bowl", description: "Glazed salmon over rice with pickled ginger", ingredients: ["5 oz salmon fillet", "1 cup sushi rice", "teriyaki sauce", "edamame", "pickled ginger", "nori strips", "sesame seeds"], instructions: ["Cook rice", "Brush salmon with teriyaki, pan-sear 4 min each side", "Arrange rice, salmon, edamame in bowl", "Top with ginger, nori, sesame seeds"], prepTime: 18, calories: 540, protein: 36, carbs: 52, fat: 18, tags: ["japanese", "high-protein"]))

        r.append(Recipe(mealType: .lunch, name: "Black Bean & Corn Salad", description: "Bright Tex-Mex salad with lime dressing", ingredients: ["1 can black beans drained", "1 cup corn", "1 bell pepper diced", "1/4 red onion diced", "cilantro", "lime juice", "olive oil", "cumin", "1/4 avocado"], instructions: ["Combine beans, corn, pepper, onion, cilantro", "Whisk lime juice, olive oil, cumin", "Toss salad with dressing", "Top with avocado"], prepTime: 10, calories: 380, protein: 16, carbs: 52, fat: 14, tags: ["vegan", "no-cook", "high-fiber", "mexican"]))

        r.append(Recipe(mealType: .lunch, name: "Grilled Chicken Grain Bowl", description: "Farro, greens, and grilled chicken", ingredients: ["5 oz chicken breast", "1 cup farro cooked", "mixed greens", "roasted beets", "goat cheese", "walnuts", "balsamic glaze"], instructions: ["Grill chicken, slice", "Cook farro", "Arrange greens, farro, beets in bowl", "Top with chicken, goat cheese, walnuts", "Drizzle balsamic glaze"], prepTime: 20, calories: 520, protein: 38, carbs: 46, fat: 20, tags: ["high-protein", "whole-grain"]))

        r.append(Recipe(mealType: .lunch, name: "Vietnamese Banh Mi Bowl", description: "Deconstructed banh mi without the bread", ingredients: ["5 oz pork tenderloin", "pickled carrots and daikon", "cucumber", "jalapeño", "cilantro", "1 cup jasmine rice", "soy sauce", "lime", "sriracha mayo"], instructions: ["Season and sear pork 4 min each side, slice", "Cook rice", "Arrange rice, pork, pickled veggies, cucumber", "Top with jalapeño, cilantro, sriracha mayo"], prepTime: 18, calories: 480, protein: 34, carbs: 50, fat: 14, tags: ["vietnamese", "high-protein"]))

        r.append(Recipe(mealType: .lunch, name: "Caprese Chicken Salad", description: "Italian-inspired with fresh mozzarella", ingredients: ["5 oz chicken breast grilled", "fresh mozzarella", "cherry tomatoes", "fresh basil", "mixed greens", "balsamic glaze", "olive oil"], instructions: ["Grill and slice chicken", "Arrange greens, tomatoes, mozzarella", "Top with chicken and basil", "Drizzle olive oil and balsamic glaze"], prepTime: 15, calories: 460, protein: 42, carbs: 10, fat: 28, tags: ["italian", "low-carb", "high-protein"]))

        r.append(Recipe(mealType: .lunch, name: "Chickpea Curry Wrap", description: "Spiced chickpeas in a warm tortilla", ingredients: ["1 can chickpeas drained", "1/2 onion diced", "1 tsp curry powder", "1/4 cup coconut milk", "spinach", "1 whole wheat tortilla", "olive oil"], instructions: ["Sauté onion in olive oil 3 min", "Add chickpeas and curry powder, cook 3 min", "Add coconut milk, simmer 5 min, mash slightly", "Add spinach, wilt", "Fill tortilla and roll"], prepTime: 15, calories: 440, protein: 18, carbs: 54, fat: 18, tags: ["vegan", "indian", "portable"]))

        r.append(Recipe(mealType: .lunch, name: "Egg Fried Rice", description: "Quick weekday lunch staple", ingredients: ["2 cups cold cooked rice", "2 eggs", "1/2 cup frozen peas and carrots", "2 green onions sliced", "soy sauce", "sesame oil", "garlic"], instructions: ["Heat sesame oil, sauté garlic", "Push to side, scramble eggs", "Add cold rice, stir-fry on high 3 min", "Add veggies, soy sauce, toss", "Top with green onions"], prepTime: 10, calories: 420, protein: 16, carbs: 58, fat: 14, tags: ["quick", "asian", "budget"]))

        r.append(Recipe(mealType: .lunch, name: "Greek Salad with Grilled Halloumi", description: "Salty cheese over a classic Greek salad", ingredients: ["4 oz halloumi cheese", "cucumber", "cherry tomatoes", "red onion", "kalamata olives", "olive oil", "oregano", "lemon juice"], instructions: ["Slice and grill halloumi 2 min each side", "Chop cucumber, tomatoes, onion", "Toss with olives, olive oil, lemon, oregano", "Top with halloumi"], prepTime: 12, calories: 420, protein: 22, carbs: 14, fat: 32, tags: ["mediterranean", "vegetarian", "low-carb"]))

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // DINNERS (20)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        r.append(Recipe(mealType: .dinner, name: "Pan-Seared Salmon & Asparagus", description: "Crispy salmon with roasted asparagus", ingredients: ["6 oz salmon fillet", "1 bunch asparagus", "1 tbsp olive oil", "lemon", "garlic", "salt & pepper"], instructions: ["Season salmon with salt, pepper, garlic", "Pan-sear skin-side down 4 min, flip 3 min", "Roast asparagus at 425F with olive oil 12 min", "Squeeze lemon over everything"], prepTime: 18, calories: 480, protein: 42, carbs: 10, fat: 30, tags: ["high-protein", "low-carb"]))

        r.append(Recipe(mealType: .dinner, name: "Chicken Stir-Fry with Rice", description: "Teriyaki chicken with vegetables", ingredients: ["6 oz chicken breast", "1 cup jasmine rice", "broccoli", "bell peppers", "teriyaki sauce", "sesame oil", "green onions"], instructions: ["Cook rice", "Slice chicken, stir-fry in sesame oil 5 min", "Add veggies, cook 3 min", "Add teriyaki sauce, toss", "Serve over rice with green onions"], prepTime: 20, calories: 560, protein: 40, carbs: 58, fat: 16, tags: ["meal-prep", "asian"]))

        r.append(Recipe(mealType: .dinner, name: "Grass-Fed Beef Tacos", description: "Simple beef tacos with fresh toppings", ingredients: ["6 oz ground beef (90/10)", "3 corn tortillas", "1/4 avocado", "salsa", "cilantro", "lime", "shredded lettuce"], instructions: ["Brown beef with taco seasoning", "Warm tortillas", "Build tacos with beef, lettuce, salsa, avocado", "Finish with cilantro and lime"], prepTime: 15, calories: 520, protein: 36, carbs: 34, fat: 26, tags: ["quick", "mexican"]))

        r.append(Recipe(mealType: .dinner, name: "Baked Cod with Quinoa", description: "Light white fish with herbed quinoa", ingredients: ["6 oz cod fillet", "1 cup quinoa cooked", "lemon", "cherry tomatoes", "olive oil", "fresh herbs", "capers"], instructions: ["Bake cod at 400F for 12 min with lemon and herbs", "Cook quinoa", "Halve tomatoes, toss with olive oil and capers", "Plate cod over quinoa with tomato salad"], prepTime: 20, calories: 440, protein: 38, carbs: 40, fat: 14, tags: ["light", "high-protein", "mediterranean"]))

        r.append(Recipe(mealType: .dinner, name: "Turkey Meatball Pasta", description: "Lean turkey meatballs with marinara", ingredients: ["6 oz ground turkey", "2 oz whole wheat pasta", "marinara sauce", "parmesan", "garlic", "Italian seasoning", "egg"], instructions: ["Mix turkey with egg, garlic, Italian seasoning, form balls", "Bake meatballs at 400F 15 min", "Cook pasta", "Simmer meatballs in marinara", "Serve over pasta with parmesan"], prepTime: 25, calories: 540, protein: 42, carbs: 48, fat: 18, tags: ["meal-prep", "italian"]))

        r.append(Recipe(mealType: .dinner, name: "Grilled Steak & Sweet Potato", description: "Seared steak with roasted sweet potato", ingredients: ["6 oz sirloin steak", "1 large sweet potato", "1 tbsp butter", "rosemary", "salt & pepper", "steamed broccoli"], instructions: ["Season steak, sear 4 min each side", "Rest 5 min", "Cube and roast sweet potato at 425F 25 min", "Steam broccoli", "Plate with butter on steak"], prepTime: 30, calories: 580, protein: 44, carbs: 42, fat: 24, tags: ["high-protein"]))

        r.append(Recipe(mealType: .dinner, name: "Shrimp & Zucchini Noodles", description: "Low-carb garlic shrimp over zoodles", ingredients: ["6 oz shrimp", "2 zucchinis spiralized", "garlic", "olive oil", "cherry tomatoes", "red pepper flakes", "parmesan"], instructions: ["Sauté garlic in olive oil", "Add shrimp, cook 2 min each side", "Add zucchini noodles, toss 2 min", "Add halved tomatoes and pepper flakes", "Top with parmesan"], prepTime: 12, calories: 360, protein: 36, carbs: 14, fat: 18, tags: ["low-carb", "quick", "keto"]))

        r.append(Recipe(mealType: .dinner, name: "Chicken & Black Bean Bowl", description: "Southwest-style protein bowl", ingredients: ["6 oz chicken breast", "1/2 cup black beans", "1 cup brown rice", "corn", "salsa", "lime", "cilantro", "sour cream"], instructions: ["Season and grill chicken", "Warm rice, beans, and corn", "Build bowl", "Top with salsa, sour cream, cilantro, lime"], prepTime: 20, calories: 560, protein: 44, carbs: 56, fat: 14, tags: ["meal-prep", "high-protein", "mexican"]))

        r.append(Recipe(mealType: .dinner, name: "Thai Green Curry", description: "Coconut curry with chicken and vegetables", ingredients: ["6 oz chicken thigh diced", "1 can coconut milk", "2 tbsp green curry paste", "1 cup broccoli", "1/2 cup bell pepper", "basil leaves", "1 cup jasmine rice", "fish sauce"], instructions: ["Cook rice", "Sauté curry paste in oil 1 min", "Add coconut milk, bring to simmer", "Add chicken, cook 6 min", "Add veggies, cook 3 min", "Season with fish sauce, top with basil"], prepTime: 22, calories: 580, protein: 36, carbs: 48, fat: 28, tags: ["thai", "one-pot"]))

        r.append(Recipe(mealType: .dinner, name: "Sheet Pan Chicken Fajitas", description: "Everything on one pan", ingredients: ["6 oz chicken breast sliced", "2 bell peppers sliced", "1 onion sliced", "fajita seasoning", "olive oil", "tortillas", "lime", "sour cream"], instructions: ["Toss chicken, peppers, onion with seasoning and oil", "Spread on sheet pan", "Bake at 425F for 18 min", "Serve in warm tortillas with lime and sour cream"], prepTime: 25, calories: 520, protein: 38, carbs: 42, fat: 20, tags: ["sheet-pan", "meal-prep", "mexican"]))

        r.append(Recipe(mealType: .dinner, name: "Lemon Herb Chicken Thighs", description: "Juicy baked chicken thighs with herbs", ingredients: ["2 bone-in chicken thighs", "lemon", "garlic", "rosemary", "thyme", "olive oil", "roasted potatoes", "green beans"], instructions: ["Season thighs with lemon, garlic, herbs, oil", "Place on baking sheet with potatoes", "Bake at 425F for 35 min", "Steam green beans last 5 min", "Serve together"], prepTime: 40, calories: 560, protein: 40, carbs: 36, fat: 28, tags: ["mediterranean", "one-pan"]))

        r.append(Recipe(mealType: .dinner, name: "Tofu Pad Thai", description: "Classic Thai noodle dish, plant-based", ingredients: ["1 block firm tofu cubed", "4 oz rice noodles", "1 egg", "bean sprouts", "green onion", "peanuts chopped", "2 tbsp pad thai sauce", "lime", "sriracha"], instructions: ["Press and cube tofu, pan-fry until golden", "Cook rice noodles per package", "Scramble egg in pan", "Add noodles, sauce, toss together", "Top with sprouts, peanuts, green onion, lime"], prepTime: 20, calories: 480, protein: 24, carbs: 54, fat: 20, tags: ["thai", "vegetarian"]))

        r.append(Recipe(mealType: .dinner, name: "Lamb Kofta with Tzatziki", description: "Spiced lamb patties with cool yogurt sauce", ingredients: ["6 oz ground lamb", "1/4 onion grated", "cumin", "coriander", "parsley", "1/2 cup Greek yogurt", "cucumber grated", "garlic", "pita bread", "mixed greens"], instructions: ["Mix lamb with onion, cumin, coriander, parsley", "Form into oval patties", "Grill or pan-fry 4 min each side", "Mix yogurt, cucumber, garlic for tzatziki", "Serve kofta with pita, greens, tzatziki"], prepTime: 20, calories: 520, protein: 36, carbs: 30, fat: 28, tags: ["middle-eastern", "high-protein"]))

        r.append(Recipe(mealType: .dinner, name: "Stuffed Bell Peppers", description: "Peppers filled with rice, beef, and cheese", ingredients: ["2 large bell peppers halved", "4 oz ground beef", "1/2 cup rice cooked", "1/2 cup tomato sauce", "1/4 cup shredded cheese", "Italian seasoning"], instructions: ["Brown beef with Italian seasoning", "Mix with rice and tomato sauce", "Stuff pepper halves", "Top with cheese", "Bake at 375F for 25 min"], prepTime: 35, calories: 480, protein: 32, carbs: 38, fat: 22, tags: ["meal-prep", "comfort"]))

        r.append(Recipe(mealType: .dinner, name: "Miso Glazed Cod", description: "Japanese-style glazed white fish", ingredients: ["6 oz cod fillet", "2 tbsp white miso paste", "1 tbsp mirin", "1 tsp sesame oil", "1 cup rice", "steamed bok choy", "sesame seeds"], instructions: ["Mix miso, mirin, sesame oil", "Marinate cod 30 min (or brush generously)", "Broil 6-8 min until caramelized", "Serve over rice with bok choy", "Sprinkle sesame seeds"], prepTime: 15, calories: 440, protein: 36, carbs: 48, fat: 10, tags: ["japanese", "high-protein", "light"]))

        r.append(Recipe(mealType: .dinner, name: "Chicken Tikka Masala", description: "Indian-spiced chicken in creamy tomato sauce", ingredients: ["6 oz chicken breast cubed", "1/2 cup plain yogurt", "1 can tomato sauce", "1/4 cup heavy cream", "garam masala", "turmeric", "garlic", "ginger", "1 cup basmati rice", "cilantro"], instructions: ["Marinate chicken in yogurt, garam masala, turmeric 15 min", "Cook chicken in pan 5 min", "Add tomato sauce, garlic, ginger, simmer 10 min", "Stir in cream", "Serve over rice with cilantro"], prepTime: 30, calories: 560, protein: 40, carbs: 52, fat: 20, tags: ["indian", "comfort"]))

        r.append(Recipe(mealType: .dinner, name: "One-Pan Sausage & Vegetables", description: "Italian sausage with roasted veggies", ingredients: ["2 Italian chicken sausage links", "1 cup broccoli", "1 cup sweet potato cubed", "1/2 cup bell pepper", "olive oil", "Italian seasoning", "garlic powder"], instructions: ["Cut sausage into rounds", "Toss all with olive oil and seasonings", "Spread on sheet pan", "Bake at 400F for 22 min"], prepTime: 28, calories: 460, protein: 30, carbs: 36, fat: 22, tags: ["sheet-pan", "meal-prep", "one-pan"]))

        r.append(Recipe(mealType: .dinner, name: "Black Bean Enchiladas", description: "Vegetarian enchiladas with red sauce", ingredients: ["1 can black beans", "1/2 cup corn", "1/2 cup shredded cheese", "4 corn tortillas", "enchilada sauce", "sour cream", "cilantro", "1/4 avocado"], instructions: ["Mix beans, corn, half the cheese", "Fill tortillas, roll, place in baking dish", "Pour enchilada sauce over top", "Sprinkle remaining cheese", "Bake at 375F 20 min", "Top with sour cream, cilantro, avocado"], prepTime: 30, calories: 520, protein: 22, carbs: 62, fat: 22, tags: ["vegetarian", "mexican", "comfort"]))

        r.append(Recipe(mealType: .dinner, name: "Grilled Mahi-Mahi with Mango Salsa", description: "Light fish with tropical fruit salsa", ingredients: ["6 oz mahi-mahi fillet", "1/2 mango diced", "1/4 red onion diced", "jalapeño minced", "cilantro", "lime juice", "1 cup coconut rice", "olive oil"], instructions: ["Season fish, grill 4 min each side", "Mix mango, onion, jalapeño, cilantro, lime for salsa", "Cook rice with splash of coconut milk", "Plate fish over rice, top with salsa"], prepTime: 18, calories: 460, protein: 36, carbs: 48, fat: 12, tags: ["light", "tropical", "high-protein"]))

        r.append(Recipe(mealType: .dinner, name: "Korean Beef Bulgogi Bowl", description: "Sweet-savory marinated beef over rice", ingredients: ["6 oz beef sirloin sliced thin", "soy sauce", "sesame oil", "brown sugar", "garlic", "ginger", "1 cup rice", "kimchi", "steamed spinach", "fried egg", "sesame seeds"], instructions: ["Marinate beef in soy sauce, sesame oil, sugar, garlic, ginger 15 min", "Stir-fry beef on high heat 3 min", "Cook rice", "Build bowl: rice, beef, spinach, kimchi", "Top with fried egg and sesame seeds"], prepTime: 25, calories: 580, protein: 40, carbs: 54, fat: 22, tags: ["korean", "high-protein"]))

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // SNACKS (16)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        r.append(Recipe(mealType: .snack, name: "Protein Shake", description: "Classic whey shake with banana", ingredients: ["1 scoop whey protein", "1 banana", "1 cup almond milk", "ice", "1 tbsp peanut butter"], instructions: ["Blend all ingredients until smooth"], prepTime: 3, calories: 340, protein: 30, carbs: 32, fat: 12, tags: ["quick", "post-workout"]))

        r.append(Recipe(mealType: .snack, name: "Greek Yogurt & Berries", description: "High-protein snack", ingredients: ["1 cup Greek yogurt", "1/2 cup mixed berries", "1 tbsp honey"], instructions: ["Combine and eat"], prepTime: 2, calories: 220, protein: 20, carbs: 28, fat: 4, tags: ["quick", "no-cook"]))

        r.append(Recipe(mealType: .snack, name: "Apple & Almond Butter", description: "Simple clean snack", ingredients: ["1 large apple", "2 tbsp almond butter"], instructions: ["Slice apple", "Dip in almond butter"], prepTime: 2, calories: 280, protein: 6, carbs: 32, fat: 16, tags: ["quick", "no-cook"]))

        r.append(Recipe(mealType: .snack, name: "Cottage Cheese & Pineapple", description: "High-protein, sweet and savory", ingredients: ["1 cup cottage cheese", "1/2 cup pineapple chunks", "pinch of cinnamon"], instructions: ["Top cottage cheese with pineapple and cinnamon"], prepTime: 2, calories: 240, protein: 26, carbs: 22, fat: 4, tags: ["quick", "no-cook", "high-protein"]))

        r.append(Recipe(mealType: .snack, name: "Trail Mix & Protein Bar", description: "Grab-and-go energy", ingredients: ["1 protein bar", "1/4 cup mixed nuts"], instructions: ["Unwrap and eat"], prepTime: 1, calories: 350, protein: 24, carbs: 28, fat: 16, tags: ["quick", "portable"]))

        r.append(Recipe(mealType: .snack, name: "Chocolate Protein Smoothie", description: "Thick and rich chocolate shake", ingredients: ["1 scoop chocolate whey", "1 cup milk", "1/2 banana", "1 tbsp cocoa powder", "ice"], instructions: ["Blend all ingredients until smooth"], prepTime: 3, calories: 300, protein: 28, carbs: 30, fat: 8, tags: ["quick", "post-workout"]))

        r.append(Recipe(mealType: .snack, name: "Hard Boiled Eggs & Hummus", description: "Savory high-protein snack", ingredients: ["2 hard boiled eggs", "2 tbsp hummus", "carrot sticks"], instructions: ["Peel eggs", "Dip in hummus with carrot sticks"], prepTime: 2, calories: 240, protein: 16, carbs: 12, fat: 14, tags: ["meal-prep", "high-protein"]))

        r.append(Recipe(mealType: .snack, name: "Rice Cakes with PB & Banana", description: "Light crunchy snack", ingredients: ["2 rice cakes", "1 tbsp peanut butter", "1/2 banana sliced"], instructions: ["Spread peanut butter on rice cakes", "Top with banana slices"], prepTime: 2, calories: 260, protein: 8, carbs: 38, fat: 10, tags: ["quick", "no-cook"]))

        r.append(Recipe(mealType: .snack, name: "Edamame with Sea Salt", description: "Steamed soybeans with flaky salt", ingredients: ["1 cup edamame in shell", "sea salt"], instructions: ["Steam or microwave edamame 3 min", "Sprinkle with sea salt"], prepTime: 4, calories: 190, protein: 17, carbs: 14, fat: 8, tags: ["vegan", "quick", "high-protein"]))

        r.append(Recipe(mealType: .snack, name: "Turkey Roll-Ups", description: "Deli turkey with cheese and mustard", ingredients: ["4 oz sliced turkey breast", "2 slices Swiss cheese", "mustard", "pickle spear"], instructions: ["Lay turkey slices flat", "Place cheese and mustard on each", "Roll up tight", "Serve with pickle"], prepTime: 3, calories: 220, protein: 28, carbs: 4, fat: 10, tags: ["low-carb", "high-protein", "no-cook", "keto"]))

        r.append(Recipe(mealType: .snack, name: "Mango Lassi Smoothie", description: "Indian-inspired yogurt drink", ingredients: ["1/2 cup mango frozen", "1/2 cup Greek yogurt", "1/2 cup milk", "1 tsp honey", "pinch of cardamom"], instructions: ["Blend all ingredients until smooth"], prepTime: 3, calories: 240, protein: 14, carbs: 36, fat: 4, tags: ["quick", "indian"]))

        r.append(Recipe(mealType: .snack, name: "Cucumber & Cream Cheese Bites", description: "Cool, crunchy, and satisfying", ingredients: ["1 cucumber sliced", "2 oz cream cheese", "everything bagel seasoning", "smoked salmon (optional)"], instructions: ["Spread cream cheese on cucumber rounds", "Sprinkle with seasoning", "Top with salmon if desired"], prepTime: 5, calories: 180, protein: 8, carbs: 6, fat: 14, tags: ["low-carb", "no-cook", "keto"]))

        r.append(Recipe(mealType: .snack, name: "Energy Balls", description: "No-bake oat and nut butter bites", ingredients: ["1 cup rolled oats", "1/2 cup peanut butter", "1/4 cup honey", "2 tbsp chocolate chips", "1 tbsp chia seeds"], instructions: ["Mix all ingredients in bowl", "Refrigerate 20 min", "Roll into 10 balls", "Store in fridge up to 5 days"], prepTime: 10, calories: 280, protein: 10, carbs: 32, fat: 14, tags: ["meal-prep", "portable", "no-cook"]))

        r.append(Recipe(mealType: .snack, name: "Roasted Chickpeas", description: "Crunchy, spiced snack", ingredients: ["1 can chickpeas drained", "1 tbsp olive oil", "1/2 tsp cumin", "1/2 tsp paprika", "salt"], instructions: ["Pat chickpeas dry", "Toss with oil and spices", "Bake at 400F for 25 min, stirring halfway", "Cool before eating"], prepTime: 30, calories: 240, protein: 12, carbs: 30, fat: 8, tags: ["vegan", "high-fiber", "meal-prep"]))

        r.append(Recipe(mealType: .snack, name: "Tuna Salad Lettuce Cups", description: "Protein-packed low-carb cups", ingredients: ["1 can tuna drained", "1 tbsp mayo", "celery diced", "lemon juice", "salt & pepper", "butter lettuce leaves"], instructions: ["Mix tuna, mayo, celery, lemon", "Spoon into lettuce cups"], prepTime: 5, calories: 200, protein: 26, carbs: 2, fat: 10, tags: ["low-carb", "high-protein", "no-cook", "keto"]))

        r.append(Recipe(mealType: .snack, name: "Frozen Yogurt Bark", description: "Sweet frozen treat with toppings", ingredients: ["2 cups Greek yogurt", "2 tbsp honey", "1/4 cup berries", "2 tbsp dark chocolate chips", "2 tbsp granola"], instructions: ["Mix yogurt and honey", "Spread on parchment-lined sheet pan", "Top with berries, chocolate, granola", "Freeze 2 hours", "Break into pieces"], prepTime: 10, calories: 260, protein: 18, carbs: 34, fat: 8, tags: ["meal-prep", "dessert"]))

        return r
    }()
    // swiftlint:enable function_body_length
}
