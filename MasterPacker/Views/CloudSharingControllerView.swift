import SwiftUI
import CloudKit

/// Presents Apple's native CloudKit share sheet — the same UI used to
/// share a Note, a Reminders list, or a Photos album.
///
/// UICloudSharingController renders blank when SwiftUI hands it directly
/// to `.sheet()` as content (a known SwiftUI/UIKit interop gap, confirmed
/// on our own first real-device test) — it needs a genuine UIKit
/// `present(_:animated:)` call from a view controller that's actually in
/// the hierarchy, not to be treated as the sheet's own content. So this
/// hosts a trivial, invisible UIViewController that's embedded directly
/// into the SwiftUI view tree (via `.background(...)`, not `.sheet(...)`)
/// and calls `present` on itself once `isPresented` flips true.
///
/// Uses UICloudSharingController's preparationHandler initializer rather
/// than passing a pre-made CKShare — that's the more reliable pattern for
/// first-time sharing (see TripSharingService's shareTrip doc comment).
struct CloudSharingPresenter: UIViewControllerRepresentable {
    let trip: Trip
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented, uiViewController.presentedViewController == nil {
            let sharingController = UICloudSharingController { _, completion in
                Task { @MainActor in
                    do {
                        let share = try await TripSharingService.shared.shareTrip(trip)
                        // TEMP diagnostic — chasing "recipient never gets a
                        // working invite." This is the exact share/URL
                        // being handed to UICloudSharingController; if
                        // .url is nil here, that's the smoking gun.
                        print("🔵 [Sharing] preparationHandler completing with share.url=\(String(describing: share.url)) recordID=\(share.recordID)")
                        completion(share, CKContainer.default(), nil)
                    } catch {
                        print("🔴 [Sharing] preparationHandler shareTrip FAILED: \(error)")
                        completion(nil, nil, error)
                    }
                }
            }
            sharingController.delegate = context.coordinator
            // .allowPrivate governs *who* can be invited (specific people
            // vs. a public link); .allowReadWrite governs what they can
            // do once invited — both axes need to be set.
            sharingController.availablePermissions = [.allowPrivate, .allowReadWrite]
            sharingController.presentationController?.delegate = context.coordinator
            uiViewController.present(sharingController, animated: true)
        } else if !isPresented, let presented = uiViewController.presentedViewController {
            presented.dismiss(animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate, UIAdaptivePresentationControllerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            // TEMP diagnostic — was silently swallowed before; this can
            // fire even after the preparationHandler already succeeded,
            // if something later in the save/publish flow fails.
            print("🔴 [Sharing] cloudSharingController failedToSaveShareWithError: \(error)")
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            print("🔵 [Sharing] cloudSharingControllerDidSaveShare. share.url=\(String(describing: csc.share?.url))")
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            csc.share?[CKShare.SystemFieldKey.title] as? String
        }

        /// Fires on swipe-to-dismiss (not on the controller's own
        /// self-dismissal after finishing) — keeps the binding honest so
        /// a later tap re-presents cleanly either way.
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            isPresented = false
        }
    }
}
