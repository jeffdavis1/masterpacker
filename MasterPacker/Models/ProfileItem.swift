import Foundation
import SwiftData

/// A single "always pack this" item saved to a `TravelerProfile` or a
/// `PetProfile` (exactly one of `profile`/`petProfile` is set — mirrors how
/// `PackingItem` has separate optional `traveler`/`pet` relationships).
///
/// `categoryName` is a free-form string rather than the `PackingCategory`
/// enum, so a profile item can use either a built-in category or a custom
/// one the user has saved (see `CustomCategory`). `displaySymbol` resolves
/// it back to a built-in category's icon when possible, falling back to a
/// generic tag icon for custom categories.
@Model
final class ProfileItem {
    var name: String = ""
    var categoryName: String = PackingCategory.misc.rawValue
    var quantity: Int = 1
    var profile: TravelerProfile?
    var petProfile: PetProfile?

    init(
        name: String,
        categoryName: String,
        quantity: Int = 1,
        profile: TravelerProfile? = nil,
        petProfile: PetProfile? = nil
    ) {
        self.name = name
        self.categoryName = categoryName
        self.quantity = quantity
        self.profile = profile
        self.petProfile = petProfile
    }

    var displaySymbol: String {
        let categorySymbol = PackingCategory(rawValue: categoryName)?.symbol ?? "tag"
        return PackingIcon.symbol(forName: name, fallback: categorySymbol)
    }
}
