import CloudKit
import UIKit

/// Submits feedback to CloudKit's *public* database — deliberately a
/// separate database from the private/shared ones everything else in the
/// app uses (trips, bags, profiles), each with its own security model.
///
/// This is not literally anonymous: CloudKit stamps every record, public
/// database included, with a `creatorUserRecordID` from whatever iCloud
/// account is signed in on the device — an opaque, app-scoped identifier,
/// never the user's real name or email. The form itself asks for
/// nothing else. See the roadmap discussion for this feature for the
/// full reasoning behind picking this over a mailto-based approach.
///
/// Reading feedback back is done via the CloudKit Dashboard
/// (icloud.developer.apple.com), not from within the app — there's no
/// admin UI here on purpose, and the Feedback record type's Security
/// Role should be Create-only (no Read/Query) for World/Authenticated
/// so no client, including this app's own, can read other people's
/// submissions. That's a CloudKit Dashboard configuration step, not
/// something enforced here in code.
enum FeedbackService {
    private static let recordType = "Feedback"

    enum FeedbackError: Error {
        case emptyMessage
    }

    /// Saves one feedback record. Throws on an empty/whitespace-only
    /// message (callers should already disable Send in that case — this
    /// is a last-line guard) or on any CloudKit failure (offline, the
    /// Feedback record type not yet deployed to the Production
    /// environment, etc.) — callers should show a generic retry message
    /// either way rather than surfacing CKError details to the user.
    static func submit(message: String) async throws {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FeedbackError.emptyMessage }

        let record = CKRecord(recordType: recordType)
        record["message"] = trimmed as CKRecordValue
        record["appVersion"] = appVersionString as CKRecordValue
        record["osVersion"] = "iOS \(UIDevice.current.systemVersion)" as CKRecordValue

        _ = try await CKContainer.default().publicCloudDatabase.save(record)
    }

    /// e.g. "1.0 (1)" — for your own troubleshooting context on a
    /// submission only, never shown to the user.
    private static var appVersionString: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(shortVersion) (\(buildNumber))"
    }
}
