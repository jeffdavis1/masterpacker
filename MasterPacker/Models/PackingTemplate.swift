import Foundation

/// Builds a starter packing list scaled to a trip's type and length.
enum PackingTemplate {
    static func suggestedItems(for tripType: TripType, days: Int) -> [(name: String, category: PackingCategory, quantity: Int)] {
        var items: [(name: String, category: PackingCategory, quantity: Int)] = [
            ("Passport / ID", .documents, 1),
            ("Wallet & cards", .documents, 1),
            ("Phone charger", .electronics, 1),
            ("Toothbrush", .toiletries, 1),
            ("Toothpaste", .toiletries, 1),
            ("Underwear", .clothing, days),
            ("Socks", .clothing, days),
            ("T-shirts / tops", .clothing, max(2, days)),
        ]

        switch tripType {
        case .beach:
            items += [
                ("Swimsuit", .clothing, 2),
                ("Sunscreen", .toiletries, 1),
                ("Sunglasses", .gear, 1),
                ("Flip-flops", .clothing, 1),
                ("Beach towel", .gear, 1),
            ]
        case .cityBreak:
            items += [
                ("Comfortable walking shoes", .clothing, 1),
                ("Day bag", .gear, 1),
                ("Portable charger", .electronics, 1),
            ]
        case .hiking:
            items += [
                ("Hiking boots", .clothing, 1),
                ("Rain jacket", .clothing, 1),
                ("Backpack", .gear, 1),
                ("Water bottle", .gear, 1),
                ("First aid kit", .gear, 1),
            ]
        case .business:
            items += [
                ("Business attire", .clothing, days),
                ("Laptop & charger", .electronics, 1),
                ("Business cards", .documents, 1),
            ]
        case .coldWeather:
            items += [
                ("Winter coat", .clothing, 1),
                ("Gloves", .clothing, 1),
                ("Warm hat", .clothing, 1),
                ("Thermal layers", .clothing, 2),
            ]
        case .general:
            break
        }

        if days > 3 {
            items.append(("Laundry bag", .misc, 1))
        }

        return items
    }
}
