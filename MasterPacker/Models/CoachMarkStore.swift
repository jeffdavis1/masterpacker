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
    /// bag or dismisses it 3 times.
    static var shouldShowMyBagCoachMark: Bool {
        !UserDefaults.standard.bool(forKey: Key.firstBagCreated)
            && UserDefaults.standard.integer(forKey: Key.dismissals) < 3
    }

    /// Tapping the X — an explicit decline, unlike tapping the coach mark
    /// itself (which navigates to My Bag but doesn't count against the
    /// 3-strikes limit, since following the prompt isn't turning it down).
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
