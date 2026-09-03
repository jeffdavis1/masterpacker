import FirebaseAnalytics

/// A thin wrapper around Firebase Analytics — call sites log a named,
/// typed event instead of reaching for `Analytics.logEvent` directly, so
/// every event this app sends lives in one place with one naming
/// convention.  Firebase is configured once, in
/// AppDelegate.didFinishLaunchingWithOptions; every call here is safe to
/// make regardless of whether that's happened yet (Firebase queues
/// events before configure() if it somehow ran first).
///
/// Deliberately covers user *actions* (created, deleted, shared, applied,
/// …), not screen-by-screen navigation — a named business event is more
/// useful for "what are my users doing" than a raw navigation trace, and
/// Firebase's automatic screen tracking barely works in a SwiftUI-only
/// app anyway (no per-screen UIViewController for it to detect).
///
/// Privacy: every event here is a hard line, not just a convention —
/// parameters are counts, booleans, or fixed enum-like strings only,
/// never a trip name, item name, traveler/pet name, or destination.
/// That's what the privacy policy (docs/PRIVACY_POLICY.md) promises
/// Firebase never sees; a new event that breaks this needs the policy
/// updated first, per CLAUDE.md.
enum AnalyticsService {
    // MARK: - Trips

    static func tripCreated(travelerCount: Int, petCount: Int, activityCount: Int, travelMethod: TravelMethod, generatedSuggestions: Bool) {
        Analytics.logEvent("trip_created", parameters: [
            "traveler_count": travelerCount,
            "pet_count": petCount,
            "activity_count": activityCount,
            "travel_method": travelMethod.rawValue,
            "generated_suggestions": generatedSuggestions,
        ])
    }

    /// Fires on every EditTripView save, regardless of which fields
    /// changed — a lighter-weight "this trip was edited at all" signal.
    /// bagAppliedToTrip() below covers the one save-time sub-action
    /// worth its own event.
    static func tripUpdated() {
        Analytics.logEvent("trip_updated", parameters: nil)
    }

    static func tripDeleted(wasShared: Bool) {
        Analytics.logEvent("trip_deleted", parameters: [
            "was_shared": wasShared,
        ])
    }

    /// A trip coming back from Archived — always a deliberate tap
    /// (Restore), never fired for TripArchiver's automatic archiving
    /// (that's elapsed time, not a user action, so it isn't tracked).
    static func tripRestoredFromArchive() {
        Analytics.logEvent("trip_restored_from_archive", parameters: nil)
    }

    static func tripMapViewed() {
        Analytics.logEvent("trip_map_viewed", parameters: nil)
    }

    // MARK: - Items

    static func itemAdded(assigneeType: String) {
        Analytics.logEvent("item_added", parameters: [
            "assignee_type": assigneeType,
        ])
    }

    static func itemsDeleted(count: Int) {
        Analytics.logEvent("items_deleted", parameters: [
            "count": count,
        ])
    }

    /// One item's luggage assignment changed via the per-item menu —
    /// itemsBulkAssignedToLuggage below covers the multi-select path.
    static func itemLuggageChanged() {
        Analytics.logEvent("item_luggage_changed", parameters: nil)
    }

    static func itemsBulkAssignedToLuggage(count: Int) {
        Analytics.logEvent("items_bulk_assigned_to_luggage", parameters: [
            "count": count,
        ])
    }

    static func itemPackedToggled(isPacked: Bool) {
        Analytics.logEvent("item_packed_toggled", parameters: [
            "is_packed": isPacked,
        ])
    }

    // MARK: - Sharing

    static func shareSheetOpened() {
        Analytics.logEvent("share_sheet_opened", parameters: nil)
    }

    static func tripShared() {
        Analytics.logEvent("trip_shared", parameters: nil)
    }

    /// The share sheet's own save step failing after preparation already
    /// succeeded — see CloudSharingControllerView. Worth its own signal
    /// (not just Crashlytics) so how often this happens shows up in
    /// regular reporting, not just crash-adjacent tooling.
    static func shareSaveFailed() {
        Analytics.logEvent("share_save_failed", parameters: nil)
    }

    static func shareAccepted() {
        Analytics.logEvent("share_accepted", parameters: nil)
    }

