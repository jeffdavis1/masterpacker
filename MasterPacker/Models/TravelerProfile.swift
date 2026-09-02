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

    // Many-to-many with PackingTemplate — a bag can belong to more than
    // one traveler, and a traveler can own more than one bag. .nullify
    // (the default) rather than .cascade: deleting a traveler profile
    // shouldn't take their bags down with them, just unassign them.
    @Relationship(inverse: \PackingTemplate.ownersStorage)
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
    /// PackingTemplate.owners for what an empty assignment means.
    var ownedTemplates: [PackingTemplate] {
        get { ownedTemplatesStorage ?? [] }
        set { ownedTemplatesStorage = newValue }
    }
}
