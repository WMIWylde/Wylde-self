import SwiftUI
import Combine

class AppState: ObservableObject {
    // Tab — not persisted (always start on Today)
    @Published var selectedTab: Tab = .today

    // Appearance — "dark" (default, matches web), "light", or "system"
    @Published var appearanceMode: String = "dark"                   { didSet { defaults.set(appearanceMode, forKey: "wylde_appearance") } }
    var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "dark": return .dark
        case "light": return .light
        default: return nil  // "system" follows device
        }
    }

    // Auth / profile — persisted
    @Published var isAuthenticated = false                          { didSet { defaults.set(isAuthenticated, forKey: "wylde_authed") } }
    @Published var userName: String = ""                            { didSet { defaults.set(userName, forKey: "wylde_name") } }
    /// Current day in the transformation — calculated from start date, auto-advances daily.
    @Published var currentDay: Int = 1
    @Published var streak: Int = 0                                  { didSet { defaults.set(streak, forKey: "wylde_streak") } }

    /// Dates ("yyyy-MM-dd") on which the user has "closed the loop"
    /// (completed Evening Reflection). Set-like semantics — a date is
    /// only recorded once no matter how many times the reflection is
    /// re-opened. Used to display "N of M closed" progress.
    @Published private(set) var completedDates: [String] = []       { didSet { defaults.set(completedDates, forKey: "wylde_days_completed") } }

    /// Total days the user has closed the loop, lifetime.
    /// Always ≤ currentDay. Used as the numerator of the "closed / started"
    /// progress display in the Today hero and You profile chip.
    var completedDays: Int { completedDates.count }
    // XP is now a silent internal counter — used for analytics + future
    // identity-driven badges, never surfaced as a level/rank.
    @Published var xp: Int = 0                                      { didSet { defaults.set(xp, forKey: "wylde_xp") } }

    // Profile
    // Empty default keeps the core app inclusive — Wylde Self should not
    // assume a gender. The user can set this explicitly during onboarding.
    // Existing users who already chose "Male"/"Female" keep their value
    // because loadFromDefaults reads the persisted string.
    //
    // Sensitive fields (gender, age, weight, height, health, diet) use
    // SecureStorage (Keychain) instead of UserDefaults.
    @Published var gender: String = ""                              { didSet { guard !isLoading else { return }; secure.set(gender, forKey: "wylde_gender") } }
    @Published var goals: [String] = []                             { didSet { defaults.set(goals, forKey: "wylde_goals") } }
    /// The user's identity statement — who they are becoming. Set during
    /// onboarding or editable in You tab. This is the emotional anchor
    /// that every daily action ties back to.
    @Published var identityStatement: String = ""                    { didSet { defaults.set(identityStatement, forKey: "wylde_identity_statement") } }
    @Published var gymName: String = ""                             { didSet { defaults.set(gymName, forKey: "wylde_gym") } }
    @Published var onboardingComplete: Bool = false                  { didSet { defaults.set(onboardingComplete, forKey: "wylde_onboarded") } }
    @Published var ageRange: String = ""                             { didSet { guard !isLoading else { return }; secure.set(ageRange, forKey: "wylde_age") } }
    @Published var fitnessLevel: String = ""                         { didSet { defaults.set(fitnessLevel, forKey: "wylde_level") } }
    @Published var trainingStyle: String = ""                        { didSet { defaults.set(trainingStyle, forKey: "wylde_training_style") } }
    @Published var trainingDays: String = ""                         { didSet { defaults.set(trainingDays, forKey: "wylde_days") } }
    @Published var equipment: String = ""                            { didSet { defaults.set(equipment, forKey: "wylde_equipment") } }
    @Published var gymAccess: String = ""                            { didSet { defaults.set(gymAccess, forKey: "wylde_gym_access") } }
    @Published var heightRange: String = ""                          { didSet { guard !isLoading else { return }; secure.set(heightRange, forKey: "wylde_height") } }
    @Published var weight: String = ""                               { didSet { guard !isLoading else { return }; secure.set(weight, forKey: "wylde_weight") } }
    @Published var weightUnit: String = "lbs"                        { didSet { defaults.set(weightUnit, forKey: "wylde_weight_unit") } }
    @Published var healthConcerns: [String] = []                     { didSet { guard !isLoading else { return }; secure.setCodable(healthConcerns, forKey: "wylde_health") } }
    @Published var healthNotes: String = ""                          { didSet { guard !isLoading else { return }; secure.set(healthNotes, forKey: "wylde_health_notes") } }
    @Published var dietaryPrefs: [String] = []                       { didSet { guard !isLoading else { return }; secure.setCodable(dietaryPrefs, forKey: "wylde_diet") } }
    @Published var dietNotes: String = ""                            { didSet { guard !isLoading else { return }; secure.set(dietNotes, forKey: "wylde_diet_notes") } }
    @Published var classPreferences: [String] = []                   { didSet { defaults.set(classPreferences, forKey: "wylde_classes") } }
    @Published var currentBook: String = ""                            { didSet { defaults.set(currentBook, forKey: "wylde_book") } }
    @Published var pagesReadToday: Int = 0                             { didSet { defaults.set(pagesReadToday, forKey: dayKey("wylde_pages")) } }

    // Pro entitlement — cached locally for instant UI, refreshed from
    // RevenueCat on launch + when the SDK posts an entitlement change.
    @Published var proStatus: String = "free"                       { didSet { defaults.set(proStatus, forKey: "wylde_pro_status") } }
    @Published var foundingMemberNumber: Int = 0                    { didSet { defaults.set(foundingMemberNumber, forKey: "wylde_founder_number") } }
    @Published var proProvider: String = ""                         { didSet { defaults.set(proProvider, forKey: "wylde_pro_provider") } }
    /// Convenience — true if any active Pro tier (lifetime/annual/monthly).
    var isPro: Bool {
        return proStatus == "lifetime" || proStatus == "annual" || proStatus == "monthly"
    }
    /// Convenience — true if user has a founding_member_number (1\u20131000).
    var isFoundingMember: Bool {
        return foundingMemberNumber > 0 && foundingMemberNumber <= 1000
    }

    // Identity Import — cached profile (fetched from Supabase via the
    // /api/identity-analyze endpoint). Persisted as encoded JSON so the
    // result screen renders instantly on cold launch.
    @Published var identityProfile: IdentityProfile? {
        didSet { guard !isLoading else { return }; secure.setCodable(identityProfile, forKey: "wylde_identity_profile") }
    }
    var hasIdentityProfile: Bool { identityProfile != nil }

    // Morning Protocol — three fixed practices, persisted as completion flags
    // per day. No more "user picks 3-5" — the protocol IS the practice.
    @Published var morningProtocolActions: [MorningAction] = AppState.defaultMorningActions {
        didSet { saveCodable(morningProtocolActions, key: dayKey("wylde_morning_actions")) }
    }
    @Published var morningProtocolCompleted: Bool = false           { didSet { defaults.set(morningProtocolCompleted, forKey: dayKey("wylde_morning_done")) } }

    // Daily long walk — separate from training, mid-day movement
    @Published var dailyWalkCompleted: Bool = false                 { didSet { defaults.set(dailyWalkCompleted, forKey: dayKey("wylde_walk_done")) } }

    // Today — daily state, scoped by day-of-year so it auto-resets at midnight
    @Published var workoutCompleted: Bool = false                   { didSet { defaults.set(workoutCompleted, forKey: dayKey("wylde_workout_done")) } }
    @Published var proteinLogged: Int = 0                           { didSet { defaults.set(proteinLogged, forKey: dayKey("wylde_protein_logged")) } }
    @Published var proteinGoal: Int = 180                           { didSet { defaults.set(proteinGoal, forKey: "wylde_protein_goal") } }
    @Published var caloriesLogged: Int = 0                          { didSet { defaults.set(caloriesLogged, forKey: dayKey("wylde_calories_logged")) } }
    @Published var caloriesGoal: Int = 2400                         { didSet { defaults.set(caloriesGoal, forKey: "wylde_calories_goal") } }
    @Published var carbsLogged: Int = 0                              { didSet { defaults.set(carbsLogged, forKey: dayKey("wylde_carbs_logged")) } }
    @Published var carbsGoal: Int = 250                              { didSet { defaults.set(carbsGoal, forKey: "wylde_carbs_goal") } }
    @Published var fatLogged: Int = 0                                { didSet { defaults.set(fatLogged, forKey: dayKey("wylde_fat_logged")) } }
    @Published var fatGoal: Int = 80                                 { didSet { defaults.set(fatGoal, forKey: "wylde_fat_goal") } }
    @Published var caloriesBurned: Int = 0                           { didSet { defaults.set(caloriesBurned, forKey: dayKey("wylde_calories_burned")) } }
    @Published var waterLogged: Int = 0                              { didSet { defaults.set(waterLogged, forKey: dayKey("wylde_water_logged")) } }
    @Published var waterGoal: Int = 8                                { didSet { defaults.set(waterGoal, forKey: "wylde_water_goal") } }
    @Published var eveningReflectionDone: Bool = false               { didSet { defaults.set(eveningReflectionDone, forKey: dayKey("wylde_reflection_done")) } }

    enum Tab: String, CaseIterable {
        case today     = "Today"
        case nutrition = "Nutrition"
        case future    = "Future"
        case settings  = "You"

        var icon: String {
            switch self {
            case .today:     return "sun.horizon.fill"
            case .nutrition: return "leaf.fill"
            case .future:    return "figure.walk.motion"
            case .settings:  return "person.crop.circle.fill"
            }
        }
    }

    // MARK: - Default Morning Practices
    // Three fixed practices — meditation, journaling, reading. Workout is
    // not part of morning protocol because it lives in the daily routine.
    static let defaultMorningActions: [MorningAction] = [
        MorningAction(id: "qigong",     name: "Energy Movement", desc: "5-7 minutes of slow, intentional movement. Wake up the body's energy, loosen the joints, connect breath to motion.", dur: 7),
        MorningAction(id: "meditation", name: "Meditation", desc: "10 minutes of stillness. This is how you train your mind to be calm under pressure.", dur: 10),
        MorningAction(id: "journaling", name: "Journaling", desc: "Write what's on your mind, what you're grateful for, and what you're building. Clarity comes from the page, not the screen.", dur: 10),
        MorningAction(id: "reading",    name: "Reading",    desc: "15 minutes of deliberate input. Feed your mind something that makes you sharper, calmer, or more capable.", dur: 15)
    ]

    // MARK: - Persistence

    private let defaults = UserDefaults.standard
    private let secure = SecureStorage.shared
    // Suspend didSet writes during the initial load so we don't write the
    // defaults back over themselves (also avoids redundant disk hits).
    private var isLoading = true

    init() {
        // Must run before loadFromDefaults() so any stub-persisted Pro is
        // wiped before the cached values are read back into memory.
        clearStubProIfNeeded()
        loadFromDefaults()
        refreshCurrentDay()
        isLoading = false
        // Listen for purchase state changes from PurchaseManager so we
        // can update the cached Pro fields + push to Supabase.
        NotificationCenter.default.addObserver(
            forName: .wyldeProEntitlementChanged,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self else { return }
            if let status = note.userInfo?["status"] as? String {
                self.proStatus = status
                self.proProvider = "apple"
                // Webhook will assign the founding number server-side; we
                // optimistically bump locally too so the UI is instant.
                if self.foundingMemberNumber == 0 {
                    // Optimistic — server will reconcile to the real number
                    self.foundingMemberNumber = 1
                }
            }
        }
        // Roll the day counter forward automatically at midnight — even
        // when the app has been open all day. iOS posts
        // NSCalendarDayChanged whenever the calendar day flips (including
        // on timezone changes).
        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshCurrentDay()
            // Reload day-scoped state so in-memory daily counters reset to
            // the new day's (empty) values instead of persisting yesterday's
            // numbers under today's key.
            self?.loadFromDefaults()
        }
    }

    /// One-time cleanup for testers who were on the stub PurchaseManager.
    /// Earlier builds ran with `useRealRevenueCat = false`, which persisted a
    /// fake `wylde_pro_status = "lifetime"` + `wylde_founder_number = 1`. Now
    /// that entitlement comes ONLY from RevenueCat, clear those stub values a
    /// single time so previously-faked testers don't keep fake Pro.
    /// RevenueCat's refreshEntitlement() re-populates the real value on launch.
    private func clearStubProIfNeeded() {
        let flag = "wylde_stub_pro_cleared_v1"
        guard !defaults.bool(forKey: flag) else { return }
        defaults.removeObject(forKey: "wylde_pro_status")
        defaults.removeObject(forKey: "wylde_founder_number")
        defaults.removeObject(forKey: "wylde_pro_provider")
        defaults.set(true, forKey: flag)
    }

    /// Date-scoped key so daily counters reset automatically at midnight.
    /// Pins locale + calendar so the "yyyy-MM-dd" string is always Gregorian
    /// regardless of the device's regional calendar setting.
    private func dayKey(_ base: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return base + "_" + f.string(from: Date())
    }

    /// Compute current day from start date. Called on every app launch,
    /// foreground return, AND at midnight (via NSCalendarDayChanged
    /// observer set up in init) so the counter advances even if the app
    /// is open across the day boundary.
    ///
    /// The computed value is persisted back to defaults so
    /// loadFromDefaults() doesn't read a stale "yesterday" value the next
    /// time it runs.
    func refreshCurrentDay() {
        // Set start date on first run (when onboarding completes)
        let key = "wylde_start_date"
        let startDate: Date
        if let stored = defaults.object(forKey: key) as? Date {
            startDate = stored
        } else {
            // First time — set today as day 1
            startDate = Calendar.current.startOfDay(for: Date())
            defaults.set(startDate, forKey: key)
        }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: startDate),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        let computed = max(1, days + 1)
        if computed != currentDay {
            currentDay = computed
        }
        // Persist even if unchanged, so loadFromDefaults() always sees the
        // freshest value on next launch (there's no didSet on currentDay).
        defaults.set(computed, forKey: "wylde_day")
    }

    private func saveCodable<T: Encodable>(_ value: T, key: String) {
        guard !isLoading else { return }
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func loadCodable<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Marks today as a day where the user closed the loop. Called from
    /// EveningReflectionView when the reflection is submitted. Idempotent
    /// — re-opening + re-submitting the reflection on the same day does
    /// not double-count.
    func markLoopClosed() {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())
        guard !completedDates.contains(today) else { return }
        completedDates.append(today)
    }

    func loadFromDefaults() {
        appearanceMode = defaults.string(forKey: "wylde_appearance") ?? "dark"
        userName = defaults.string(forKey: "wylde_name") ?? ""
        currentDay = defaults.integer(forKey: "wylde_day")
        if currentDay == 0 { currentDay = 1 }
        streak = defaults.integer(forKey: "wylde_streak")
        completedDates = defaults.stringArray(forKey: "wylde_days_completed") ?? []
        xp = defaults.integer(forKey: "wylde_xp")
        // Sensitive fields — read from Keychain (SecureStorage), falling
        // back to UserDefaults for migration from pre-encryption installs.
        gender = secure.get(forKey: "wylde_gender") ?? defaults.string(forKey: "wylde_gender") ?? ""
        goals = defaults.stringArray(forKey: "wylde_goals") ?? []
        identityStatement = defaults.string(forKey: "wylde_identity_statement") ?? ""
        gymName = defaults.string(forKey: "wylde_gym") ?? ""
        onboardingComplete = defaults.bool(forKey: "wylde_onboarded")
        ageRange = secure.get(forKey: "wylde_age") ?? defaults.string(forKey: "wylde_age") ?? ""
        fitnessLevel = defaults.string(forKey: "wylde_level") ?? ""
        trainingStyle = defaults.string(forKey: "wylde_training_style") ?? ""
        trainingDays = defaults.string(forKey: "wylde_days") ?? ""
        equipment = defaults.string(forKey: "wylde_equipment") ?? ""
        gymAccess = defaults.string(forKey: "wylde_gym_access") ?? ""
        heightRange = secure.get(forKey: "wylde_height") ?? defaults.string(forKey: "wylde_height") ?? ""
        weight = secure.get(forKey: "wylde_weight") ?? defaults.string(forKey: "wylde_weight") ?? ""
        weightUnit = defaults.string(forKey: "wylde_weight_unit") ?? "lbs"
        healthConcerns = secure.getCodable([String].self, forKey: "wylde_health") ?? defaults.stringArray(forKey: "wylde_health") ?? []
        healthNotes = secure.get(forKey: "wylde_health_notes") ?? defaults.string(forKey: "wylde_health_notes") ?? ""
        dietaryPrefs = secure.getCodable([String].self, forKey: "wylde_diet") ?? defaults.stringArray(forKey: "wylde_diet") ?? []
        dietNotes = secure.get(forKey: "wylde_diet_notes") ?? defaults.string(forKey: "wylde_diet_notes") ?? ""

        // One-time migration to structured nutrition preferences
        if !defaults.bool(forKey: "wylde_nutrition_prefs_migrated") && !dietaryPrefs.isEmpty {
            let migrated = NutritionPreferences.migrateFromLegacy(dietaryPrefs: dietaryPrefs, dietNotes: dietNotes)
            secure.setCodable(migrated, forKey: "wylde_nutrition_prefs")
            defaults.set(true, forKey: "wylde_nutrition_prefs_migrated")
            Task { @MainActor in
                NutritionPreferencesService.shared.preferences = migrated
            }
        }
        classPreferences = defaults.stringArray(forKey: "wylde_classes") ?? []
        currentBook = defaults.string(forKey: "wylde_book") ?? ""
        pagesReadToday = defaults.integer(forKey: dayKey("wylde_pages"))
        eveningReflectionDone = defaults.bool(forKey: dayKey("wylde_reflection_done"))

        // Pro entitlement — cached locally for instant UI on launch.
        // Source of truth is RevenueCat / Supabase; this is just the
        // last-known value so the UI doesn't flicker free→pro on cold start.
        proStatus = defaults.string(forKey: "wylde_pro_status") ?? "free"
        foundingMemberNumber = defaults.integer(forKey: "wylde_founder_number")
        proProvider = defaults.string(forKey: "wylde_pro_provider") ?? ""

        // Identity profile — cached in Keychain for instant render on cold launch.
        // Falls back to UserDefaults for migration from pre-encryption installs.
        identityProfile = secure.getCodable(IdentityProfile.self, forKey: "wylde_identity_profile")
            ?? loadCodable(IdentityProfile.self, key: "wylde_identity_profile")

        // Morning protocol — date-scoped so it resets each day. Load any
        // state persisted under TODAY's key; a fresh day has no entry, so
        // loadCodable returns nil → the canonical defaults (all completed=false)
        // are used, which is the daily reset. Also reconcile against the
        // canonical 3 practices so old multi-action protocols collapse down.
        let saved = loadCodable([MorningAction].self, key: dayKey("wylde_morning_actions")) ?? []
        let canonicalIds = Set(AppState.defaultMorningActions.map { $0.id })
        let savedIds = Set(saved.map { $0.id })
        if savedIds == canonicalIds {
            // Same set, saved earlier today — keep their completion state
            morningProtocolActions = saved
        } else {
            // Fresh day (nil) or stale set — reset to canonical defaults
            morningProtocolActions = AppState.defaultMorningActions
        }
        // Fresh day has no entry under today's key → defaults to false (reset).
        morningProtocolCompleted = defaults.bool(forKey: dayKey("wylde_morning_done"))

        // Daily walk — date-scoped
        dailyWalkCompleted = defaults.bool(forKey: dayKey("wylde_walk_done"))

        // Daily state — scoped to today, so naturally empty on a fresh day
        workoutCompleted = defaults.bool(forKey: dayKey("wylde_workout_done"))
        proteinLogged = defaults.integer(forKey: dayKey("wylde_protein_logged"))
        caloriesLogged = defaults.integer(forKey: dayKey("wylde_calories_logged"))
        carbsLogged = defaults.integer(forKey: dayKey("wylde_carbs_logged"))
        fatLogged = defaults.integer(forKey: dayKey("wylde_fat_logged"))
        caloriesBurned = defaults.integer(forKey: dayKey("wylde_calories_burned"))
        waterLogged = defaults.integer(forKey: dayKey("wylde_water_logged"))

        // Goals carry over day-to-day, only reset when user changes them
        let pg = defaults.integer(forKey: "wylde_protein_goal")
        if pg > 0 { proteinGoal = pg }
        let cg = defaults.integer(forKey: "wylde_calories_goal")
        if cg > 0 { caloriesGoal = cg }
        let cbg = defaults.integer(forKey: "wylde_carbs_goal")
        if cbg > 0 { carbsGoal = cbg }
        let fg = defaults.integer(forKey: "wylde_fat_goal")
        if fg > 0 { fatGoal = fg }
        let wg = defaults.integer(forKey: "wylde_water_goal")
        if wg > 0 { waterGoal = wg }

        // Auth: prefer explicit flag, fall back to "did the user set a name"
        if defaults.object(forKey: "wylde_authed") != nil {
            isAuthenticated = defaults.bool(forKey: "wylde_authed")
        } else {
            isAuthenticated = !userName.isEmpty
        }
    }

    /// Wipe all persisted state — call from a debug menu or sign-out flow
    func resetAllData() {
        let keys = [
            "wylde_authed", "wylde_name", "wylde_day", "wylde_streak", "wylde_xp",
            "wylde_goals", "wylde_gym", "wylde_onboarded",
            "wylde_level", "wylde_days", "wylde_equipment",
            "wylde_gym_access", "wylde_weight_unit",
            "wylde_classes",
            "wylde_morning_actions", "wylde_morning_done",
            "wylde_protein_goal", "wylde_calories_goal",
            // Legacy keys — remove stale UserDefaults copies of now-secure fields
            "wylde_gender", "wylde_age", "wylde_height", "wylde_weight",
            "wylde_health", "wylde_health_notes", "wylde_diet", "wylde_diet_notes",
            "wylde_identity_profile"
        ]
        for k in keys { defaults.removeObject(forKey: k) }
        // Sweep all date-scoped daily keys (every "wylde_*_<yyyy-MM-dd>" key)
        let dailyPrefixes = [
            "wylde_workout_done_",
            "wylde_protein_logged_",
            "wylde_calories_logged_",
            "wylde_walk_done_",
            "wylde_pages_",
            "wylde_carbs_logged_",
            "wylde_fat_logged_",
            "wylde_calories_burned_",
            "wylde_water_logged_",
            "wylde_reflection_done_",
            "wylde_reflection_",
            "wylde_meals_",
            // Morning ritual keys are now day-scoped (see dayKey usage above)
            "wylde_morning_done_",
            "wylde_morning_actions_"
        ]
        for key in defaults.dictionaryRepresentation().keys {
            if dailyPrefixes.contains(where: { key.hasPrefix($0) }) {
                defaults.removeObject(forKey: key)
            }
        }
        // Clear nutrition preferences migration flag
        defaults.removeObject(forKey: "wylde_nutrition_prefs_migrated")
        Task { @MainActor in
            NutritionPreferencesService.shared.reset()
        }

        // Wipe Keychain + file storage (sensitive data + vision images)
        SecureStorage.shared.deleteAllUserData()
        loadFromDefaults()
    }

    /// Silent XP accumulator — used for analytics + future identity-driven
    /// badges, never displayed as a rank. The Ember/Spark/Flame ladder was
    /// stripped because it pulled the brand toward video-game gamification
    /// when the actual point of Wylde Self is transforming your relationship
    /// with yourself.
    func awardXP(_ amount: Int, reason: String) {
        xp += amount  // didSet writes to defaults automatically
        HapticManager.shared.impact(.light)
    }
}

struct MorningAction: Identifiable, Codable {
    let id: String
    let name: String
    let desc: String
    let dur: Int
    var completed: Bool = false
}
