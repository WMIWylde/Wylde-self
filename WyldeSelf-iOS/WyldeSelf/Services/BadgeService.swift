import Foundation
import SwiftUI
import AVKit

// ════════════════════════════════════════════════════════════════════
//  BadgeService — iOS port of the web WYLDE_BADGES system.
//  Identity-driven achievement badges. Unlocks award +100 points
//  (ledger) and fire a full-screen ceremony (levelup1.mp4 overlay).
//
//  Metrics come from lifetime counters persisted in UserDefaults and
//  incremented by BadgeService.count(_:) at the same hooks that award
//  XP. Earned badge ids sync to the shared Supabase `badges` table so
//  web and iOS never re-celebrate each other's unlocks.
// ════════════════════════════════════════════════════════════════════

struct WyldeBadge: Identifiable {
    let id: String
    let symbol: String        // SF Symbol
    let name: String
    let desc: String
    let category: String
    let metric: BadgeMetric
    let threshold: Int
}

enum BadgeMetric: String {
    case streak, sessions, mornings, walks, prs, meals, reflections
}

@MainActor
final class BadgeService: ObservableObject {
    static let shared = BadgeService()
    private init() {}

    @Published var pendingCeremony: WyldeBadge?

    var earnedIds: Set<String> { earned }

    private let defaults = UserDefaults.standard
    private var earned: Set<String> {
        get { Set(defaults.stringArray(forKey: "wylde_badges_earned") ?? []) }
        set { defaults.set(Array(newValue), forKey: "wylde_badges_earned") }
    }