    static func tripAddedToMyTrips() {
        Analytics.logEvent("trip_added_to_my_trips", parameters: nil)
    }

    /// Un-pinning a shared trip from My Trips — distinct from
    /// sharedTripLeft() below, which is fully leaving the share.
    static func sharedTripRemovedFromMyTrips() {
        Analytics.logEvent("shared_trip_removed_from_my_trips", parameters: nil)
    }

    static func sharedTripLeft() {
        Analytics.logEvent("shared_trip_left", parameters: nil)
    }

    // MARK: - Travelers & pets

    static func travelerProfileCreated() {
        Analytics.logEvent("traveler_profile_created", parameters: nil)
    }

    static func petProfileCreated() {
        Analytics.logEvent("pet_profile_created", parameters: nil)
    }

    /// `profileType` is "traveler" or "pet".
    static func profileDeleted(profileType: String) {
        Analytics.logEvent("profile_deleted", parameters: [
            "profile_type": profileType,
        ])
    }

    static func essentialItemAdded() {
        Analytics.logEvent("essential_item_added", parameters: nil)
    }

    static func essentialItemsDeleted(count: Int) {
        Analytics.logEvent("essential_items_deleted", parameters: [
            "count": count,
        ])
    }

    static func essentialSuggestionsCommitted(count: Int) {
        Analytics.logEvent("essential_suggestions_committed", parameters: [
            "count": count,
        ])
    }

    // MARK: - Bags ("My Bags")

    static func bagCreated() {
        Analytics.logEvent("bag_created", parameters: nil)
    }

    static func bagRenamed() {
        Analytics.logEvent("bag_renamed", parameters: nil)
    }

    static func bagDeleted() {
        Analytics.logEvent("bag_deleted", parameters: nil)
    }

    static func bagItemAdded() {
        Analytics.logEvent("bag_item_added", parameters: nil)
    }

    static func bagItemsDeleted(count: Int) {
        Analytics.logEvent("bag_items_deleted", parameters: [
            "count": count,
        ])
    }

    /// Fires whether an owner was assigned or cleared back to unassigned
    /// — both are "the owner changed", and a boolean says which.
    static func bagOwnerChanged(isNowOwned: Bool) {
        Analytics.logEvent("bag_owner_changed", parameters: [
            "is_now_owned": isNowOwned,
        ])
    }

    static func bagSuggestionsCommitted(count: Int) {
        Analytics.logEvent("bag_suggestions_committed", parameters: [
            "count": count,
        ])
    }

    static func bagAppliedToTrip() {
        Analytics.logEvent("bag_applied_to_trip", parameters: nil)
    }

    // MARK: - Categories & activities

    static func customCategoryCreated() {
        Analytics.logEvent("custom_category_created", parameters: nil)
    }

    static func customCategoryDeleted() {
        Analytics.logEvent("custom_category_deleted", parameters: nil)
    }

    static func customActivityCreated() {
        Analytics.logEvent("custom_activity_created", parameters: nil)
    }

    static func customActivityDeleted() {
        Analytics.logEvent("custom_activity_deleted", parameters: nil)
    }

    // MARK: - Feedback

    static func feedbackSubmitted() {
        Analytics.logEvent("feedback_submitted", parameters: nil)
    }

    // MARK: - Notifications

    static func notificationPermissionResult(granted: Bool) {
        Analytics.logEvent("notification_permission_result", parameters: [
            "granted": granted,
        ])
    }

    /// `kind` is derived from the notification's own identifier suffix
    /// ("startReminder", "unpackedReminder", "weatherAlert") — never the
    /// trip-specific portion of that identifier.
    static func notificationTapped(kind: String) {
        Analytics.logEvent("notification_tapped", parameters: [
            "kind": kind,
        ])
    }

    // MARK: - Onboarding

    static func myBagCoachMarkShown() {
        Analytics.logEvent("my_bag_coach_mark_shown", parameters: nil)
    }

    static func myBagCoachMarkDismissed() {
        Analytics.logEvent("my_bag_coach_mark_dismissed", parameters: nil)
    }

    static func myBagCoachMarkTapped() {
        Analytics.logEvent("my_bag_coach_mark_tapped", parameters: nil)
    }
}
