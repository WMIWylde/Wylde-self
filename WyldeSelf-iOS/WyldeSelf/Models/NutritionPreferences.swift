import Foundation

// MARK: - Dietary Framework

enum FrameworkCategory: String, Codable, CaseIterable {
    case general = "General"
    case performance = "Performance"
    case plantForward = "Plant-Forward"
    case elimination = "Elimination"
    case medical = "Medical"
}

enum DietaryFramework: String, Codable, CaseIterable, Identifiable {
    case balancedWholeFood = "balanced_whole_food"
    case highProtein = "high_protein"
    case mediterranean = "mediterranean"
    case keto = "keto"
    case lowCarb = "low_carb"
    case paleo = "paleo"
    case whole30 = "whole30"
    case plantBased = "plant_based"
    case vegetarian = "vegetarian"
    case vegan = "vegan"
    case pescatarian = "pescatarian"
    case antiInflammatory = "anti_inflammatory"
    case lowGlycemic = "low_glycemic"
    case dash = "dash"
    case glutenFree = "gluten_free"
    case dairyFree = "dairy_free"
    case lowHistamine = "low_histamine"
    case lowFODMAP = "low_fodmap"
    case autoimmune = "autoimmune"
    case gerdFriendly = "gerd_friendly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .balancedWholeFood: return "Balanced Whole Foods"
        case .highProtein: return "High Protein"
        case .mediterranean: return "Mediterranean"
        case .keto: return "Keto"
        case .lowCarb: return "Low Carb"
        case .paleo: return "Paleo"
        case .whole30: return "Whole30"
        case .plantBased: return "Plant-Based"
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .pescatarian: return "Pescatarian"
        case .antiInflammatory: return "Anti-Inflammatory"
        case .lowGlycemic: return "Low Glycemic"
        case .dash: return "DASH"
        case .glutenFree: return "Gluten-Free"
        case .dairyFree: return "Dairy-Free"
        case .lowHistamine: return "Low Histamine"
        case .lowFODMAP: return "Low FODMAP"
        case .autoimmune: return "Autoimmune Protocol"
        case .gerdFriendly: return "GERD / Reflux-Friendly"
        }
    }

    var description: String {
        switch self {
        case .balancedWholeFood: return "Minimally processed foods across all food groups"
        case .highProtein: return "Emphasizes protein for muscle building and satiety"
        case .mediterranean: return "Rich in olive oil, fish, vegetables, and whole grains"
        case .keto: return "Very low carb, high fat to promote ketosis"
        case .lowCarb: return "Reduced carbohydrate intake without strict ketosis"
        case .paleo: return "Whole foods based on ancestral eating patterns"
        case .whole30: return "30-day elimination of sugar, grains, dairy, and legumes"
        case .plantBased: return "Primarily plants with minimal animal products"
        case .vegetarian: return "No meat or fish, includes dairy and eggs"
        case .vegan: return "No animal products of any kind"
        case .pescatarian: return "Vegetarian plus fish and seafood"
        case .antiInflammatory: return "Foods that reduce systemic inflammation"
        case .lowGlycemic: return "Foods that minimally impact blood sugar"
        case .dash: return "Designed to support healthy blood pressure"
        case .glutenFree: return "Excludes all gluten-containing grains"
        case .dairyFree: return "Excludes all dairy products"
        case .lowHistamine: return "Avoids aged, fermented, and high-histamine foods"
        case .lowFODMAP: return "Limits fermentable carbohydrates for digestive health"
        case .autoimmune: return "Elimination protocol for autoimmune conditions"
        case .gerdFriendly: return "Avoids common reflux triggers"
        }
    }

    var isMedicallySupervised: Bool {
        switch self {
        case .lowHistamine, .lowFODMAP, .autoimmune, .gerdFriendly, .dash:
            return true
        default:
            return false
        }
    }

    var medicalDisclaimer: String? {
        guard isMedicallySupervised else { return nil }
        switch self {
        case .lowFODMAP:
            return "Low FODMAP is designed as a short-term elimination protocol with structured reintroduction. Individual tolerance varies. Work with a dietitian for best results."
        case .lowHistamine:
            return "Histamine content varies with food freshness, storage, and preparation. Individual tolerance differs significantly. Consider working with a healthcare provider."
        case .autoimmune:
            return "The autoimmune protocol is an elimination diet that should be supervised by a healthcare professional familiar with your condition."
        case .gerdFriendly:
            return "Reflux triggers vary by individual. This plan avoids common triggers but may need adjustment based on your experience."
        case .dash:
            return "DASH was developed for blood pressure management. If you have a medical condition, consult your healthcare provider."
        default:
            return nil
        }
    }

    var category: FrameworkCategory {
        switch self {
        case .balancedWholeFood, .mediterranean, .lowGlycemic:
            return .general
        case .highProtein, .keto, .lowCarb, .paleo, .whole30:
            return .performance
        case .plantBased, .vegetarian, .vegan, .pescatarian:
            return .plantForward
        case .glutenFree, .dairyFree, .antiInflammatory:
            return .elimination
        case .lowHistamine, .lowFODMAP, .autoimmune, .gerdFriendly, .dash:
            return .medical
        }
    }

    static var groupedByCategory: [(FrameworkCategory, [DietaryFramework])] {
        FrameworkCategory.allCases.map { cat in
            (cat, allCases.filter { $0.category == cat })
        }
    }
}

