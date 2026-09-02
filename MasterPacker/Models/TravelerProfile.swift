import Foundation
import SwiftData

/// A reusable "person" whose always-pack list can be applied to any trip's
/// traveler slot, instead of retyping the same items every time.
///
/// Distinct from `Traveler`, which is scoped to a single trip: picking a
/// profile when adding a traveler to a trip copies its name/age bracket and
/// always-items in as a one-time starting point. Editing the profile later
/// doesn't retroactively change trips that already used it — it's a
/// template, not a live link.
@Model
final class TravelerProfile {
    var name: String = ""
    var ageBracket: AgeBracket = AgeBracket.adult

    @Relationship(deleteRule: .cascade, inverse: \ProfileItem.profile)
    private var alwaysItemsStorage: [ProfileItem]? = []

    // One-to-many with PackingTemplate — a traveler can own more than one
    // bag, but (per explicit product decision) each bag belongs to at
    // most one traveler. .nullify (the default) rather than .cascade:
    // deleting a traveler profile shouldn't take their bags down with
    // them, just unassign them.
    @Relationship(inverse: \PackingTemplate.owner)
    private var ownedTemplatesStorage: [PackingTemplate]? = []

    init(name: String, ageBracket: AgeBracket = .adult) {
        self.name = name
        self.ageBracket = ageBracket
    }

    var alwaysItems: [ProfileItem] {
        get { alwaysItemsStorage ?? [] }
        set { alwaysItemsStorage = newValue }
    }

    /// Bags (My Bag templates) assigned to this traveler — see
    /// PackingTemplate.owner for what an unassigned bag means.
    var ownedTemplates: [PackingTemplate] {
        get { ownedTemplatesStorage ?? [] }
        set { ownedTemplatesStorage = newValue }
    }
}
