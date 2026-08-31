import Foundation

/// A curated, near-universal set of "always pack" items shown as tappable
/// suggestions when building a traveler profile or a saved bag
/// (`PackingTemplate`, in `TemplateDetailView`). Deterministic and offline,
/// same approach as `PackingRulesEngine`.
///
/// `group` is purely a browsing label — grouped/order via `groupOrder`
/// below into the expandable category list ProfileDetailView and
/// TemplateDetailView show ("Clothing Essentials", "Footwear", …) — it's
/// separate from `category` (the `PackingCategory` actually stored on the
/// resulting ProfileItem/TemplateItem), since several display groups
/// (e.g. Footwear, Outerwear) all map to the same storage category
/// (.clothing).
enum CommonProfileItems {
    struct Suggestion: Identifiable, Hashable {
        var id: String { name }
        let name: String
        let category: PackingCategory
        let group: String = "Frequently Packed"
    }

    /// Display order for the expandable category sections — fixed rather
    /// than alphabetical, so it reads in the same order a person actually
    /// packs (clothes and shoes first, documents and misc last).
    static let groupOrder: [String] = [
        "Clothing Essentials",
        "Footwear",
        "Outerwear & Accessories",
        "Toiletries & Personal Care",
        "Health & Wellness",
        "Documents & Essentials",
        "Tech & Electronics",
        "Bags & Organization",
        "Miscellaneous",
    ]

    /// Buckets `suggestions` by `group`, in `groupOrder`'s fixed order —
    /// a group with nothing in it (e.g. everything in it already got
    /// added) simply doesn't produce a bucket, so it just disappears from
    /// the expandable list rather than showing empty.
    static func grouped(_ suggestions: [Suggestion]) -> [(group: String, suggestions: [Suggestion])] {
        let byGroup = Dictionary(grouping: suggestions, by: \.group)
        return groupOrder.compactMap { group in
            guard let items = byGroup[group], !items.isEmpty else { return nil }
            return (group, items)
        }
    }

