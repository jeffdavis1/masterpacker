import Foundation

/// A curated, near-universal set of "always pack" items shown as tappable
/// suggestions when building a traveler profile or a saved bag
/// (`PackingTemplate`, in `TemplateDetailView`). Deterministic and offline,
/// same approach as `PackingRulesEngine`.
enum CommonProfileItems {
    struct Suggestion: Identifiable, Hashable {
        var id: String { name }
        let name: String
        let category: PackingCategory
    }

    static let all: [Suggestion] = [
        // Toiletries
        Suggestion(name: "Toothbrush", category: .toiletries),
        Suggestion(name: "Toothpaste", category: .toiletries),
        Suggestion(name: "Deodorant", category: .toiletries),
        Suggestion(name: "Razor", category: .toiletries),
        Suggestion(name: "Hairbrush", category: .toiletries),
        Suggestion(name: "Contact lenses & solution", category: .toiletries),
        Suggestion(name: "Medications", category: .toiletries),

        // Electronics
        Suggestion(name: "Phone charger", category: .electronics),
        Suggestion(name: "Portable battery pack", category: .electronics),
        Suggestion(name: "Headphones", category: .electronics),
        Suggestion(name: "Charging cables", category: .electronics),

        // Documents
        Suggestion(name: "Driver's license / ID", category: .documents),
        Suggestion(name: "Credit & debit cards", category: .documents),
        Suggestion(name: "Health insurance card", category: .documents),

        // Gear
        Suggestion(name: "Reusable water bottle", category: .gear),
        Suggestion(name: "Sunglasses", category: .gear),
        Suggestion(name: "Travel pillow", category: .gear),

        // Miscellaneous
        Suggestion(name: "Earplugs", category: .misc),
        Suggestion(name: "Eye mask", category: .misc),
    ]
}
