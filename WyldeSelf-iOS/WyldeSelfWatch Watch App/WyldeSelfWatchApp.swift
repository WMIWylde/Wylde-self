import SwiftUI
import WatchKit
import HealthKit

@main
struct WyldeSelfWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    @StateObject private var connector = PhoneConnector()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(connector)
        }
    }
}


// Receives workout configurations when the iPhone calls
// HKHealthStore.startWatchApp(with:) — e.g. user starts a walk or
// workout on the phone and the watch begins live tracking.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in
            WatchWorkoutSessionManager.shared.start(configuration: workoutConfiguration)
        }
    }
}
