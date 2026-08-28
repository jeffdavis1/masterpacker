import Foundation

/// A curated, near-universal set of "always pack" items shown as tappable
/// suggestions when building a pet profile. Mirrors `CommonProfileItems`.
enum CommonPetItems {
    static let all: [CommonProfileItems.Suggestion] = [
        Suggestion(name: "Food (travel supply)", category: .petSupplies),
        Suggestion(name: "Food & water bowls", category: .petSupplies),
        Suggestion(name: "Leash & collar", category: .petSupplies),
        Suggestion(name: "Waste bags", category: .petSupplies),
        Suggestion(name: "Litter & travel litter box", category: .petSupplies),
        Suggestion(name: "Travel crate / carrier", category: .petSupplies),
        Suggestion(name: "Favorite toy / bed", category: .petSupplies),
        Suggestion(name: "Medications", category: .petSupplies),
        Suggestion(name: "Vaccination & vet records", category: .documents),
    ]

    private typealias Suggestion = CommonProfileItems.Suggestion
}
