import Foundation
import CloudKit
import SwiftData

/// Hand-rolled CloudKit sharing for trips — a separate, parallel sync path
/// used only once a trip is actively shared with someone else. Everything
/// else in the app keeps using SwiftData's own private-database sync,
/// completely untouched by this.
///
/// @MainActor to match SwiftData model access (Trip/Traveler/Pet/
/// PackingItem are all read here) — same reasoning as NotificationManager:
/// keeping this on the same actor as the model data avoids any risk of
/// passing a non-Sendable @Model instance across an actor boundary.
@MainActor
final class TripSharingService {
    static let shared = TripSharingService()

    private let container = CKContainer.default()
    private init() {}

    /// What's already been pushed to CloudKit for a shared trip — the
    /// zone/record names to reuse on a re-share, keyed off the trip's own
    /// SwiftData identifier so no schema change was needed to track this
    /// (same UserDefaults-snapshot pattern as NotificationManager's
    /// weather baseline).
    struct SharedTripLink: Codable {
        var zoneName: String
        var tripRecordName: String
        var travelerRecordNames: [String: String] // traveler storage key -> record name
        var petRecordNames: [String: String]
        var itemRecordNames: [String: String]
    }

    /// Creates (or reuses) this trip's CloudKit share, pushing a full
    /// snapshot of its current travelers/pets/items as plain CKRecords in
    /// a dedicated zone, and returns the CKShare ready to hand to
    /// UICloudSharingController.
    func shareTrip(_ trip: Trip) async throws -> CKShare {
        let database = container.privateCloudDatabase
        let key = storageKey(for: trip.persistentModelID)

        if let existingLink = loadLink(key: key) {
            let zoneID = CKRecordZone.ID(zoneName: existingLink.zoneName, ownerName: CKCurrentUserDefaultName)
            let tripRecordID = CKRecord.ID(recordName: existingLink.tripRecordName, zoneID: zoneID)
            if let share = try await fetchExistingShare(for: tripRecordID, database: database) {
                return share
            }
            // Falls through to create a fresh share below if the old one
            // is gone (e.g. it was previously stopped).
        }

        let zoneName = "SharedTrip-\(UUID().uuidString)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        _ = try await database.save(CKRecordZone(zoneID: zoneID))

        let tripRecordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let tripRecord = SharedRecordBuilder.tripRecord(trip, recordID: tripRecordID)

        var recordsToSave: [CKRecord] = [tripRecord]
        var travelerRecordNames: [String: String] = [:]
        var petRecordNames: [String: String] = [:]
        var itemRecordNames: [String: String] = [:]

        var travelerRecordIDByKey: [String: CKRecord.ID] = [:]
        for traveler in trip.travelers {
            let travelerKey = storageKey(for: traveler.persistentModelID)
            let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
            recordsToSave.append(SharedRecordBuilder.travelerRecord(traveler, recordID: recordID, tripRecordID: tripRecordID))
            travelerRecordNames[travelerKey] = recordID.recordName
            travelerRecordIDByKey[travelerKey] = recordID
        }

        var petRecordIDByKey: [String: CKRecord.ID] = [:]
        for pet in trip.pets {
            let petKey = storageKey(for: pet.persistentModelID)
            let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
            recordsToSave.append(SharedRecordBuilder.petRecord(pet, recordID: recordID, tripRecordID: tripRecordID))
            petRecordNames[petKey] = recordID.recordName
            petRecordIDByKey[petKey] = recordID
        }

        for item in trip.items {
            let itemKey = storageKey(for: item.persistentModelID)
            let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
            let travelerRecordName = item.traveler.flatMap { travelerRecordIDByKey[storageKey(for: $0.persistentModelID)] }?.recordName
            let petRecordName = item.pet.flatMap { petRecordIDByKey[storageKey(for: $0.persistentModelID)] }?.recordName
            recordsToSave.append(SharedRecordBuilder.itemRecord(
                item,
                recordID: recordID,
                tripRecordID: tripRecordID,
                travelerRecordName: travelerRecordName,
                petRecordName: petRecordName
            ))
            itemRecordNames[itemKey] = recordID.recordName
        }

        let share = CKShare(rootRecord: tripRecord)
        share[CKShare.SystemFieldKey.title] = trip.name
        recordsToSave.append(share)

        _ = try await database.modifyRecords(saving: recordsToSave, deleting: [])

        saveLink(
            SharedTripLink(
                zoneName: zoneName,
                tripRecordName: tripRecordID.recordName,
                travelerRecordNames: travelerRecordNames,
                petRecordNames: petRecordNames,
                itemRecordNames: itemRecordNames
            ),
            key: key
        )

        return share
    }

    private func fetchExistingShare(for tripRecordID: CKRecord.ID, database: CKDatabase) async throws -> CKShare? {
        guard let tripRecord = try? await database.record(for: tripRecordID) else { return nil }
        guard let shareReference = tripRecord.share else { return nil }
        guard let shareRecord = try? await database.record(for: shareReference.recordID) else { return nil }
        return shareRecord as? CKShare
    }

    // MARK: - Link storage

    private func storageKey(for id: PersistentIdentifier) -> String {
        (try? JSONEncoder().encode(id))?.base64EncodedString() ?? UUID().uuidString
    }

    private func linkDefaultsKey(_ key: String) -> String {
        "sharedTripLink.\(key)"
    }

    private func loadLink(key: String) -> SharedTripLink? {
        guard let data = UserDefaults.standard.data(forKey: linkDefaultsKey(key)) else { return nil }
        return try? JSONDecoder().decode(SharedTripLink.self, from: data)
    }

    private func saveLink(_ link: SharedTripLink, key: String) {
        guard let data = try? JSONEncoder().encode(link) else { return }
        UserDefaults.standard.set(data, forKey: linkDefaultsKey(key))
    }
}