    static let badges: [WyldeBadge] = [
        // Streaks
        .init(id: "streak_3",   symbol: "leaf",                name: "3 Days Strong",      desc: "Three consecutive days of showing up",              category: "streak",     metric: .streak, threshold: 3),
        .init(id: "streak_7",   symbol: "flame",               name: "One Week Standing",  desc: "A full week of consistent practice",                category: "streak",     metric: .streak, threshold: 7),
        .init(id: "streak_14",  symbol: "bolt",                name: "Two Weeks Held",     desc: "You held the line for fourteen days",               category: "streak",     metric: .streak, threshold: 14),
        .init(id: "streak_21",  symbol: "sparkles",            name: "Habit Threshold",    desc: "Twenty-one days — the practice is sticking",        category: "streak",     metric: .streak, threshold: 21),
        .init(id: "streak_30",  symbol: "moon.stars",          name: "A Month Held",       desc: "A full lunar cycle of consistency",                 category: "streak",     metric: .streak, threshold: 30),
        .init(id: "streak_100", symbol: "diamond",             name: "100 Days Unbroken",  desc: "A hundred consecutive days. Rare air.",             category: "streak",     metric: .streak, threshold: 100),
        .init(id: "streak_365", symbol: "crown",               name: "A Year Unbroken",    desc: "One year of unbroken practice",                     category: "streak",     metric: .streak, threshold: 365),
        // Sessions
        .init(id: "sess_1",     symbol: "location.north.line", name: "First Rep",          desc: "You logged your first session",                     category: "sessions",   metric: .sessions, threshold: 1),
        .init(id: "sess_10",    symbol: "hammer",              name: "Ten Sessions In",    desc: "Ten sessions of real work",                         category: "sessions",   metric: .sessions, threshold: 10),
        .init(id: "sess_50",    symbol: "shield",              name: "Fifty Deep",         desc: "Fifty sessions — this is no accident",              category: "sessions",   metric: .sessions, threshold: 50),
        .init(id: "sess_100",   symbol: "mountain.2",          name: "The Hundred",        desc: "A hundred sessions. You're a different person.",    category: "sessions",   metric: .sessions, threshold: 100),
        .init(id: "sess_500",   symbol: "trophy",              name: "500 Sessions",       desc: "Five hundred sessions of compounding work",         category: "sessions",   metric: .sessions, threshold: 500),
        // Mornings
        .init(id: "morn_1",     symbol: "sunrise",             name: "First Morning",      desc: "You completed your first morning protocol",         category: "practice",   metric: .mornings, threshold: 1),
        .init(id: "morn_7",     symbol: "sun.max",             name: "Seven Mornings",     desc: "A week of intentional starts",                      category: "practice",   metric: .mornings, threshold: 7),
        .init(id: "morn_30",    symbol: "book",                name: "Thirty Mornings",    desc: "A month of practiced rituals",                      category: "practice",   metric: .mornings, threshold: 30),
        .init(id: "morn_100",   symbol: "target",              name: "A Hundred Mornings", desc: "A hundred days you chose yourself early",           category: "practice",   metric: .mornings, threshold: 100),
        // Walks
        .init(id: "walk_1",     symbol: "shoeprints.fill",     name: "First Walk",         desc: "You logged your first daily walk",                  category: "practice",   metric: .walks, threshold: 1),
        .init(id: "walk_7",     symbol: "leaf",                name: "Seven Walks",        desc: "A full week of walking",                            category: "practice",   metric: .walks, threshold: 7),
        .init(id: "walk_30",    symbol: "mountain.2",          name: "Thirty Walks",       desc: "A month of moving outside",                         category: "practice",   metric: .walks, threshold: 30),
        .init(id: "walk_100",   symbol: "sun.horizon",         name: "A Hundred Walks",    desc: "A hundred days of stepping outside",                category: "practice",   metric: .walks, threshold: 100),
        // Strength
        .init(id: "pr_1",       symbol: "arrow.up.circle",     name: "First PR",           desc: "You set your first personal record",                category: "strength",   metric: .prs, threshold: 1),
        .init(id: "pr_10",      symbol: "scalemass",           name: "Ten PRs",            desc: "Ten personal records logged",                       category: "strength",   metric: .prs, threshold: 10),
        .init(id: "pr_50",      symbol: "mountain.2",          name: "Fifty PRs",          desc: "Fifty PRs — you've outgrown your old ceiling",      category: "strength",   metric: .prs, threshold: 50),
        // Nutrition
        .init(id: "meal_1",     symbol: "fork.knife",          name: "First Meal",         desc: "You logged your first meal",                        category: "nutrition",  metric: .meals, threshold: 1),
        .init(id: "meal_30",    symbol: "leaf",                name: "Thirty Meals",       desc: "Thirty meals tracked — you're paying attention",    category: "nutrition",  metric: .meals, threshold: 30),
        .init(id: "meal_100",   symbol: "fork.knife.circle",   name: "A Hundred Meals",    desc: "A hundred meals logged",                            category: "nutrition",  metric: .meals, threshold: 100),
        // Reflections
        .init(id: "refl_1",     symbol: "eye",                 name: "First Reflection",   desc: "You logged how a session felt",                     category: "reflection", metric: .reflections, threshold: 1),
        .init(id: "refl_7",     symbol: "safari",              name: "Seven Reflections",  desc: "You're tuning in to your own signal",               category: "reflection", metric: .reflections, threshold: 7),
        .init(id: "refl_30",    symbol: "hurricane",           name: "Thirty Reflections", desc: "Thirty reflections — self-awareness as practice",   category: "reflection", metric: .reflections, threshold: 30),
    ]

    // MARK: - Lifecycle

    private var observing = false

    /// Call once (MainTabView). Maps XP award reasons to lifetime counters
    /// so earning hooks stay in one place.
    func start(appState: AppState) {
        guard !observing else { return }
        observing = true
        retroCredit(streak: appState.streak)
        NotificationCenter.default.addObserver(forName: .wyldeXPAwarded, object: nil, queue: .main) { [weak self] note in
            guard let self, let reason = (note.userInfo?["reason"] as? String)?.lowercased() else { return }
            Task { @MainActor in
                if reason.contains("workout completed") { self.count(.sessions) }
                else if reason.contains("morning protocol") { self.count(.mornings) }
                else if reason.contains("walk") { self.count(.walks) }
                else if reason.contains("reflection") { self.count(.reflections) }
                else { self.evaluate(streak: nil) }
            }
        }
    }

    // MARK: - Counters

    private func counterKey(_ m: BadgeMetric) -> String { "wylde_count_\(m.rawValue)" }