// MARK: - Nutrition Goal

enum NutritionGoal: String, Codable, CaseIterable, Identifiable {
    case fatLoss = "fat_loss"
    case maintainWeight = "maintain_weight"
    case buildMuscle = "build_muscle"
    case bodyRecomp = "body_recomp"
    case improveEnergy = "improve_energy"
    case improveDigestion = "improve_digestion"
    case metabolicHealth = "metabolic_health"
    case reduceInflammation = "reduce_inflammation"
    case heartHealth = "heart_health"
    case athleticPerformance = "athletic_performance"
    case healthyAging = "healthy_aging"
    case generalWellness = "general_wellness"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fatLoss: return "Fat Loss"
        case .maintainWeight: return "Maintain Weight"
        case .buildMuscle: return "Build Muscle"
        case .bodyRecomp: return "Body Recomposition"
        case .improveEnergy: return "Improve Energy"
        case .improveDigestion: return "Improve Digestion"
        case .metabolicHealth: return "Metabolic Health"
        case .reduceInflammation: return "Reduce Inflammation"
        case .heartHealth: return "Heart Health"
        case .athleticPerformance: return "Athletic Performance"
        case .healthyAging: return "Healthy Aging"
        case .generalWellness: return "General Wellness"
        }
    }
}

// MARK: - Restriction

enum Restriction: String, Codable, CaseIterable, Identifiable {
    case glutenFree = "gluten_free"
    case dairyFree = "dairy_free"
    case eggFree = "egg_free"
    case nutFree = "nut_free"
    case peanutFree = "peanut_free"
    case soyFree = "soy_free"
    case shellfishFree = "shellfish_free"
    case fishFree = "fish_free"
    case sesameFree = "sesame_free"
    case cornFree = "corn_free"
    case porkFree = "pork_free"
    case redMeatFree = "red_meat_free"
    case halal = "halal"
    case kosher = "kosher"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .glutenFree: return "Gluten-Free"
        case .dairyFree: return "Dairy-Free"
        case .eggFree: return "Egg-Free"
        case .nutFree: return "Nut-Free"
        case .peanutFree: return "Peanut-Free"
        case .soyFree: return "Soy-Free"
        case .shellfishFree: return "Shellfish-Free"
        case .fishFree: return "Fish-Free"
        case .sesameFree: return "Sesame-Free"
        case .cornFree: return "Corn-Free"
        case .porkFree: return "Pork-Free"
        case .redMeatFree: return "Red Meat-Free"
        case .halal: return "Halal"
        case .kosher: return "Kosher"
        case .other: return "Other"
        }
    }

    /// Ingredient keywords that indicate this allergen is present
    var ingredientKeywords: [String] {
        switch self {
        case .glutenFree: return ["wheat", "flour", "bread", "pasta", "barley", "rye", "couscous", "bulgur", "semolina", "farro", "spelt", "tortilla", "crouton", "panko", "breadcrumb", "naan", "pita", "sourdough", "bagel"]
        case .dairyFree: return ["milk", "cheese", "butter", "cream", "yogurt", "whey", "casein", "mozzarella", "parmesan", "feta", "cheddar", "cottage cheese", "sour cream", "ricotta", "ghee"]
        case .eggFree: return ["egg", "eggs", "mayo", "mayonnaise", "meringue", "custard"]
        case .nutFree: return ["almond", "walnut", "cashew", "pecan", "pistachio", "macadamia", "hazelnut", "brazil nut", "pine nut", "nut butter", "almond butter", "almond milk"]
        case .peanutFree: return ["peanut", "peanut butter", "peanut oil"]
        case .soyFree: return ["soy", "soy sauce", "tofu", "tempeh", "edamame", "miso", "soybean"]
        case .shellfishFree: return ["shrimp", "crab", "lobster", "crawfish", "clam", "mussel", "oyster", "scallop", "squid", "calamari"]
        case .fishFree: return ["salmon", "tuna", "cod", "tilapia", "halibut", "sardine", "anchovy", "trout", "mackerel", "swordfish", "mahi", "bass", "catfish", "fish"]
        case .sesameFree: return ["sesame", "tahini", "sesame oil", "sesame seeds"]
        case .cornFree: return ["corn", "cornmeal", "cornstarch", "corn tortilla", "polenta", "grits"]
        case .porkFree: return ["pork", "bacon", "ham", "sausage", "prosciutto", "pancetta", "chorizo"]
        case .redMeatFree: return ["beef", "steak", "ground beef", "lamb", "bison", "venison", "veal"]
        case .halal: return ["pork", "bacon", "ham", "prosciutto", "pancetta", "lard", "gelatin"]
        case .kosher: return ["pork", "bacon", "ham", "shellfish", "shrimp", "crab", "lobster"]
        case .other: return []
        }
    }
}

