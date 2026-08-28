import UIKit
import CloudKit

/// Handles CloudKit share acceptance for SwiftUI's scene-based app
/// lifecycle. This was the actual bug behind shared trips never
/// appearing on the recipient side: SwiftUI App-lifecycle apps are
/// scene-based even without any explicit scene management, and iOS
/// delivers an accepted share to this *scene* delegate method — not to
/// UIApplicationDelegate.application(_:userDidAcceptCloudKitShareWith:),
/// which is the older pre-scene API and was silently never being called.
/// Confirmed via diagnostic logging: the share URL itself was valid and
/// correctly formed, but neither the app-delegate callback nor anything
/// else ever fired when the link was tapped.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    /// Warm case: the app is already running when the share link is
    /// tapped.
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in
            await TripSharingService.shared.acceptIncomingShare(metadata: cloudKitShareMetadata)
        }
    }

    /// Cold-start case: the app isn't running yet, and launches *because*
    /// the share link was tapped — the metadata arrives via
    /// connectionOptions instead of the callback above. This is exactly
    /// what happens right after a fresh install, which is how this bug
    /// was being tested — so this path matters as much as the warm one.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let metadata = connectionOptions.cloudKitShareMetadata else { return }
        Task { @MainActor in
            await TripSharingService.shared.acceptIncomingShare(metadata: metadata)
        }
    }
}
