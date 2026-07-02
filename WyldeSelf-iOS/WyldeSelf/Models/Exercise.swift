import Foundation
import SwiftUI

// MARK: - Exercise Model
// Mirrors the schema in /data/exercises.json (free-exercise-db, normalized)

struct Exercise: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: String           // "strength", "cardio", "stretching", etc.
    let level: String              // "beginner", "intermediate", "expert"
    let force: String?             // "pull", "push", "static"
    let mechanic: String?          // "compound", "isolation"
    let equipment: String          // "barbell", "dumbbell", "body only", ...
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: [String]
    let images: [String]           // remote URLs to GitHub raw
    let gifUrl: String?            // animated GIF from ExerciseDB (online exercises)

    var primaryMuscle: String { primaryMuscles.first ?? "" }
    var displayEquipment: String { equipment == "none" ? "Bodyweight" : equipment.capitalized }
    var displayLevel: String { level.capitalized }

    // Init for creating from ExerciseDB API results
    init(id: String, name: String, equipment: String, primaryMuscles: [String], secondaryMuscles: [String], instructions: [String], gifUrl: String?) {
        self.id = id
        self.name = name
        self.category = "strength"
        self.level = "intermediate"
        self.force = nil
        self.mechanic = nil
        self.equipment = equipment
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.instructions = instructions
        self.images = []
        self.gifUrl = gifUrl
    }
}

// MARK: - Repository
// Loads + caches the bundled exercises.json. Exposes search / filter helpers.

@MainActor
final class ExerciseRepository: ObservableObject {
    static let shared = ExerciseRepository()

    @Published private(set) var all: [Exercise] = []
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var loadError: String?

    private init() {
        load()
    }

    func load() {
        guard !isLoaded else { return }
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            loadError = "exercises.json not found in app bundle"
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Exercise].self, from: data)
            self.all = decoded
            self.isLoaded = true
        } catch {
            loadError = "Failed to decode exercises.json: \(error.localizedDescription)"
        }
    }

    // Distinct facet values for filter pickers
    var allMuscles: [String] {
        let set = Set(all.flatMap { $0.primaryMuscles })
        return set.sorted()
    }
    var allEquipment: [String] {
        let set = Set(all.map { $0.equipment })
        return set.sorted()
    }
    var allCategories: [String] {
        let set = Set(all.map { $0.category })
        return set.sorted()
    }
    var allLevels: [String] {
        ["beginner", "intermediate", "expert"]
    }

    func search(
        query: String = "",
        muscle: String? = nil,
        equipment: String? = nil,
        category: String? = nil,
        level: String? = nil
    ) -> [Exercise] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        return all.filter { ex in
            if let m = muscle, !ex.primaryMuscles.contains(where: { $0.lowercased() == m.lowercased() }) &&
                              !ex.secondaryMuscles.contains(where: { $0.lowercased() == m.lowercased() }) {
                return false
            }
            if let e = equipment, ex.equipment.lowercased() != e.lowercased() { return false }
            if let c = category, ex.category.lowercased() != c.lowercased() { return false }
            if let l = level, ex.level.lowercased() != l.lowercased() { return false }
            if !q.isEmpty, !ex.name.lowercased().contains(q) { return false }
            return true
        }
    }

    // MARK: - Online Search (ExerciseDB — 1,500 exercises with GIFs)

    @Published var onlineResults: [Exercise] = []
    @Published var isSearchingOnline = false

    func searchOnline(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { onlineResults = []; return }
        isSearchingOnline = true
        defer { isSearchingOnline = false }

        guard let url = URL(string: "https://www.wyldeself.com/api/exercises-search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&limit=20") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct Resp: Codable {
                let exercises: [OnlineExercise]
                struct OnlineExercise: Codable {
                    let id: String
                    let name: String
                    let gifUrl: String?
                    let bodyParts: [String]?
                    let equipment: String?
                    let targetMuscles: [String]?
                    let secondaryMuscles: [String]?
                    let instructions: [String]?
                }
            }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            onlineResults = resp.exercises.map { e in
                Exercise(
                    id: e.id,
                    name: e.name.capitalized,
                    equipment: e.equipment ?? "body weight",
                    primaryMuscles: e.targetMuscles ?? e.bodyParts ?? [],
                    secondaryMuscles: e.secondaryMuscles ?? [],
                    instructions: e.instructions ?? [],
                    gifUrl: e.gifUrl
                )
            }
        } catch {
            #if DEBUG
            print("[ExerciseRepo] Online search error: \(error.localizedDescription)")
            #endif
            onlineResults = []
        }
    }

    func first(matching name: String) -> Exercise? {
        let q = name.lowercased().trimmingCharacters(in: .whitespaces)
        // Exact name match
        if let exact = all.first(where: { $0.name.lowercased() == q }) {
            return exact
        }
        // Word-overlap fallback
        let qWords = q.split(separator: " ").map(String.init)
        var best: Exercise?
        var bestScore = 0
        for ex in all {
            let n = ex.name.lowercased()
            var score = 0
            for w in qWords where !w.isEmpty && n.contains(w) {
                score += w.count
            }
            if n.hasPrefix(qWords.first ?? "") { score += 5 }
            if score > bestScore {
                bestScore = score
                best = ex
            }
        }
        return best
    }
}
