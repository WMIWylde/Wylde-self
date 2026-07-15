import Foundation
import Combine

// ════════════════════════════════════════════════════════════════════
//  CheckinSync — closes the loop between AppState daily toggles and
//  the clinical dashboard.
//
//  What it does:
//    • Observes AppState completion fields (morning protocol, workout,
//      walk, protein, calories) and the day counter.
//    • Debounces 2.5 seconds, so a burst of toggles produces one upsert.
//    • POSTs to /api/consumer/checkin via ClinicalAPI.
//    • Only fires when the user has an active care relationship (cached).
//
//  Mapping AppState → CheckinPayload (initial heuristic — refine later):
//    doses          = morningProtocolCompleted ? 3 : 0
//                     (placeholder until peptide-dose tracking ships)
//    daily_checkin  = (morning + walk + workout > 0) ? 3 : 0
//    workout        = workoutCompleted ? 3 : 0
//    nutrition      = proteinLogged / proteinGoal scaled to 0..3
//
//  Lifecycle: started from WyldeSelfApp.onAppear. Idempotent.
// ════════════════════════════════════════════════════════════════════

@MainActor
final class CheckinSync {
    static let shared = CheckinSync()
    private init() {}

    private var cancellables: Set<AnyCancellable> = []
    @Published private(set) var hasActiveCareRelationship: Bool = false
    private var lastSyncedSignature: String = ""
    private var inflight: Task<Void, Never>?

    // MARK: - Start

    func start(appState: AppState) {
        guard cancellables.isEmpty else { return }  // idempotent

        // Refresh the cached care-relationship flag on auth changes.
        NotificationCenter.default.publisher(for: .wyldeAuthChanged)
            .sink { [weak self] _ in Task { await self?.refreshRelationshipFlag() } }
            .store(in: &cancellables)

        // Initial check
        Task { await refreshRelationshipFlag() }

        // Observe the fields that contribute to a day's check-in.
        let pubs: [AnyPublisher<Void, Never>] = [
            appState.$morningProtocolCompleted.map { _ in () }.eraseToAnyPublisher(),
            appState.$workoutCompleted.map { _ in () }.eraseToAnyPublisher(),
            appState.$dailyWalkCompleted.map { _ in () }.eraseToAnyPublisher(),
            appState.$proteinLogged.map { _ in () }.eraseToAnyPublisher(),
            appState.$caloriesLogged.map { _ in () }.eraseToAnyPublisher(),
        ]

        Publishers.MergeMany(pubs)
            // Skip the initial sink that fires when subscribers attach.
            .dropFirst()
            .debounce(for: .seconds(2.5), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                self.sync(appState: appState)
            }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
        inflight?.cancel()
    }

    // MARK: - Sync

    private func sync(appState: AppState) {
        guard hasActiveCareRelationship else {
            #if DEBUG
            print("[CheckinSync] Skipping sync — no care relationship")
            #endif
            return
        }

        let payload = Self.buildPayload(from: appState)
        let signature = Self.signature(of: payload)
        guard signature != lastSyncedSignature else { return }   // no change

        inflight?.cancel()
        inflight = Task { [signature, payload] in
            do {
                try await ClinicalAPI.submitCheckin(payload)
                lastSyncedSignature = signature
            } catch {
                // Silent failure — next toggle will retry. Surface to user
                // only after repeated failures (future work).
                #if DEBUG
                print("[CheckinSync] failed:", error.localizedDescription)
                #endif
            }
        }
    }

    // MARK: - Helpers

    func refreshRelationshipFlag() async {
        // Guard: don't hit the server before AuthService has restored a session
        // on cold launch. Without this we'd fire a Bearer-nil request that always
        // 401s. The .wyldeAuthChanged observer above will call us again once
        // AuthService.restore() completes and has a real token to attach.
        guard await AuthService.shared.accessToken != nil else {
            hasActiveCareRelationship = false
            #if DEBUG
            print("[CheckinSync] Skipping relationship check — auth not ready")
            #endif
            return
        }

        do {
            let r = try await ClinicalAPI.careRelationships()
            hasActiveCareRelationship = (r.active_relationship != nil)
            #if DEBUG
            print("[CheckinSync] Care relationship active: \(hasActiveCareRelationship)")
            #endif
        } catch {
            hasActiveCareRelationship = false
            #if DEBUG
            print("[CheckinSync] Care relationship check failed: \(error.localizedDescription)")
            #endif
        }
    }

    private static func buildPayload(from appState: AppState) -> CheckinPayload {
        let dateStr: String = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.calendar = Calendar(identifier: .gregorian)
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()

        let nutritionScore: Int = {
            let ratio = appState.proteinGoal > 0
                ? Double(appState.proteinLogged) / Double(appState.proteinGoal)
                : 0
            switch ratio {
            case 0..<0.25:  return 0
            case 0.25..<0.6: return 1
            case 0.6..<0.9:  return 2
            default:         return 3
            }
        }()

        let didAnything =
            appState.morningProtocolCompleted ||
            appState.workoutCompleted ||
            appState.dailyWalkCompleted ||
            appState.proteinLogged > 0

        return CheckinPayload(
            date: dateStr,
            doses: appState.morningProtocolCompleted ? 3 : 0,
            daily_checkin: didAnything ? 3 : 0,
            workout: appState.workoutCompleted ? 3 : 0,
            nutrition: nutritionScore,
            weight: nil,
            sleep_score: nil,
            hrv: nil,
            rhr: nil,
            mood: nil,
            notes: nil
        )
    }

    /// Stable hash of the payload's adherence axes, used to skip
    /// duplicate POSTs when nothing actually changed.
    private static func signature(of payload: CheckinPayload) -> String {
        "\(payload.date ?? "")|\(payload.doses)|\(payload.daily_checkin)|\(payload.workout)|\(payload.nutrition)"
    }
}
