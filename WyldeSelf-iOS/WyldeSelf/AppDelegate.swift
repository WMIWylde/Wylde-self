import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Request notification permissions
        NotificationManager.shared.requestPermission()
        UNUserNotificationCenter.current().delegate = self

        // Initialize HealthKit (async — fire and forget)
        Task {
            _ = await HealthKitManager.shared.requestAuthorization()
        }

        return true
    }

    // Handle foreground notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    // Handle notification taps
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let screen = userInfo["screen"] as? String {
            NotificationCenter.default.post(
                name: .navigateToScreen,
                object: nil,
                userInfo: ["screen": screen]
            )
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let navigateToScreen = Notification.Name("navigateToScreen")
}
