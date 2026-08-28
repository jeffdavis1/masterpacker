import Foundation
import CloudKit

/// Record type names and field keys for MasterPacker's hand-rolled
/// CloudKit sharing layer. Trip/Traveler/Pet/PackingItem stay on SwiftData
/// and its own private-database sync exactly as before — this is a
/// separate, parallel set of plain CKRecords built only when a trip is
/// actively shared with someone else, since SwiftData has no supported
/// CKShare integration as of this writing (verified — every real-world
/// implementation either hand-rolls CloudKit like this or migrates off
/// SwiftData to Core Data entirely).
enum SharedRecordType {
    static let trip = "SharedTrip"
    static let traveler = "SharedTraveler"
    static let pet = "SharedPet"
    static let item = "SharedItem"
}

enum SharedTripField {
    static let name = "name"
    static let destination = "destination"
    static let startDate = "startDate"
    static let endDate = "endDate"
    static let travelMethod = "travelMethod"
    static let activities = "activities"
    static let notes = "notes"
}

enum SharedTravelerField {
    static let name = "name"
    static let ageBracket = "ageBracket"
}

enum SharedPetField {
    static let name = "name"
    static let species = "species"
}

enum SharedItemField {
    static let name = "name"
    static let category = "category"
    static let quantity = "quantity"
    static let isPacked = "isPacked"
    /// Record *names* (not CKRecord.Reference fields) of the SharedTraveler/
    /// SharedPet this item belongs to, if any — plain strings so reading an
    /// item's owner back doesn't require a second fetch. Both nil means a
    /// shared/household item, same convention PackingItem itself uses.
    static let travelerRecordName = "travelerRecordName"
    static let petRecordName = "petRecordName"
}

/// Builds plain CKRecords from this app's SwiftData models. Every record
/// below (other than the trip root) sets `.parent` back to the trip
/// record — that's what makes them all part of the same CKShare hierarchy
/// once the trip's share is created.
enum SharedRecordBuilder {
    static func tripRecord(_ trip: Trip, recordID: CKRecord.ID) -> CKRecord {
        let record = CKRecord(recordType: SharedRecordType.trip, recordID: recordID)
        record[SharedTripField.name] = trip.name
        record[SharedTripField.destination] = trip.destination
        record[SharedTripField.startDate] = trip.startDate
        record[SharedTripField.endDate] = trip.endDate
        record[SharedTripField.travelMethod] = trip.travelMethod.rawValue
        record[SharedTripField.activities] = trip.activities.map(\.rawValue)
        record[SharedTripField.notes] = trip.notes
        return record
    }

    static func travelerRecord(_ traveler: Traveler, recordID: CKRecord.ID, tripRecordID: CKRecord.ID) -> CKRecord {
        let record = CKRecord(recordType: SharedRecordType.traveler, recordID: recordID)
        record[SharedTravelerField.name] = traveler.name
        record[SharedTravelerField.ageBracket] = traveler.ageBracket.rawValue
        record.parent = CKRecord.Reference(recordID: tripRecordID, action: .none)
        return record
    }

    static func petRecord(_ pet: Pet, recordID: CKRecord.ID, tripRecordID: CKRecord.ID) -> CKRecord {
        let record = CKRecord(recordType: SharedRecordType.pet, recordID: recordID)
        record[SharedPetField.name] = pet.name
        record[SharedPetField.species] = pet.species.rawValue
        record.parent = CKRecord.Reference(recordID: tripRecordID, action: .none)
        return record
    }

    static func itemRecord(
        _ item: PackingItem,
        recordID: CKRecord.ID,
        tripRecordID: CKRecord.ID,
        travelerRecordName: String?,
        petRecordName: String?
    ) -> CKRecord {
        let record = CKRecord(recordType: SharedRecordType.item, recordID: recordID)
        record[SharedItemField.name] = item.name
        record[SharedItemField.category] = item.category.rawValue
        record[SharedItemField.quantity] = item.quantity
        // CKRecord fields don't support Bool directly — stored as 0/1.
        record[SharedItemField.isPacked] = item.isPacked ? 1 : 0
        record[SharedItemField.travelerRecordName] = travelerRecordName
        record[SharedItemField.petRecordName] = petRecordName
        record.parent = CKRecord.Reference(recordID: tripRecordID, action: .none)
        return record
    }
}
