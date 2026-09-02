import Foundation
import SwiftData

/// A user-defined trip activity chip. Text-only (no icon) — the built-in
/// `Activity` cases still cover icons (and packing-rule generation) for
/// standard activities; custom ones fall back to a generic icon wherever
/// a symbol is needed and never drive PackingRulesEngine, since there's
/// no rule written for an arbitrary name. Persisted (rather than typed
/// fresh each trip) so one shows up again as a selectable chip on future
/// trips too — same reuse model as `CustomCategory`.
@Model
final class CustomActivity {
    var name: String = ""

    init(name: String) {
        self.name = name
    }
}
