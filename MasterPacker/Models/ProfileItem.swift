import Foundation
import SwiftData

/// A single "always pack this" item saved to a `TravelerProfile`.
@Model
final class ProfileItem {
    var name: String = ""
    var category: PackingCategory = PackingCategory.misc
    var quantity: Int = 1
    var profile: TravelerProfile?

    init(name: String, category: PackingCategory, quantity: Int = 1, profile: TravelerProfile? = nil) {
        self.name = name
        self.category = category
        self.quantity = quantity
        self.profile = profile
    }
}
