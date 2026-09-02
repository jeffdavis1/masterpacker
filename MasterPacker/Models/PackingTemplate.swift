import Foundation
import SwiftData

/// A reusable, named list of items (e.g. "Camping Essentials") that can be
/// applied to any trip — either while creating it, or added afterward from
/// the trip detail page. Distinct from TravelerProfile/PetProfile, which
/// are per-person/per-pet: a template is trip-wide, and its items land in
/// the trip's Shared/household bucket when applied.
@Model
final class PackingTemplate {
    var name: String = ""

    @Relationship(deleteRule: .cascade, inverse: \TemplateItem.template)
    private var itemsStorage: [TemplateItem]? = []

    // Many-to-many; the inverse side (TravelerProfile.ownedTemplatesStorage)
    // owns the @Relationship(inverse:) declaration, so this side is just a
    // plain optional array — CloudKit still requires every to-many
    // relationship to be Optional, hence the plumbing below rather than a
    // bare non-optional array.
    private var ownersStorage: [TravelerProfile]? = []

    init(name: String) {
        self.name = name
    }

    var items: [TemplateItem] {
        get { itemsStorage ?? [] }
        set { itemsStorage = newValue }
    }

    /// Travelers this bag belongs to. Empty means unowned — which reads as
    /// "available for everyone" (see AddTripView's bag filtering) rather
    /// than belonging to no one, so every bag that existed before this
    /// feature shipped keeps working exactly as it did.
    var owners: [TravelerProfile] {
        get { ownersStorage ?? [] }
        set { ownersStorage = newValue }
    }
}
