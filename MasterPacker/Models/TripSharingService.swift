import Foundation
import CloudKit
import SwiftData
import Combine

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
final class TripSharingService: ObservableObject {
    static let shared = TripSharingService()

    private let container = CKContainer.default()

    /// Trips shared *to* this device by someone else, fetched from
    /// CloudKit's shared database. Populated by refreshSharedTrips() —
    /// call that (e.g. on view appear, pull-to-refresh, or right after
    /// accepting a new share) rather than expecting this to update itself;
    /// there's no live/push-driven sync yet.
    @Published private(set) var sharedTrips: [RemoteTrip] = []

    private init() {}

    // MARK: - Owner side: creating / re-syncing a share

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

    /// Creates this trip's CloudKit share on first call, pushing a full
    /// snapshot of its travelers/pets/items as plain CKRecords in a
    /// dedicated zone. On a later call for an already-shared trip, this
    /// re-syncs instead: existing records get their fields refreshed and
    /// any traveler/pet/item added since the last share is pushed as a
    /// new record — so tapping "Share" again doubles as "push my latest
    /// changes." Either way, returns the CKShare ready for
    /// UICloudSharingController.
    ///
    /// Known gap: only field values on already-shared records and newly
    /// added travelers/pets/items are synced this way — a renamed trip or
    /// deleted traveler won't (yet) be reflected until this is genuinely
    /// re-architected with proper incremental sync. Item packed/unpacked
    /// state syncs live on every toggle (see syncItemPackedIfShared),
    /// independent of this.
    func shareTrip(_ trip: Trip) async throws -> CKShare {
        let database = container.privateCloudDatabase
        let key = storageKey(for: trip.persistentModelID)

        if let existingLink = loadLink(key: key) {
            let zoneID = CKRecordZone.ID(zoneName: existingLink.zoneName, ownerName: CKCurrentUserDefaultName)
            let tripRecordID = CKRecord.ID(recordName: existingLink.tripRecordName, zoneID: zoneID)
            if let share = try await fetchExistingShare(for: tripRecordID, database: database) {
                try await resyncSnapshot(trip, zoneID: zoneID, tripRecordID: tripRecordID, link: existingLink, key: key, database: database)
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

    /// Re-shares an already-shared trip: refreshes the trip record's own
    /// fields, and pushes a new record for any traveler/pet/item that
    /// doesn't have one yet (added since the last share/sync).
    private func resyncSnapshot(
        _ trip: Trip,
        zoneID: CKRecordZone.ID,
        tripRecordID: CKRecord.ID,
        link: SharedTripLink,
        key: String,
        database: CKDatabase
    ) async throws {
        var recordsToSave: [CKRecord] = [SharedRecordBuilder.tripRecord(trip, recordID: tripRecordID)]
        var travelerRecordNames = link.travelerRecordNames
        var petRecordNames = link.petRecordNames
        var itemRecordNames = link.itemRecordNames

        var travelerRecordIDByKey: [String: CKRecord.ID] = [:]
        for traveler in trip.travelers {
            let travelerKey = storageKey(for: traveler.persistentModelID)
            let recordID: CKRecord.ID
            if let existingName = link.travelerRecordNames[travelerKey] {
                recordID = CKRecord.ID(recordName: existingName, zoneID: zoneID)
            } else {
                recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
                travelerRecordNames[travelerKey] = recordID.recordName
            }
            recordsToSave.append(SharedRecordBuilder.travelerRecord(traveler, recordID: recordID, tripRecordID: tripRecordID))
            travelerRecordIDByKey[travelerKey] = recordID
        }

        var petRecordIDByKey: [String: CKRecord.ID] = [:]
        for pet in trip.pets {
            let petKey = storageKey(for: pet.persistentModelID)
            let recordID: CKRecord.ID
            if let existingName = link.petRecordNames[petKey] {
                recordID = CKRecord.ID(recordName: existingName, zoneID: zoneID)
            } else {
                recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
                petRecordNames[petKey] = recordID.recordName
            }
            recordsToSave.append(SharedRecordBuilder.petRecord(pet, recordID: recordID, tripRecordID: tripRecordID))
            petRecordIDByKey[petKey] = recordID
        }

        for item in trip.items {
            let itemKey = storageKey(for: item.persistentModelID)
            let recordID: CKRecord.ID
            if let existingName = link.itemRecordNames[itemKey] {
                recordID = CKRecord.ID(recordName: existingName, zoneID: zoneID)
            } else {
                recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
                itemRecordNames[itemKey] = recordID.recordName
            }
            let travelerRecordName = item.traveler.flatMap { travelerRecordIDByKey[storageKey(for: $0.persistentModelID)] }?.recordName
            let petRecordName = item.pet.flatMap { petRecordIDByKey[storageKey(for: $0.persistentModelID)] }?.recordName
            recordsToSave.append(SharedRecordBuilder.itemRecord(
                item,
                recordID: recordID,
                tripRecordID: tripRecordID,
                travelerRecordName: travelerRecordName,
                petRecordName: petRecordName
            ))
        }

        _ = try await database.modifyRecords(saving: recordsToSave, deleting: [])

        saveLink(
            SharedTripLink(
                zoneName: link.zoneName,
                tripRecordName: link.tripRecordName,
                travelerRecordNames: travelerRecordNames,
                petRecordNames: petRecordNames,
                itemRecordNames: itemRecordNames
            ),
            key: key
        )
    }

    private func fetchExistingShare(for tripRecordID: CKRecord.ID, database: CKDatabase) async throws -> CKShare? {
        guard let tripRecord = try? await database.record(for: tripRecordID) else { return nil }
        guard let shareReference = tripRecord.share else { return nil }
        guard let shareRecord = try? await database.record(for: shareReference.recordID) else { return nil }
        return shareRecord as? CKShare
    }

    /// Pushes a single item's packed state to its shared CKRecord, if the
    /// item's trip is currently shared and that item already has a
    /// corresponding record. Silently does nothing otherwise (not shared,
    /// or the item was added after the last share/re-sync) — the owner
    /// can always tap "Share" again to fully catch up. Call this whenever
    /// isPacked changes on the owner's own copy, so a participant sees the
    /// change on their next refresh without needing a full re-share.
    func syncItemPackedIfShared(_ item: PackingItem) async {
        guard let trip = item.trip else { return }
        let tripKey = storageKey(for: trip.persistentModelID)
        guard let link = loadLink(key: tripKey) else { return }
        let itemKey = storageKey(for: item.persistentModelID)
        guard let recordName = link.itemRecordNames[itemKey] else { return }

        let zoneID = CKRecordZone.ID(zoneName: link.zoneName, ownerName: CKCurrentUserDefaultName)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        let database = container.privateCloudDatabase

        guard let record = try? await database.record(for: recordID) else { return }
        record[SharedItemField.isPacked] = item.isPacked ? 1 : 0
        _ = try? await database.save(record)
    }

    // MARK: - Recipient side: accepting + reading shares

    /// Handles the system callback fired when the user accepts an
    /// incoming share invite (see AppDelegate) — accepts it with
    /// CloudKit, then refreshes the shared-trips list so it shows up.
    func acceptIncomingShare(metadata: CKShare.Metadata) async {
        let shareContainer = CKContainer(identifier: metadata.containerIdentifier)
        do {
            _ = try await shareContainer.accept(metadata)
            await refreshSharedTrips()
        } catch {
            // Best-effort — if this fails, the trip simply won't appear;
            // the owner can resend the invite.
        }
    }

    /// Refetches every trip shared to this device. Call on view appear
    /// and pull-to-refresh — there's no push-driven live sync yet, so
    /// this is the only way to see a change the owner (or another
    /// participant) made.
    func refreshSharedTrips() async {
        guard let trips = try? await fetchSharedTrips() else { return }
        sharedTrips = trips
    }

    private func fetchSharedTrips() async throws -> [RemoteTrip] {
        let database = container.sharedCloudDatabase
        let zones = try await database.allRecordZones()

        var trips: [RemoteTrip] = []
        for zone in zones {
            if let trip = try? await fetchRemoteTrip(in: zone.zoneID, database: database) {
                trips.append(trip)
            }
        }
        return trips
    }

    private func fetchRemoteTrip(in zoneID: CKRecordZone.ID, database: CKDatabase) async throws -> RemoteTrip? {
        guard let tripRecord = try await queryRecords(type: SharedRecordType.trip, zoneID: zoneID, database: database).first else {
            return nil
        }
        let travelerRecords = try await queryRecords(type: SharedRecordType.traveler, zoneID: zoneID, database: database)
        let petRecords = try await queryRecords(type: SharedRecordType.pet, zoneID: zoneID, database: database)
        let itemRecords = try await queryRecords(type: SharedRecordType.item, zoneID: zoneID, database: database)

        return RemoteTrip(
            zoneID: zoneID,
            recordID: tripRecord.recordID,
            name: tripRecord[SharedTripField.name] as? String ?? "",
            destination: tripRecord[SharedTripField.destination] as? String ?? "",
            startDate: tripRecord[SharedTripField.startDate] as? Date ?? .now,
            endDate: tripRecord[SharedTripField.endDate] as? Date ?? .now,
            travelMethod: TravelMethod(rawValue: tripRecord[SharedTripField.travelMethod] as? String ?? "") ?? .car,
            activities: Set((tripRecord[SharedTripField.activities] as? [String] ?? []).compactMap(Activity.init(rawValue:))),
            notes: tripRecord[SharedTripField.notes] as? String ?? "",
            travelers: travelerRecords.map { record in
                RemoteTraveler(
                    recordID: record.recordID,
                    name: record[SharedTravelerField.name] as? String ?? "",
                    ageBracket: AgeBracket(rawValue: record[SharedTravelerField.ageBracket] as? String ?? "") ?? .adult
                )
            },
            pets: petRecords.map { record in
                RemotePet(
                    recordID: record.recordID,
                    name: record[SharedPetField.name] as? String ?? "",
                    species: PetSpecies(rawValue: record[SharedPetField.species] as? String ?? "") ?? .dog
                )
            },
            items: itemRecords.map { record in
                RemoteItem(
                    recordID: record.recordID,
                    name: record[SharedItemField.name] as? String ?? "",
                    category: PackingCategory(rawValue: record[SharedItemField.category] as? String ?? "") ?? .misc,
                    quantity: record[SharedItemField.quantity] as? Int ?? 1,
                    isPacked: (record[SharedItemField.isPacked] as? Int ?? 0) != 0,
                    travelerRecordName: record[SharedItemField.travelerRecordName] as? String,
                    petRecordName: record[SharedItemField.petRecordName] as? String
                )
            }
        )
    }

    private func queryRecords(type: String, zoneID: CKRecordZone.ID, database: CKDatabase) async throws -> [CKRecord] {
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        let (results, _) = try await database.records(matching: query, inZoneWith: zoneID)
        return results.compactMap { _, result in try? result.get() }
    }

    /// Toggles a remote item's packed state and writes it straight back
    /// to CloudKit — this is how a participant's own edits reach the
    /// owner. Updates the in-memory `sharedTrips` optimistically so the UI
    /// responds immediately, without waiting on a full refetch.
    func setRemoteItemPacked(_ isPacked: Bool, item: RemoteItem) async {
        if let tripIndex = sharedTrips.firstIndex(where: { trip in trip.items.contains { $0.id == item.id } }),
           let itemIndex = sharedTrips[tripIndex].items.firstIndex(where: { $0.id == item.id }) {
            sharedTrips[tripIndex].items[itemIndex].isPacked = isPacked
        }

        let database = container.sharedCloudDatabase
        guard let record = try? await database.record(for: item.recordID) else { return }
        record[SharedItemField.isPacked] = isPacked ? 1 : 0
        _ = try? await database.save(record)
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
