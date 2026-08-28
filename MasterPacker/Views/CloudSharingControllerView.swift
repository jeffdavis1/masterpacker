import SwiftUI
import CloudKit

/// Bridges Apple's native CloudKit share sheet — the same UI used to
/// share a Note, a Reminders list, or a Photos album — into SwiftUI.
/// Presenting this is also how the trip's owner later manages who has
/// access or stops sharing (re-invoking it on an already-shared trip
/// shows the existing participant list).
struct CloudSharingControllerView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadWrite]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            // UICloudSharingController surfaces its own error UI to the
            // user — nothing else to do here.
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            csc.share?[CKShare.SystemFieldKey.title] as? String
        }
    }
}
