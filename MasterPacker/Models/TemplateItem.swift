import Foundation
import SwiftData

/// A single item saved to a `PackingTemplate`. Uses the closed
/// `PackingCategory` enum (not the free-form categoryName string
/// `ProfileItem` uses) — custom categories were scoped to traveler/pet
/// profile items only.
@Model
final class TemplateItem {
    var name: String = ""
    var category: PackingCategory = PackingCategory.misc
    var quantity: Int = 1
    var template: PackingTemplate?

    init(name: String, category: PackingCategory, quantity: Int = 1, template: PackingTemplate? = nil) {
        self.name = name
        self.category = category
        self.quantity = quantity
        self.template = template
    }

    var displaySymbol: String {
        PackingIcon.symbol(forName: name, fallback: category.symbol)
    }
}
