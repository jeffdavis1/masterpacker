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

    /// Which of the trip's Luggage this item is packed in, if the user
    /// has bothered to assign one — nil just means "not sorted into a
    /// bag yet", not an error state.
    var luggage: Luggage?

    init(
        name: String,
        category: PackingCategory,
        quantity: Int = 1,
        isPacked: Bool = false,
        trip: Trip? = nil,
        traveler: Traveler? = nil,
        pet: Pet? = nil,
        luggage: Luggage? = nil
    ) {
        self.name = name
        self.category = category
        self.quantity = quantity
        self.isPacked = isPacked
        self.trip = trip
        self.traveler = traveler
        self.pet = pet
        self.luggage = luggage
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
        // Split from umbrella below — a rain jacket and an umbrella are
        // different objects and shouldn't share an icon just because
        // they're both rain gear.
        (["rain jacket", "raincoat", "waterproof"], "cloud.rain.fill"),
        (["umbrella"], "umbrella.fill"),
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
        // Must precede the generic "phone" rule below — "Phone charger"
        // would otherwise match "phone" first and get the iphone icon
        // instead of a charging-cable one.
        (["phone charger", "charging cable"], "cable.connector"),
        (["power adapter", "plug adapter"], "powerplug.fill"),
        (["phone"], "iphone"),
        (["camera"], "camera.fill"),
        (["headphone"], "headphones"),
        (["laptop"], "laptopcomputer"),
        (["credit card", "debit card"], "creditcard.fill"),
        (["wallet"], "wallet.pass.fill"),
        (["flight", "boarding pass"], "airplane"),
        // Must precede "book"/"e-reader" below — "Notebook" contains
        // "book" as a substring and would otherwise match that instead.
        (["notebook"], "pencil"),
        (["book", "e-reader"], "book.fill"),
        (["nail clipper"], "scissors"),
        (["hand sanitizer"], "hands.sparkles.fill"),
        (["packing cube"], "shippingbox.fill"),
        (["toiletry bag"], "bag.fill"),
        (["compression bag"], "archivebox.fill"),
        // Liquid/gel toiletries — distinct from the plain "drop" outline
        // used as toiletries' category fallback.
        (["shampoo", "conditioner", "body wash", "face wash", "moisturizer", "hair styling", "soap"], "drop.fill"),
        // General over-the-counter medications/supplements — distinct
        // from the toiletries category fallback, without needing a
        // separate icon per symptom (no such icons exist to pick from).
        (["pain reliever", "antacid", "allergy medication", "flu medicine", "cold medicine", "melatonin", "sleep aid", "digestive aid", "vitamin"], "pills.fill"),
        (["sleeping bag"], "bed.double.fill"),
        (["headlamp", "flashlight"], "flashlight.on.fill"),
        (["tent"], "tent.fill"),
        (["camp stove"], "flame.fill"),
    ]
}
