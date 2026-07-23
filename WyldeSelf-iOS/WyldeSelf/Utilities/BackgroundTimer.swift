import Foundation
import Combine
import UIKit

// ════════════════════════════════════════════════════════════════════
//  BackgroundTimer — survives app backgrounding by storing a start
//  date and computing elapsed from wall-clock time. Uses a display-
//  link cadence timer for UI updates when foregrounded, and
//  recalculates on foreground return.
//
//  Usage:
//    @StateObject var timer = BackgroundTimer(persistKey: "walk_start")
//    timer.start()       // begins
//    timer.elapsed       // seconds since start (always current)
//    timer.stop()        // stops, clears persisted date
// ════════════════════════════════════════════════════════════════════

@MainActor
final class BackgroundTimer: ObservableObject {
    @Published private(set) var elapsed: Int = 0
    @Published private(set) var isRunning = false

    /// The actual start time — survives backgrounding
    private(set) var startDate: Date?

    private var displayTimer: Timer?
    private let persistKey: String
    private var foregroundObserver: AnyCancellable?
    private var backgroundObserver: AnyCancellable?

    init(persistKey: String) {
        self.persistKey = persistKey
        restoreIfNeeded()
        observeAppLifecycle()
    }

    deinit {
        displayTimer?.invalidate()
    }

    // MARK: - Public

    func start() {
        let now = Date()
        startDate = now
        isRunning = true
        elapsed = 0
        persist(now)
        startDisplayTimer()
    }

    func stop() -> Int {
        displayTimer?.invalidate()
        displayTimer = nil
        let finalElapsed = computeElapsed()
        elapsed = finalElapsed
        isRunning = false
        startDate = nil
        clearPersisted()
        return finalElapsed
    }

    var elapsedTimeInterval: TimeInterval {
        guard let start = startDate else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // MARK: - Display Timer (UI ticks)

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        elapsed = computeElapsed()
    }

    private func computeElapsed() -> Int {
        guard let start = startDate else { return 0 }
        return max(0, Int(Date().timeIntervalSince(start)))
    }

    // MARK: - Persistence (survives app kill)

    private func persist(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: persistKey)
    }

    private func clearPersisted() {
        UserDefaults.standard.removeObject(forKey: persistKey)
    }

    private func restoreIfNeeded() {
        let stored = UserDefaults.standard.double(forKey: persistKey)
        guard stored > 0 else { return }

        let date = Date(timeIntervalSince1970: stored)
        // Sanity: ignore if start date is in the future or more than 24h ago
        let age = Date().timeIntervalSince(date)
        guard age > 0, age < 86400 else {
            clearPersisted()
            return
        }

        startDate = date
        isRunning = true
        elapsed = computeElapsed()
        startDisplayTimer()
    }

    // MARK: - App Lifecycle

    private func observeAppLifecycle() {
        foregroundObserver = NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.isRunning else { return }
                self.elapsed = self.computeElapsed()
                self.startDisplayTimer()
            }

        backgroundObserver = NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Stop the display timer to save resources; start date is persisted
                self?.displayTimer?.invalidate()
                self?.displayTimer = nil
            }
    }
}
