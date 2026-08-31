import Foundation

/// Resolves any packing item's name to one of CommonProfileItems'
/// browsing groups ("Clothing Essentials", "Footwear", …) — the same
/// taxonomy the Suggested Items picker uses — so TripDetailView's own
/// packing list reads with the same categories, not just the picker.
///
/// Same layered approach as `PackingIcon`: an exact match against the
/// curated staples list first (it's already hand-categorized), then
/// keyword rules for names PackingRulesEngine/weather/notes generate
/// that aren't in that list (e.g. "Hiking boots", "Business attire"),
/// then a sensible default for the item's PackingCategory so nothing is
/// ever left ungrouped.
///
/// Deliberately NOT used for pet items — every pet item already shares
/// one PackingCategory (.petSupplies), so the existing category grouping
/// already collapses a pet's section to a single correctly-named
/// "PET SUPPLIES" header; none of these 9 human-oriented groups fit a
/// leash or a bag of kibble, and "Miscellaneous" would just be a worse
/// name for the same one-header outcome. See TripDetailView.
enum ItemDisplayGroup {
    static func group(forName name: String, category: PackingCategory) -> String {
        let lowercased = name.lowercased()
        if let curated = curatedLookup[lowercased] {
            return curated
        }
        for rule in keywordRules where rule.keywords.contains(where: lowercased.contains) {
            return rule.group
        }
        return categoryDefault[category] ?? "Miscellaneous"
    }

    /// A representative icon for a group's header row — reuses the
    /// matching PackingCategory's own icon wherever one group maps
    /// cleanly onto one category, so these stay visually consistent with
    /// the rest of the app's iconography rather than inventing a
    /// parallel set.
    static func symbol(for group: String) -> String {
        symbols[group] ?? PackingCategory.misc.symbol
    }

    private static let symbols: [String: String] = [
        "Clothing Essentials": PackingCategory.clothing.symbol,
        "Footwear": "shoe.2",
        "Outerwear & Accessories": "umbrella",
        "Toiletries & Personal Care": PackingCategory.toiletries.symbol,
        "Health & Wellness": "cross.case",
        "Documents & Essentials": PackingCategory.documents.symbol,
        "Tech & Electronics": PackingCategory.electronics.symbol,
        "Bags & Organization": PackingCategory.gear.symbol,
        "Miscellaneous": PackingCategory.misc.symbol,
    ]

    private static let curatedLookup: [String: String] = Dictionary(
        uniqueKeysWithValues: CommonProfileItems.all.map { ($0.name.lowercased(), $0.group) }
    )

    private static let categoryDefault: [PackingCategory: String] = [
        .clothing: "Clothing Essentials",
        .toiletries: "Toiletries & Personal Care",
        .electronics: "Tech & Electronics",
        .documents: "Documents & Essentials",
        .gear: "Miscellaneous",
        .petSupplies: "Miscellaneous",
        .misc: "Miscellaneous",
    ]

    private static let keywordRules: [(keywords: [String], group: String)] = [
        // Footwear — checked first so "snow boots"/"hiking boots"/
        // "running shoes" land here rather than a more general bucket.
        (["boot", "shoe", "sneaker", "sandal", "flip-flop", "flip flop"], "Footwear"),

        // Outerwear, cold-weather layers, and eyewear.
        (
            ["rain jacket", "raincoat", "waterproof", "umbrella", "snow jacket",
             "snow pants", "warm jacket", "warm hat", "glove", "thermal",
             "sunglasses", "goggles", "scarf"],
            "Outerwear & Accessories"
        ),

        (["sunscreen", "first aid"], "Health & Wellness"),
        (["diaper", "wipes", "toiletries"], "Toiletries & Personal Care"),
        (["passport", "travel documents", "reservations"], "Documents & Essentials"),
        (["laptop", "phone charger"], "Tech & Electronics"),

        (
            ["backpack", "day bag", "sleeping bag", "headlamp", "flashlight",
             "tent", "camp stove", "laundry bag"],
            "Bags & Organization"
        ),

        // Everything else that's still clothing (basics, activewear,
        // formal/business, sleepwear) — checked last so nothing above
        // gets shadowed by a broader clothing match first.
        (
            ["swimsuit", "swim trunks", "bikini", "pajama", "pyjama", "sleepwear",
             "nightgown", "onesie", "outfit", "underwear", "sock", "t-shirt",
             "tshirt", "pant", "short", "workout clothes", "business attire"],
            "Clothing Essentials"
        ),
    ]
}
