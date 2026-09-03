import UIKit
import CloudKit
import FirebaseCore
import FirebaseCrashlytics
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
        //
        // FirebaseCrashlytics is linked (see project package product
        // dependencies) and needs no separate setup call — it registers
        // its own uncaught-exception/signal handlers as soon as it's
        // linked and this configure() call runs, capturing crashes from
        // here on. One manual, one-time Xcode step still required before
        // crash reports are symbolicated: add a Run Script build phase
        // that uploads dSYMs, per Firebase's Crashlytics + SPM setup
        // guide (Target → Build Phases → + → New Run Script Phase) —
        // that's an Xcode-project action, not something safe to hand-edit
        // into the .pbxproj blind.
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

    /// APNs hands back this device's push token once registerForRemoteNotifications()
    /// above succeeds — printed here (hex-encoded, the format Apple's push
    /// tools/console expect) purely so it's visible in Xcode's console for manual
    /// testing. Nothing in the app itself needs to hold onto this: CloudKit's own
    /// silent-push subscription picks up the registered token automatically,
    /// with no explicit handoff required.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if DEBUG
        let tokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("📱 APNs device token: \(tokenHex)")
        #endif
    }

    /// Push registration failing means CloudKit sharing sync silently
    /// stops working for this device — worth knowing about in production,
    /// not just a console line only a developer watching Xcode would see.
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Crashlytics.crashlytics().record(error: error)
        #if DEBUG
        print("⚠️ Failed to register for remote notifications: \(error)")
        #endif
    }
}
