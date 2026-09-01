import Foundation
import CloudKit

/// Lightweight, non-SwiftData view models for a trip shared *to* this
/// device (i.e. someone else's trip, accepted via CKShare) — built
/// straight from CKRecords fetched out of CloudKit's shared database.
/// CloudKit is still the source of truth; Codable here is only so
/// TripSharingService can cache the last-fetched snapshot in UserDefaults
/// for instant display on the next launch, not a second persistence
/// layer. Deliberately separate from Trip/Traveler/Pet/PackingItem so the
/// regular SwiftData-backed trip screens stay completely untouched by
/// this.
///
/// CKRecord.ID/CKRecordZone.ID aren't used directly as Codable payloads
/// here — rather than depend on the SDK's own conformance for those
/// types, each struct below encodes/decodes the plain recordName/
/// zoneName/ownerName strings they're built from and reconstructs the
/// CloudKit identifier on decode, the same pattern TripSharingService
/// already uses to persist a SharedTripLink to UserDefaults.
struct RemoteTrip: Identifiable, Codable {
    let zoneID: CKRecordZone.ID
    let recordID: CKRecord.ID
    var id: String { recordID.recordName }

    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var travelMethod: TravelMethod
    var activities: Set<Activity>
    var notes: String
    var travelers: [RemoteTraveler]
    var pets: [RemotePet]
    var items: [RemoteItem]

    var durationInDays: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(1, days + 1)
    }

    var packedCount: Int {
        items.filter(\.isPacked).count
    }

    init(
        zoneID: CKRecordZone.ID,
        recordID: CKRecord.ID,
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        travelMethod: TravelMethod,
        activities: Set<Activity>,
        notes: String,
        travelers: [RemoteTraveler],
        pets: [RemotePet],
        items: [RemoteItem]
    ) {
        self.zoneID = zoneID
        self.recordID = recordID
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.travelMethod = travelMethod
        self.activities = activities
        self.notes = notes
        self.travelers = travelers
        self.pets = pets
        self.items = items
    }

    private enum CodingKeys: String, CodingKey {
        case zoneName, ownerName, recordName
        case name, destination, startDate, endDate, travelMethod, activities, notes, travelers, pets, items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let zoneID = CKRecordZone.ID(
            zoneName: try container.decode(String.self, forKey: .zoneName),
            ownerName: try container.decode(String.self, forKey: .ownerName)
        )
        self.zoneID = zoneID
        self.recordID = CKRecord.ID(recordName: try container.decode(String.self, forKey: .recordName), zoneID: zoneID)
        name = try container.decode(String.self, forKey: .name)
        destination = try container.decode(String.self, forKey: .destination)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        travelMethod = try container.decode(TravelMethod.self, forKey: .travelMethod)
        activities = try container.decode(Set<Activity>.self, forKey: .activities)
        notes = try container.decode(String.self, forKey: .notes)
        travelers = try container.decode([RemoteTraveler].self, forKey: .travelers)
        pets = try container.decode([RemotePet].self, forKey: .pets)
        items = try container.decode([RemoteItem].self, forKey: .items)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(zoneID.zoneName, forKey: .zoneName)
        try container.encode(zoneID.ownerName, forKey: .ownerName)
        try container.encode(recordID.recordName, forKey: .recordName)
        try container.encode(name, forKey: .name)
        try container.encode(destination, forKey: .destination)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(travelMethod, forKey: .travelMethod)
        try container.encode(activities, forKey: .activities)
        try container.encode(notes, forKey: .notes)
        try container.encode(travelers, forKey: .travelers)
        try container.encode(pets, forKey: .pets)
        try container.encode(items, forKey: .items)
    }
}

struct RemoteTraveler: Identifiable, Codable {
    let recordID: CKRecord.ID
    var id: String { recordID.recordName }
    var name: String
    var ageBracket: AgeBracket

    init(recordID: CKRecord.ID, name: String, ageBracket: AgeBracket) {
        self.recordID = recordID
        self.name = name
        self.ageBracket = ageBracket
    }

