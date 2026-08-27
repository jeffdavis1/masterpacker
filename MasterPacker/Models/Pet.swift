import Foundation
import SwiftData

@Model
final class Pet {
    // Default values at the declaration site — required for SwiftData's
    // CloudKit sync.
    var name: String = ""
    var species: PetSpecies = PetSpecies.dog
    var trip: Trip?

    // Gives PackingItem.pet a declared inverse — CloudKit requires every
    // relationship to have one. Optional, per CloudKit's requirement that
    // all to-many relationships be Optional.
    @Relationship(inverse: \PackingItem.pet)
    var packingItems: [PackingItem]? = []

    init(name: String, species: PetSpecies, trip: Trip? = nil) {
        self.name = name
        self.species = species
        self.trip = trip
    }
}

enum PetSpecies: String, Codable, CaseIterable, Identifiable {
    case dog = "Dog"
    case cat = "Cat"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .dog: return "dog"
        case .cat: return "cat"
        case .other: return "pawprint"
        }
    }
}
