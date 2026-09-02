import Foundation

/// Persistence for the My Bag onboarding coach mark (see
/// MyBagCoachMarkOverlay) — plain UserDefaults, not SwiftData, since this
/// is per-device onboarding state, not app data that should sync via
/// CloudKit or show up anywhere else.
enum CoachMarkStore {
    private enum Key {
        static let dismissals = "myBagCoachMarkDismissals"
        static let appFirstLaunch = "appFirstLaunch"
        static let firstBagCreated = "firstBagCreated"
    }

    /// Explicit X-taps before the coach mark retires itself for good —
    /// tuned down from the spec's original 3 after QA found 3 felt like
    /// one dismissal too many. Ignoring it (just using the app, or
    /// force-quitting) never counts against this.
    private static let dismissalLimit = 2

    /// Call once at app startup. Doesn't itself gate the coach mark (see
    /// `shouldShowMyBagCoachMark` below, which per spec only checks
    /// dismissals/firstBagCreated so the coach mark can keep appearing
    /// across multiple launches, not just the very first) — this just
    /// records that a first launch has happened, tracked per the
    /// feature's own technical notes.
    static func recordAppLaunchIfNeeded() {
        if !UserDefaults.standard.bool(forKey: Key.appFirstLaunch) {
            UserDefaults.standard.set(true, forKey: Key.appFirstLaunch)
        }
    }

    /// Visible on every launch until either the user creates their first
    /// bag or dismisses it dismissalLimit times.
    static var shouldShowMyBagCoachMark: Bool {
        !UserDefaults.standard.bool(forKey: Key.firstBagCreated)
            && UserDefaults.standard.integer(forKey: Key.dismissals) < dismissalLimit
    }

    /// Tapping the X — an explicit decline, unlike tapping the coach mark
    /// itself (which navigates to My Bag but doesn't count against the
    /// dismissal limit, since following the prompt isn't turning it down).
    static func recordMyBagCoachMarkDismissal() {
        let count = UserDefaults.standard.integer(forKey: Key.dismissals) + 1
        UserDefaults.standard.set(count, forKey: Key.dismissals)
    }

    /// Called wherever a bag actually gets created (NewTemplateView.save())
    /// — permanently retires the coach mark regardless of dismissal count.
    static func recordFirstBagCreated() {
        UserDefaults.standard.set(true, forKey: Key.firstBagCreated)
    }
}
