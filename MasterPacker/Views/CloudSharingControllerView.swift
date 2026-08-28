import SwiftUI
import CloudKit

/// Bridges Apple's native CloudKit share sheet — the same UI used to
/// share a Note, a Reminders list, or a Photos album — into SwiftUI.
/// Presenting this is also how the trip's owner later manages who has
/// access or stops sharing (re-invoking it on an already-shared trip
/// shows the existing participant list).
///
/// Uses UICloudSharingController's preparationHandler initializer rather
/// than passing a pre-made CKShare — multiple independent developer
/// reports (and our own first real-device test) confirm the pre-made-
/// share initializer is unreliable for first-time sharing (the share
/// sheet appears but offers no way to actually pick a person). With
/// preparationHandler, the share sheet presents immediately and the
/// actual CKShare only gets created once the user picks a share method,
/// which is the behavior Apple's own apps use.
struct CloudSharingControllerView: UIViewControllerRepresentable {
    let trip: Trip

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController { _, completion in
            Task { @MainActor in
                do {
                    let share = try await TripSharingService.shared.shareTrip(trip)
                    completion(share, CKContainer.default(), nil)
                } catch {
                    completion(nil, nil, error)
                }
            }
        }
        controller.delegate = context.coordinator
        // .allowPrivate governs *who* can be invited (specific people vs.
        // a public link); .allowReadWrite governs what they can do once
        // invited. Both axes need to be set — omitting allowPrivate looks
        // to be why the share sheet had no invite option at all.
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
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
