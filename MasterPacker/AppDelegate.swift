import UIKit
import CloudKit

/// Small UIKit bridge for CloudKit sharing — SwiftUI's App lifecycle has
/// no direct hook for "the user just tapped Accept on an incoming share
/// invite," so this exists solely to catch that one callback and hand it
/// off to TripSharingService. Nothing else in the app goes through this.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in
            await TripSharingService.shared.acceptIncomingShare(metadata: cloudKitShareMetadata)
        }
    }
}
