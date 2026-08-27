import Foundation
import SwiftData

@Model
final class Pet {
    var name: String
    var species: PetSpecies
    var trip: Trip?

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
