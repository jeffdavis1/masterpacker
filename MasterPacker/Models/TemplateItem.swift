import Foundation
import SwiftData

/// A single item saved to a `PackingTemplate`. Uses the same free-form
/// categoryName-string pattern as ProfileItem and PackingItem, so a
/// custom category created anywhere in the app is usable here too.
@Model
final class TemplateItem {
    var name: String = ""
    var categoryName: String = PackingCategory.misc.rawValue
    var quantity: Int = 1
    var template: PackingTemplate?

    init(name: String, categoryName: String, quantity: Int = 1, template: PackingTemplate? = nil) {
        self.name = name
        self.categoryName = categoryName
        self.quantity = quantity
        self.template = template
    }

    var displaySymbol: IconRef {
        let categorySymbol = PackingCategory(rawValue: categoryName)?.symbol ?? "tag"
        return PackingIcon.iconRef(forName: name, fallback: categorySymbol)
    }
}
