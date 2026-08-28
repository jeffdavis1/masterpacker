import FirebaseAnalytics

/// A thin wrapper around Firebase Analytics — call sites log a named,
/// typed event instead of reaching for `Analytics.logEvent` directly, so
/// every event this app sends lives in one place with one naming
/// convention. Firebase is configured once, in
/// AppDelegate.didFinishLaunchingWithOptions; every call here is safe to
/// make regardless of whether that's happened yet (Firebase queues
/// events before configure() if it somehow ran first).
///
/// Covers the roadmap's "key events": trip creation, packing progress,
/// sharing actions, and feature usage (My Bag, custom categories,
/// custom activities) — not full screen-by-screen tracking, since named
/// business events are more useful than a raw navigation trace.
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

    static func tripDeleted(wasShared: Bool) {
        Analytics.logEvent("trip_deleted", parameters: [
            "was_shared": wasShared,
        ])
    }

    // MARK: - Packing progress

    static func itemPackedToggled(isPacked: Bool) {
        Analytics.logEvent("item_packed_toggled", parameters: [
            "is_packed": isPacked,
        ])
    }

    // MARK: - Sharing

    static func tripShared() {
        Analytics.logEvent("trip_shared", parameters: nil)
    }

    static func shareAccepted() {
        Analytics.logEvent("share_accepted", parameters: nil)
    }

    static func tripAddedToMyTrips() {
        Analytics.logEvent("trip_added_to_my_trips", parameters: nil)
    }

    static func sharedTripLeft() {
        Analytics.logEvent("shared_trip_left", parameters: nil)
    }

    // MARK: - Feature usage

    static func bagCreated() {
        Analytics.logEvent("bag_created", parameters: nil)
    }

    static func bagAppliedToTrip() {
        Analytics.logEvent("bag_applied_to_trip", parameters: nil)
    }

    static func customCategoryCreated() {
        Analytics.logEvent("custom_category_created", parameters: nil)
    }
}
