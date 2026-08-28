import Foundation
import SwiftData

@Model
final class PackingItem {
    // Default values at the declaration site — required for SwiftData's
    // CloudKit sync.

    /// Stable, launch-independent identifier — see Trip.id's doc comment
    /// for why persistentModelID isn't safe to use for this.
    var id: UUID = UUID()
    var name: String = ""
    var category: PackingCategory = PackingCategory.misc
    var quantity: Int = 1
    var isPacked: Bool = false
    var trip: Trip?

    /// Who this item is for. Both nil means it's a shared/household item.
    var traveler: Traveler?
    var pet: Pet?

    init(
        name: String,
        category: PackingCategory,
        quantity: Int = 1,
        isPacked: Bool = false,
        trip: Trip? = nil,
        traveler: Traveler? = nil,
        pet: Pet? = nil
    ) {
        self.name = name
        self.category = category
        self.quantity = quantity
        self.isPacked = isPacked
        self.trip = trip
        self.traveler = traveler
        self.pet = pet
    }

    /// Display label for the section this item belongs in.
    var assigneeLabel: String {
        if let traveler { return traveler.name }
        if let pet { return "\(pet.name) (pet)" }
        return "Shared"
    }

    /// A more specific icon based on the item's name when one matches
    /// (e.g. "Hiking boots" gets a shoe icon, not the generic clothing
    /// icon), falling back to the category's icon otherwise.
    var displaySymbol: String {
        PackingIcon.symbol(forName: name, fallback: category.symbol)
    }
}

enum PackingCategory: String, Codable, CaseIterable, Identifiable {
    case clothing = "Clothing"
    case toiletries = "Toiletries"
    case electronics = "Electronics"
    case documents = "Documents"
    case gear = "Gear"
    case petSupplies = "Pet Supplies"
    case misc = "Miscellaneous"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .clothing: return "tshirt"
        case .toiletries: return "drop"
        case .electronics: return "bolt"
        case .documents: return "doc.text"
        case .gear: return "backpack"
        case .petSupplies: return "pawprint"
        case .misc: return "shippingbox"
        }
    }
}

/// Picks a more specific icon based on an item's name when one matches
/// (e.g. "Hiking boots" -> a shoe icon), falling back to a category's
/// default icon otherwise. A modest, high-confidence keyword set — not
/// exhaustive, but meaningfully more accurate than one icon per category
/// for clothing items in particular. Shared by `PackingItem` and
/// `ProfileItem`.
enum PackingIcon {
    static func symbol(forName name: String, fallback: String) -> String {
        let lowercased = name.lowercased()
        for rule in rules where rule.keywords.contains(where: lowercased.contains) {
            return rule.symbol
        }
        return fallback
    }

    private static let rules: [(keywords: [String], symbol: String)] = [
        (["boot", "shoe", "sneaker", "sandal", "flip-flop", "flip flop"], "shoe.2.fill"),
        (["swimsuit", "swim trunks", "bikini", "swim"], "figure.pool.swim"),
        (["sunglasses", "goggles"], "eyeglasses"),
        (["thermal", "snow jacket", "snow pants", "warm hat"], "snowflake"),
        (["suit", "formal", "dress shoes", "business attire", "tie"], "briefcase.fill"),
        (["rain jacket", "raincoat", "waterproof"], "umbrella.fill"),
        (["hiking boots", "hiking"], "figure.hiking"),
    ]
}
