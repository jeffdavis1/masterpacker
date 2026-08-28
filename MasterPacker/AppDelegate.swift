import UIKit
import CloudKit

/// Small UIKit bridge for things SwiftUI's App lifecycle has no direct
/// hook for. CloudKit share acceptance itself is NOT handled here — for
/// a scene-based app (which every SwiftUI App-lifecycle app is), iOS
/// delivers that to SceneDelegate instead (see SceneDelegate.swift for
/// why). This class still needs to exist for remote-notification
/// registration and for pointing iOS at that custom scene delegate.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Needed for CloudKit's zone-change subscriptions (see
        // TripSharingService.ensureZoneSubscription) to actually deliver
        // silent pushes to this device — no explicit token handoff to
        // CloudKit required, it picks up the registered token itself.
        application.registerForRemoteNotifications()
        return true
    }

    /// Points iOS at SceneDelegate for scene-level callbacks — required
    /// for windowScene(_:userDidAcceptCloudKitShareWith:) and
    /// scene(_:willConnectTo:options:) to ever be called at all.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("🔵 [Sharing] didReceiveRemoteNotification fired: \(userInfo)")
        Task { @MainActor in
            await TripSharingService.shared.handleRemoteNotification(userInfo: userInfo)
            completionHandler(.newData)
        }
    }

    // TEMP diagnostics — registerForRemoteNotifications() above had no
    // visibility into whether it actually succeeded on a given device.
    // If this device never logs a token, no push (including CloudKit's
    // silent zone-change pushes) can ever reach it, regardless of
    // whether the CloudKit-side subscription itself is fine.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("🔵 [Sharing] didRegisterForRemoteNotificationsWithDeviceToken: \(token)")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🔴 [Sharing] didFailToRegisterForRemoteNotificationsWithError: \(error)")
    }
}
