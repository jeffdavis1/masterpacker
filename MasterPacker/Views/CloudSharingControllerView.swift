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
    /// Fires when the share fails to save *after* the preparation handler
    /// already succeeded — see Coordinator.cloudSharingController(_:failedToSaveShareWithError:).
    /// A preparation failure (e.g. not signed into iCloud) is already
    /// handled by UICloudSharingController's own native error UI; this is
    /// the one failure mode that otherwise reaches no one.
    var onSaveFailed: (String) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented, uiViewController.presentedViewController == nil {
            let sharingController = UICloudSharingController { _, completion in
                Task { @MainActor in
                    do {
                        let share = try await TripSharingService.shared.shareTrip(trip)
                        completion(share, CKContainer.default(), nil)
                    } catch {
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
        Coordinator(isPresented: $isPresented, onSaveFailed: onSaveFailed)
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate, UIAdaptivePresentationControllerDelegate {
        @Binding var isPresented: Bool
        let onSaveFailed: (String) -> Void

        init(isPresented: Binding<Bool>, onSaveFailed: @escaping (String) -> Void) {
            _isPresented = isPresented
            self.onSaveFailed = onSaveFailed
        }

        /// Can fire even after the preparationHandler already succeeded,
        /// if something later in the save/publish flow fails (dropped
        /// connection, iCloud quota, etc.) — by then the sharing sheet has
        /// often already dismissed itself, so without this the user is
        /// left believing the trip is shared when it isn't. Reset
        /// isPresented too so a retry tap re-presents cleanly instead of
        /// silently no-op'ing (updateUIViewController only presents when
        /// nothing's already presented).
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            isPresented = false
            onSaveFailed(error.localizedDescription)
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