// MARK: - Cooking Skill

enum CookingSkill: String, Codable, CaseIterable, Identifiable {
    case beginner = "beginner"
    case comfortable = "comfortable"
    case confident = "confident"
    case advanced = "advanced"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .comfortable: return "Comfortable"
        case .confident: return "Confident"
        case .advanced: return "Advanced"
        }
    }
}

// MARK: - Appliance

enum Appliance: String, Codable, CaseIterable, Identifiable {
    case oven = "oven"
    case stovetop = "stovetop"
    case microwave = "microwave"
    case airFryer = "air_fryer"
    case slowCooker = "slow_cooker"
    case instantPot = "instant_pot"
    case blender = "blender"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oven: return "Oven"
        case .stovetop: return "Stovetop"
        case .microwave: return "Microwave"
        case .airFryer: return "Air Fryer"
        case .slowCooker: return "Slow Cooker"
        case .instantPot: return "Instant Pot"
        case .blender: return "Blender"
        }
    }
}

// MARK: - Preference Source

enum PreferenceSource: String, Codable {
    case user = "user"
    case ai = "ai"
    case careTeam = "care-team"
}

// MARK: - Nutrition Preferences

struct NutritionPreferences: Codable, Equatable {
    // Primary direction
    var dietaryFramework: DietaryFramework?

    // Goals
    var goals: [NutritionGoal]

    // Hard exclusions
    var restrictions: [Restriction]
    var otherRestrictionText: String

    // Food preferences
    var favoriteFoods: [String]
    var dislikedFoods: [String]
    var excludedFoods: [String]
    var preferredProteins: [String]
    var preferredCuisines: [String]

    // Meal structure
    var mealsPerDay: Int
    var snacksPerDay: Int
    var includeBreakfast: Bool
    var eatingWindowStart: String?
    var eatingWindowEnd: String?
    var intermittentFasting: Bool
    var mealPrepDays: [String]
    var leftoversAllowed: Bool
    var repeatMealsAllowed: Bool
    var householdSize: Int

    // Lifestyle
    var cookingSkill: CookingSkill?
    var maxCookingMinutes: Int?
    var weeklyBudget: String?
    var availableAppliances: [Appliance]

    // Optional nutrition targets
    var calorieTarget: Int?
    var proteinTarget: Int?
    var carbTarget: Int?
    var fatTarget: Int?
    var fiberTarget: Int?

    // Meta
    var clinicalNotes: String
    var source: PreferenceSource
    var updatedAt: Date

    // MARK: - Computed

    var hasMedicalFramework: Bool {
        dietaryFramework?.isMedicallySupervised == true
    }

    // MARK: - Default

    static var `default`: NutritionPreferences {
        NutritionPreferences(
            dietaryFramework: nil,
            goals: [],
            restrictions: [],
            otherRestrictionText: "",
            favoriteFoods: [],
            dislikedFoods: [],
            excludedFoods: [],
            preferredProteins: [],
            preferredCuisines: [],
            mealsPerDay: 3,
            snacksPerDay: 1,
            includeBreakfast: true,
            eatingWindowStart: nil,
            eatingWindowEnd: nil,
            intermittentFasting: false,
            mealPrepDays: [],
            leftoversAllowed: true,
            repeatMealsAllowed: true,
            householdSize: 1,
            cookingSkill: nil,
            maxCookingMinutes: nil,
            weeklyBudget: nil,
            availableAppliances: [],
            calorieTarget: nil,
            proteinTarget: nil,
            carbTarget: nil,
            fatTarget: nil,
            fiberTarget: nil,
            clinicalNotes: "",
            source: .user,
            updatedAt: Date()
        )
    }

    // MARK: - Legacy Migration

    static func migrateFromLegacy(dietaryPrefs: [String], dietNotes: String) -> NutritionPreferences {
        var prefs = NutritionPreferences.default

        // Map legacy strings to framework and restrictions
        let frameworkMap: [String: DietaryFramework] = [
            "Vegetarian": .vegetarian,
            "Vegan": .vegan,
            "Keto": .keto,
            "Paleo": .paleo,
        ]

        let restrictionMap: [String: Restriction] = [
            "Gluten-free": .glutenFree,
            "Dairy-free": .dairyFree,
            "Halal": .halal,
            "Kosher": .kosher,
            "Nut allergy": .nutFree,
            "Shellfish allergy": .shellfishFree,
        ]

        for pref in dietaryPrefs {
            if pref == "No restrictions" { continue }
            if let framework = frameworkMap[pref], prefs.dietaryFramework == nil {
                prefs.dietaryFramework = framework
            } else if let restriction = restrictionMap[pref] {
                if !prefs.restrictions.contains(restriction) {
                    prefs.restrictions.append(restriction)
                }
            }
        }

        if !dietNotes.isEmpty {
            prefs.clinicalNotes = dietNotes
        }

        prefs.updatedAt = Date()
        return prefs
    }
}
