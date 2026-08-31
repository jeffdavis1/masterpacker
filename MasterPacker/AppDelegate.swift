import UIKit
import CloudKit
import FirebaseCore
import UserNotifications

/// Small UIKit bridge for things SwiftUI's App lifecycle has no direct
/// hook for. CloudKit share acceptance itself is NOT handled here — for
/// a scene-based app (which every SwiftUI App-lifecycle app is), iOS
/// delivers that to SceneDelegate instead (see SceneDelegate.swift for
/// why). This class still needs to exist for remote-notification
/// registration and for pointing iOS at that custom scene delegate.
///
/// @MainActor since every delegate callback here runs on the main thread
/// anyway (per UIApplicationDelegate's own contract) — needed so
/// didFinishLaunchingWithOptions below can set NotificationManager.shared
/// as the UNUserNotificationCenter delegate without an extra hop.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Firebase's own guidance: configure() as early in launch as
        // possible, and before any other Firebase API (Analytics
        // included) is touched. Reads GoogleService-Info.plist out of
        // the app bundle automatically.
        FirebaseApp.configure()

        // Needed for CloudKit's zone-change subscriptions (see
        // TripSharingService.ensureZoneSubscription) to actually deliver
        // silent pushes to this device — no explicit token handoff to
        // CloudKit required, it picks up the registered token itself.
        application.registerForRemoteNotifications()

        // Must be set before the app finishes launching to reliably catch
        // a cold-start notification tap — see NotificationManager's
        // UNUserNotificationCenterDelegate conformance for what this
        // actually does (foreground presentation + the trip deep link).
        UNUserNotificationCenter.current().delegate = NotificationManager.shared

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
        Task { @MainActor in
            await TripSharingService.shared.handleRemoteNotification(userInfo: userInfo)
            completionHandler(.newData)
        }
    }
}
