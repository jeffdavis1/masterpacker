import Foundation
import SwiftData

/// A reusable saved pet whose always-pack list can be applied to any trip's
/// pet slot, instead of retyping the same items every time. Mirrors
/// `TravelerProfile`'s design — picking a pet profile when adding a pet to
/// a trip copies its name/species and always-items in as a one-time
/// starting point.
@Model
final class PetProfile {
    var name: String = ""
    var species: PetSpecies = PetSpecies.dog

    @Relationship(deleteRule: .cascade, inverse: \ProfileItem.petProfile)
    private var alwaysItemsStorage: [ProfileItem]? = []

    init(name: String, species: PetSpecies = .dog) {
        self.name = name
        self.species = species
    }

    var alwaysItems: [ProfileItem] {
        get { alwaysItemsStorage ?? [] }
        set { alwaysItemsStorage = newValue }
    }
}
