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
        // "dress shoes" deliberately isn't listed below (unreachable —
        // "shoe" above already catches it first, correctly, since dress
        // shoes are still shoes).
        (["suit", "formal", "business attire", "tie"], "briefcase.fill"),
        // Sleepwear used to fall through to the generic tshirt icon,
        // indistinguishable from actual shirts — the most-cited example
        // of the icon-accuracy problem this rework fixes.
        (["pajama", "pyjama", "sleepwear", "nightgown"], "moon.zzz.fill"),
        // "umbrella" on its own used to miss this rule entirely (only
        // "rain jacket"/"raincoat"/"waterproof" matched), so the actual
        // generated "Umbrella" weather item never got its own icon.
        (["rain jacket", "raincoat", "waterproof", "umbrella"], "umbrella.fill"),
        // Cold-weather gear — snow jacket/pants matched here before, but
        // "warm jacket" (the actual generated weather-item name) and
        // "gloves" fell through to generic tshirt; grouped together
        // since they're all the same kind of gear.
        (["thermal", "snow jacket", "snow pants", "warm jacket", "warm hat", "glove"], "snowflake"),
        // "hiking boots" isn't listed here (unreachable — "boot" above
        // already catches it first, and shoe.2.fill is a fine icon for
        // them too); "hiking" alone still catches other hiking gear.
        (["hiking"], "figure.hiking"),
        (["sunscreen"], "sun.max.fill"),
        (["first aid"], "cross.case.fill"),
        (["laptop"], "laptopcomputer"),
        (["sleeping bag"], "bed.double.fill"),
        (["headlamp", "flashlight"], "flashlight.on.fill"),
        (["tent"], "tent.fill"),
        (["camp stove"], "flame.fill"),
    ]
}
