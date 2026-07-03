import SwiftUI

@main
struct WyldeSelfWatchApp: App {
    @StateObject private var connector = PhoneConnector()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(connector)
        }
    }
}
