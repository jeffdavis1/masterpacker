import UIKit
import CloudKit

/// Small UIKit bridge for CloudKit sharing — SwiftUI's App lifecycle has
/// no direct hook for "the user just tapped Accept on an incoming share
/// invite" or "a silent push arrived," so this exists solely to catch
/// those two callbacks and hand them off to TripSharingService. Nothing
/// else in the app goes through this.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Needed for CloudKit's zone-change subscriptions (see
        // TripSharingService.ensureZoneSubscription) to actually deliver
        // silent pushes to this device — no explicit token handoff to
        // CloudKit required, it picks up the registered token itself.
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in
            await TripSharingService.shared.acceptIncomingShare(metadata: cloudKitShareMetadata)
        }
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
