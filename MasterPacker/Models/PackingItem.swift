import Foundation
import SwiftData

@Model
final class PackingItem {
    // Default values at the declaration site — required for SwiftData's
    // CloudKit sync.
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
