import Foundation
import CloudKit

/// Lightweight, non-SwiftData view models for a trip shared *to* this
/// device (i.e. someone else's trip, accepted via CKShare) — built
/// straight from CKRecords fetched out of CloudKit's shared database, not
/// stored locally. Deliberately separate from Trip/Traveler/Pet/
/// PackingItem so the regular SwiftData-backed trip screens stay
/// completely untouched by this.
struct RemoteTrip: Identifiable {
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
}

struct RemoteTraveler: Identifiable {
    let recordID: CKRecord.ID
    var id: String { recordID.recordName }
    var name: String
    var ageBracket: AgeBracket
}

struct RemotePet: Identifiable {
    let recordID: CKRecord.ID
    var id: String { recordID.recordName }
    var name: String
    var species: PetSpecies
}

struct RemoteItem: Identifiable {
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

    var displaySymbol: String {
        PackingIcon.symbol(forName: name, fallback: category.symbol)
    }
}
