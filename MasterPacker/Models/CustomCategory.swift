import Foundation
import SwiftData

/// A user-defined packing category, scoped to traveler-profile items.
/// Text-only (no icon) — the built-in `PackingCategory` cases still cover
/// icons for standard categories; custom ones fall back to a generic tag
/// icon (see `ProfileItem.displaySymbol`).
@Model
final class CustomCategory {
    var name: String = ""

    init(name: String) {
        self.name = name
    }
}