    private enum CodingKeys: String, CodingKey {
        case recordName, zoneName, ownerName, name, ageBracket
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordID = CKRecord.ID(
            recordName: try container.decode(String.self, forKey: .recordName),
            zoneID: CKRecordZone.ID(
                zoneName: try container.decode(String.self, forKey: .zoneName),
                ownerName: try container.decode(String.self, forKey: .ownerName)
            )
        )
        name = try container.decode(String.self, forKey: .name)
        ageBracket = try container.decode(AgeBracket.self, forKey: .ageBracket)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recordID.recordName, forKey: .recordName)
        try container.encode(recordID.zoneID.zoneName, forKey: .zoneName)
        try container.encode(recordID.zoneID.ownerName, forKey: .ownerName)
        try container.encode(name, forKey: .name)
        try container.encode(ageBracket, forKey: .ageBracket)
    }
}

struct RemotePet: Identifiable, Codable {
    let recordID: CKRecord.ID
    var id: String { recordID.recordName }
    var name: String
    var species: PetSpecies

    init(recordID: CKRecord.ID, name: String, species: PetSpecies) {
        self.recordID = recordID
        self.name = name
        self.species = species
    }

    private enum CodingKeys: String, CodingKey {
        case recordName, zoneName, ownerName, name, species
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordID = CKRecord.ID(
            recordName: try container.decode(String.self, forKey: .recordName),
            zoneID: CKRecordZone.ID(
                zoneName: try container.decode(String.self, forKey: .zoneName),
                ownerName: try container.decode(String.self, forKey: .ownerName)
            )
        )
        name = try container.decode(String.self, forKey: .name)
        species = try container.decode(PetSpecies.self, forKey: .species)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recordID.recordName, forKey: .recordName)
        try container.encode(recordID.zoneID.zoneName, forKey: .zoneName)
        try container.encode(recordID.zoneID.ownerName, forKey: .ownerName)
        try container.encode(name, forKey: .name)
        try container.encode(species, forKey: .species)
    }
}

struct RemoteItem: Identifiable, Codable {
    let recordID: CKRecord.ID
    var id: String { recordID.recordName }
    var name: String
    var category: PackingCategory
    var quantity: Int
    var isPacked: Bool
    /// Record names (not references) of the owning RemoteTraveler/RemotePet,
    /// if any — mirrors SharedItemField's plain-string convention. Both nil
    /// means a shared/household item.
    var travelerRecordName: String?
    var petRecordName: String?

    var displaySymbol: IconRef {
        PackingIcon.iconRef(forName: name, fallback: category.symbol)
    }

    init(
        recordID: CKRecord.ID,
        name: String,
        category: PackingCategory,
        quantity: Int,
        isPacked: Bool,
        travelerRecordName: String?,
        petRecordName: String?
    ) {
        self.recordID = recordID
        self.name = name
        self.category = category
        self.quantity = quantity
        self.isPacked = isPacked
        self.travelerRecordName = travelerRecordName
        self.petRecordName = petRecordName
    }

    private enum CodingKeys: String, CodingKey {
        case recordName, zoneName, ownerName
        case name, category, quantity, isPacked, travelerRecordName, petRecordName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordID = CKRecord.ID(
            recordName: try container.decode(String.self, forKey: .recordName),
            zoneID: CKRecordZone.ID(
                zoneName: try container.decode(String.self, forKey: .zoneName),
                ownerName: try container.decode(String.self, forKey: .ownerName)
            )
        )
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(PackingCategory.self, forKey: .category)
        quantity = try container.decode(Int.self, forKey: .quantity)
        isPacked = try container.decode(Bool.self, forKey: .isPacked)
        travelerRecordName = try container.decodeIfPresent(String.self, forKey: .travelerRecordName)
        petRecordName = try container.decodeIfPresent(String.self, forKey: .petRecordName)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recordID.recordName, forKey: .recordName)
        try container.encode(recordID.zoneID.zoneName, forKey: .zoneName)
        try container.encode(recordID.zoneID.ownerName, forKey: .ownerName)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(isPacked, forKey: .isPacked)
        try container.encodeIfPresent(travelerRecordName, forKey: .travelerRecordName)
        try container.encodeIfPresent(petRecordName, forKey: .petRecordName)
    }
}