    static let all: [Suggestion] = [
        // MARK: Clothing Essentials
        Suggestion(name: "T-shirts / casual tops", category: .clothing, group: "Clothing Essentials"),
        Suggestion(name: "Long-sleeve shirt", category: .clothing, group: "Clothing Essentials"),
        Suggestion(name: "Shorts", category: .clothing, group: "Clothing Essentials"),
        Suggestion(name: "Jeans / everyday pants", category: .clothing, group: "Clothing Essentials"),
        Suggestion(name: "Underwear", category: .clothing, group: "Clothing Essentials"),
        Suggestion(name: "Socks", category: .clothing, group: "Clothing Essentials"),
        Suggestion(name: "Bra", category: .clothing, group: "Clothing Essentials"),
        Suggestion(name: "Pajamas", category: .clothing, group: "Clothing Essentials"),
        Suggestion(name: "Sweater / light jacket", category: .clothing, group: "Clothing Essentials"),
        Suggestion(name: "Formal / nicer outfit", category: .clothing, group: "Clothing Essentials"),
        Suggestion(name: "Swimsuit", category: .clothing, group: "Clothing Essentials"),

        // MARK: Footwear
        Suggestion(name: "Comfortable everyday shoes", category: .clothing, group: "Footwear"),
        Suggestion(name: "Sandals / flip-flops", category: .clothing, group: "Footwear"),
        Suggestion(name: "Athletic / walking shoes", category: .clothing, group: "Footwear"),
        Suggestion(name: "Dress shoes", category: .clothing, group: "Footwear"),

        // MARK: Outerwear & Accessories
        Suggestion(name: "Rain jacket", category: .clothing, group: "Outerwear & Accessories"),
        Suggestion(name: "Umbrella", category: .gear, group: "Outerwear & Accessories"),
        Suggestion(name: "Hat / cap", category: .clothing, group: "Outerwear & Accessories"),
        Suggestion(name: "Scarf", category: .clothing, group: "Outerwear & Accessories"),
        Suggestion(name: "Sunglasses", category: .gear, group: "Outerwear & Accessories"),
        Suggestion(name: "Belt", category: .clothing, group: "Outerwear & Accessories"),
        Suggestion(name: "Lightweight layers / cardigan", category: .clothing, group: "Outerwear & Accessories"),

        // MARK: Toiletries & Personal Care
        Suggestion(name: "Toothbrush", category: .toiletries, group: "Toiletries & Personal Care"),
        Suggestion(name: "Toothpaste", category: .toiletries, group: "Toiletries & Personal Care"),
        Suggestion(name: "Deodorant", category: .toiletries, group: "Toiletries & Personal Care"),
        Suggestion(name: "Shampoo & conditioner", category: .toiletries, group: "Toiletries & Personal Care"),
        Suggestion(name: "Soap / body wash", category: .toiletries, group: "Toiletries & Personal Care"),
        Suggestion(name: "Face wash", category: .toiletries, group: "Toiletries & Personal Care"),
        Suggestion(name: "Moisturizer", category: .toiletries, group: "Toiletries & Personal Care"),
        Suggestion(name: "Sunscreen", category: .toiletries, group: "Toiletries & Personal Care"),
        Suggestion(name: "Hairbrush", category: .toiletries, group: "Toiletries & Personal Care"),
        Suggestion(name: "Hair styling products", category: .toiletries, group: "Toiletries & Personal Care"),
        Suggestion(name: "Makeup & makeup remover", category: .toiletries, group: "Toiletries & Personal Care"),
        Suggestion(name: "Feminine hygiene products", category: .toiletries, group: "Toiletries & Personal Care"),
        Suggestion(name: "Razor", category: .toiletries, group: "Toiletries & Personal Care"),
        Suggestion(name: "Shaving cream", category: .toiletries, group: "Toiletries & Personal Care"),
        Suggestion(name: "Nail clippers", category: .toiletries, group: "Toiletries & Personal Care"),
        Suggestion(name: "Contact lenses & solution", category: .toiletries, group: "Toiletries & Personal Care"),

        // MARK: Health & Wellness
        Suggestion(name: "Medications", category: .toiletries, group: "Health & Wellness"),
        Suggestion(name: "Vitamins", category: .toiletries, group: "Health & Wellness"),
        Suggestion(name: "Pain reliever", category: .toiletries, group: "Health & Wellness"),
        Suggestion(name: "Antacid", category: .toiletries, group: "Health & Wellness"),
        Suggestion(name: "Allergy medication", category: .toiletries, group: "Health & Wellness"),
        Suggestion(name: "Cold / flu medicine", category: .toiletries, group: "Health & Wellness"),
        Suggestion(name: "First aid kit", category: .gear, group: "Health & Wellness"),
        Suggestion(name: "Melatonin / sleep aid", category: .toiletries, group: "Health & Wellness"),
        Suggestion(name: "Digestive aids", category: .toiletries, group: "Health & Wellness"),

        // MARK: Documents & Essentials
        Suggestion(name: "Passport / ID", category: .documents, group: "Documents & Essentials"),
        Suggestion(name: "Driver's license", category: .documents, group: "Documents & Essentials"),
        Suggestion(name: "Travel insurance documents", category: .documents, group: "Documents & Essentials"),
        Suggestion(name: "Flight confirmations", category: .documents, group: "Documents & Essentials"),
        Suggestion(name: "Hotel reservations", category: .documents, group: "Documents & Essentials"),
        Suggestion(name: "Credit & debit cards", category: .documents, group: "Documents & Essentials"),
        Suggestion(name: "Health insurance card", category: .documents, group: "Documents & Essentials"),
        Suggestion(name: "Wallet", category: .misc, group: "Documents & Essentials"),
        Suggestion(name: "Copies of important documents", category: .documents, group: "Documents & Essentials"),

        // MARK: Tech & Electronics
        Suggestion(name: "Phone", category: .electronics, group: "Tech & Electronics"),
        Suggestion(name: "Phone charger", category: .electronics, group: "Tech & Electronics"),
        Suggestion(name: "Power adapter", category: .electronics, group: "Tech & Electronics"),
        Suggestion(name: "Portable battery pack", category: .electronics, group: "Tech & Electronics"),
        Suggestion(name: "Headphones", category: .electronics, group: "Tech & Electronics"),
        Suggestion(name: "Laptop / tablet", category: .electronics, group: "Tech & Electronics"),
        Suggestion(name: "Camera", category: .electronics, group: "Tech & Electronics"),
        Suggestion(name: "Charging cables", category: .electronics, group: "Tech & Electronics"),

        // MARK: Bags & Organization
        Suggestion(name: "Day backpack / small bag", category: .gear, group: "Bags & Organization"),
        Suggestion(name: "Packing cubes", category: .gear, group: "Bags & Organization"),
        Suggestion(name: "Toiletry bag", category: .gear, group: "Bags & Organization"),
        Suggestion(name: "Shoe bag", category: .gear, group: "Bags & Organization"),
        Suggestion(name: "Compression bags", category: .gear, group: "Bags & Organization"),

        // MARK: Miscellaneous
        Suggestion(name: "Notebook & pen", category: .misc, group: "Miscellaneous"),
        Suggestion(name: "Book / e-reader", category: .misc, group: "Miscellaneous"),
        Suggestion(name: "Earplugs", category: .misc, group: "Miscellaneous"),
        Suggestion(name: "Eye mask", category: .misc, group: "Miscellaneous"),
        Suggestion(name: "Travel pillow", category: .gear, group: "Miscellaneous"),
        Suggestion(name: "Reusable water bottle", category: .gear, group: "Miscellaneous"),
        Suggestion(name: "Hand sanitizer", category: .misc, group: "Miscellaneous"),
        Suggestion(name: "Wet wipes", category: .misc, group: "Miscellaneous"),
    ]
}