    func count(_ metric: BadgeMetric) {
        defaults.set(defaults.integer(forKey: counterKey(metric)) + 1, forKey: counterKey(metric))
        evaluate(streak: nil)
    }

    func value(of metric: BadgeMetric) -> Int {
        defaults.integer(forKey: counterKey(metric))
    }

    // MARK: - Evaluation

    /// Check all badges against current metrics. `streak` comes from AppState
    /// (it isn't a lifetime counter); pass nil to use the persisted value.
    func evaluate(streak: Int?) {
        if let streak { defaults.set(streak, forKey: "wylde_streak") }
        let currentStreak = streak ?? defaults.integer(forKey: "wylde_streak")
        var earnedSet = earned
        var newly: [WyldeBadge] = []

        for badge in Self.badges where !earnedSet.contains(badge.id) {
            let v = badge.metric == .streak ? currentStreak : value(of: badge.metric)
            if v >= badge.threshold {
                earnedSet.insert(badge.id)
                newly.append(badge)
            }
        }
        guard !newly.isEmpty else { return }
        earned = earnedSet

        struct BadgeRow: Encodable { let user_id: String; let badge_id: String; let earned_at: String }
        struct LedgerRow: Encodable { let delta: Int; let reason: String; let source: String }
        for badge in newly {
            Task {
                if let session = try? await SupabaseService.shared.auth.session {
                    _ = try? await SupabaseService.shared.from("badges")
                        .insert(BadgeRow(user_id: session.user.id.uuidString,
                                         badge_id: badge.id,
                                         earned_at: ISO8601DateFormatter().string(from: Date())))
                        .execute()
                }
                _ = try? await SupabaseService.shared.from("points_ledger")
                    .insert(LedgerRow(delta: 100, reason: "Badge: \(badge.name)", source: "ios"))
                    .execute()
            }
        }
        // Ceremony for the first; the rest are recorded silently (they'll
        // show in the badge gallery once that ships).
        pendingCeremony = newly[0]
        HapticManager.shared.impact(.heavy)
    }

    /// Silent retro-credit at launch — mark historically-earned badges
    /// without celebrating them.
    func retroCredit(streak: Int) {
        let currentStreak = streak
        var earnedSet = earned
        for badge in Self.badges where !earnedSet.contains(badge.id) {
            let v = badge.metric == .streak ? currentStreak : value(of: badge.metric)
            if v >= badge.threshold { earnedSet.insert(badge.id) }
        }
        earned = earnedSet
    }
}

// ════════════════════════════════════════════════════════════════════
//  BadgeCeremonyView — the reward moment. levelup1.mp4 behind a
//  sequenced reveal: badge name, meaning, +100 points.
// ════════════════════════════════════════════════════════════════════

struct BadgeCeremonyView: View {
    let badge: WyldeBadge
    let onDismiss: () -> Void

    @State private var player = AVPlayer(url: URL(string: "https://www.wyldeself.com/levelup1.mp4")!)
    @State private var showTitle = false
    @State private var showBody = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            FullBleedVideoPlayer(player: player)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.35))

            VStack(spacing: 14) {
                Spacer()
                Image(systemName: badge.symbol)
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(Color(hex: "C8A96E"))
                    .opacity(showTitle ? 1 : 0)
                    .scaleEffect(showTitle ? 1 : 0.7)

                Text(badge.name.uppercased())
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(showTitle ? 1 : 0)

                Text(badge.desc)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(showBody ? 1 : 0)

                Text("+100 points")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "C8A96E"))
                    .opacity(showBody ? 1 : 0)

                Spacer()

                Button("Continue") { onDismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 44)
                    .padding(.vertical, 14)
                    .background(Color(hex: "C8A96E"))
                    .clipShape(Capsule())
                    .opacity(showBody ? 1 : 0)
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            player.isMuted = true
            player.play()
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                player.seek(to: .zero); player.play()
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.8)) { showTitle = true }
            withAnimation(.easeOut(duration: 0.7).delay(1.5)) { showBody = true }
        }
        .onDisappear { player.pause() }
    }
}
