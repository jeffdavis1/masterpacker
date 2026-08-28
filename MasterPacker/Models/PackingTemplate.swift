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

    init(name: String) {
        self.name = name
    }

    var items: [TemplateItem] {
        get { itemsStorage ?? [] }
        set { itemsStorage = newValue }
    }
}
