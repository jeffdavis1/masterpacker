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
    /// call syncSharedTrips() (or this directly) on view appear, pull-to-
    /// refresh, app foreground, and incoming push notification.
    @Published private(set) var sharedTrips: [RemoteTrip] = []

    /// RemoteTrip.id values the user has chosen to also surface in "My
    /// Trips", not just "Shared With Me" — still backed by CloudKit /
    /// sharedTrips, never duplicated into a local SwiftData Trip.
    /// Persisted so the choice survives relaunch.
    @Published private(set) var pinnedSharedTripIDs: Set<String>

    /// Set once a share is accepted (warm or cold start) to the id of the
    /// trip that was just accepted — ContentView observes this to open
    /// straight into that trip rather than leaving the user to go find it
    /// under Shared With Me themselves. Cleared by whoever presents it.
    @Published var justAcceptedTripID: String?

    /// Needed only for reconcileOwnedSharedTrips (pulling a participant's
    /// edits back into this device's own SwiftData copy, for trips this
    /// device owns) — set once at launch via configure(modelContainer:).
    private var modelContainer: ModelContainer?

    private static let pinnedDefaultsKey = "pinnedSharedTripIDs"

    private init() {
        pinnedSharedTripIDs = Set(UserDefaults.standard.stringArray(forKey: Self.pinnedDefaultsKey) ?? [])
    }

    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

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
    /// re-syncs instead — same underlying logic as resyncIfShared, which
    /// is what actually keeps a shared trip's edits flowing automatically
    /// (trip field changes, items added/deleted) without the user needing
    /// to tap "Share" again for every edit; this function tapping into
    /// the same path just means the button still works as a manual
    /// "push now" too. Either way, returns the CKShare ready for
    /// UICloudSharingController. Item packed/unpacked state syncs
    /// separately, live on every toggle (see syncItemPackedIfShared).
    func shareTrip(_ trip: Trip) async throws -> CKShare {
        let database = container.privateCloudDatabase
        let key = storageKey(for: trip.id)

        if let existingLink = loadLink(key: key) {
            let zoneID = CKRecordZone.ID(zoneName: existingLink.zoneName, ownerName: CKCurrentUserDefaultName)
            let tripRecordID = CKRecord.ID(recordName: existingLink.tripRecordName, zoneID: zoneID)
            if let share = try await fetchExistingShare(for: tripRecordID, database: database) {
                try await resyncSnapshot(trip, zoneID: zoneID, tripRecordID: tripRecordID, link: existingLink, key: key, database: database)
                await ensureZoneSubscription(zoneID: zoneID, database: database)
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
            let travelerKey = storageKey(for: traveler.id)
            let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
            recordsToSave.append(SharedRecordBuilder.travelerRecord(traveler, recordID: recordID, tripRecordID: tripRecordID))
            travelerRecordNames[travelerKey] = recordID.recordName
            travelerRecordIDByKey[travelerKey] = recordID
        }

        var petRecordIDByKey: [String: CKRecord.ID] = [:]
        for pet in trip.pets {
            let petKey = storageKey(for: pet.id)
            let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
            recordsToSave.append(SharedRecordBuilder.petRecord(pet, recordID: recordID, tripRecordID: tripRecordID))
            petRecordNames[petKey] = recordID.recordName
            petRecordIDByKey[petKey] = recordID
        }

        for item in trip.items {
            let itemKey = storageKey(for: item.id)
            let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
            let travelerRecordName = item.traveler.flatMap { travelerRecordIDByKey[storageKey(for: $0.id)] }?.recordName
            let petRecordName = item.pet.flatMap { petRecordIDByKey[storageKey(for: $0.id)] }?.recordName
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

        let saveResult = try await database.modifyRecords(saving: recordsToSave, deleting: [])

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

        await ensureZoneSubscription(zoneID: zoneID, database: database)
        AnalyticsService.tripShared()

        // Critical: modifyRecords(saving:deleting:) does NOT mutate the
        // CKShare instance we passed in — it only returns an updated copy
        // in its result dictionary. The share we constructed locally has
        // no .url yet, so handing IT to UICloudSharingController produces
        // an invite link that doesn't actually resolve to a real share
        // (this was the bug behind "tapped the link, app just opened with
        // no accept prompt, share never showed up"). Must return the
        // server-saved copy instead.
        guard let savedResult = saveResult.saveResults[share.recordID],
              let savedRecord = try? savedResult.get(),
              let savedShare = savedRecord as? CKShare
        else {
            return share
        }
        return savedShare
    }

    /// Pushes an updated snapshot to CloudKit if this trip is already
    /// shared — silently does nothing otherwise (this never starts a new
    /// share; that only happens via the explicit "Share Trip" button).
    /// Item packed state has its own live path (syncItemPackedIfShared) —
    /// call this after anything else that should reach the other side:
    /// trip field edits, items added, items deleted.
    func resyncIfShared(_ trip: Trip) async {
        let key = storageKey(for: trip.id)
        guard let link = loadLink(key: key) else { return }
        let zoneID = CKRecordZone.ID(zoneName: link.zoneName, ownerName: CKCurrentUserDefaultName)
        let tripRecordID = CKRecord.ID(recordName: link.tripRecordName, zoneID: zoneID)
        try? await resyncSnapshot(trip, zoneID: zoneID, tripRecordID: tripRecordID, link: link, key: key, database: container.privateCloudDatabase)
    }

    /// Re-shares an already-shared trip: refreshes the trip record's own
    /// fields, pushes a new record for any traveler/pet/item that doesn't
    /// have one yet (added since the last share/sync), and deletes the
    /// CKRecord for anything the old link knew about that's gone now
    /// (deleted locally since the last sync) — so participants don't keep
    /// seeing stale items that no longer exist.
    private func resyncSnapshot(
        _ trip: Trip,
        zoneID: CKRecordZone.ID,
        tripRecordID: CKRecord.ID,
        link: SharedTripLink,
        key: String,
        database: CKDatabase
    ) async throws {
        var recordsToSave: [CKRecord] = [SharedRecordBuilder.tripRecord(trip, recordID: tripRecordID)]
        var travelerRecordNames: [String: String] = [:]
        var petRecordNames: [String: String] = [:]
        var itemRecordNames: [String: String] = [:]

        var travelerRecordIDByKey: [String: CKRecord.ID] = [:]
        for traveler in trip.travelers {
            let travelerKey = storageKey(for: traveler.id)
            let recordID = link.travelerRecordNames[travelerKey].map { CKRecord.ID(recordName: $0, zoneID: zoneID) }
                ?? CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
            recordsToSave.append(SharedRecordBuilder.travelerRecord(traveler, recordID: recordID, tripRecordID: tripRecordID))
            travelerRecordNames[travelerKey] = recordID.recordName
            travelerRecordIDByKey[travelerKey] = recordID
        }

        var petRecordIDByKey: [String: CKRecord.ID] = [:]
        for pet in trip.pets {
            let petKey = storageKey(for: pet.id)
            let recordID = link.petRecordNames[petKey].map { CKRecord.ID(recordName: $0, zoneID: zoneID) }
                ?? CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
            recordsToSave.append(SharedRecordBuilder.petRecord(pet, recordID: recordID, tripRecordID: tripRecordID))
            petRecordNames[petKey] = recordID.recordName
            petRecordIDByKey[petKey] = recordID
        }

        for item in trip.items {
            let itemKey = storageKey(for: item.id)
            let recordID = link.itemRecordNames[itemKey].map { CKRecord.ID(recordName: $0, zoneID: zoneID) }
                ?? CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
            let travelerRecordName = item.traveler.flatMap { travelerRecordIDByKey[storageKey(for: $0.id)] }?.recordName
            let petRecordName = item.pet.flatMap { petRecordIDByKey[storageKey(for: $0.id)] }?.recordName
            recordsToSave.append(SharedRecordBuilder.itemRecord(
                item,
                recordID: recordID,
                tripRecordID: tripRecordID,
                travelerRecordName: travelerRecordName,
                petRecordName: petRecordName
            ))
            itemRecordNames[itemKey] = recordID.recordName
        }

        var recordIDsToDelete: [CKRecord.ID] = []
        for (oldKey, oldName) in link.travelerRecordNames where travelerRecordNames[oldKey] == nil {
            recordIDsToDelete.append(CKRecord.ID(recordName: oldName, zoneID: zoneID))
        }
        for (oldKey, oldName) in link.petRecordNames where petRecordNames[oldKey] == nil {
            recordIDsToDelete.append(CKRecord.ID(recordName: oldName, zoneID: zoneID))
        }
        for (oldKey, oldName) in link.itemRecordNames where itemRecordNames[oldKey] == nil {
            recordIDsToDelete.append(CKRecord.ID(recordName: oldName, zoneID: zoneID))
        }

        _ = try await database.modifyRecords(saving: recordsToSave, deleting: recordIDsToDelete)

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
        let tripKey = storageKey(for: trip.id)
        guard let link = loadLink(key: tripKey) else { return }
        let itemKey = storageKey(for: item.id)
        guard let recordName = link.itemRecordNames[itemKey] else { return }

        let zoneID = CKRecordZone.ID(zoneName: link.zoneName, ownerName: CKCurrentUserDefaultName)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        let database = container.privateCloudDatabase

        do {
            let record = try await database.record(for: recordID)
            record[SharedItemField.isPacked] = item.isPacked ? 1 : 0
            _ = try await database.save(record)
        } catch {
            // Not surfaced to the UI — the owner can always tap "Share"
            // again to fully catch up if a push happens to fail.
        }
    }

    // MARK: - Recipient side: accepting + reading shares

    /// Handles the system callback fired when the user accepts an
    /// incoming share invite (see AppDelegate) — accepts it with
    /// CloudKit, then refreshes the shared-trips list so it shows up.
    /// Also records which trip was just accepted (the share's root
    /// record *is* the SharedTrip record, so its recordName is exactly
    /// RemoteTrip.id) so the UI can deep-link straight into it instead of
    /// leaving the user to find it themselves under Shared With Me.
    func acceptIncomingShare(metadata: CKShare.Metadata) async {
        let shareContainer = CKContainer(identifier: metadata.containerIdentifier)
        do {
            _ = try await shareContainer.accept(metadata)
            await refreshSharedTrips()
            justAcceptedTripID = metadata.rootRecordID.recordName
            AnalyticsService.shareAccepted()
        } catch {
            // Nothing further to do — the share simply won't show up.
        }
    }

    /// Refetches every trip shared to this device. Called by
    /// syncSharedTrips(); also fine to call directly (e.g. pull-to-
    /// refresh) when only the "shared to me" side needs updating.
    func refreshSharedTrips() async {
        do {
            sharedTrips = try await fetchSharedTrips()
        } catch {
            // Leaves sharedTrips as whatever it was before — the next
            // refresh (pull-to-refresh or push) will catch up.
        }
    }

    /// The one thing to call whenever we want the freshest possible
    /// state — on an incoming push notification, and on app foreground
    /// as a reliable backstop since silent push delivery isn't always
    /// instant or guaranteed. Covers both directions: refreshes this
    /// device's view of trips shared *to* it, and pulls any participant
    /// edits on trips *this device owns* back into the local SwiftData
    /// copy (see reconcileOwnedSharedTrips).
    func syncSharedTrips() async {
        await refreshSharedTrips()
        await reconcileOwnedSharedTrips()
    }

    /// Handles an incoming silent push from one of our zone subscriptions
    /// — we don't bother inspecting which zone/record changed, since a
    /// full sync is cheap at this app's scale; just re-sync everything.
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) async {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else { return }
        await syncSharedTrips()
    }

    /// Pulls a participant's edits (currently just item packed/unpacked
    /// state) back into the SwiftData copy, for every trip this device
    /// owns and has shared. The owner's own SwiftData Trip is the "real"
    /// data the rest of the app displays — the CKRecords are a satellite
    /// copy participants read/write — so without this, a participant's
    /// checkbox toggle would only ever update that satellite copy and
    /// never actually reach the owner.
    private func reconcileOwnedSharedTrips() async {
        guard let modelContainer else { return }
        let context = modelContainer.mainContext
        guard let trips = try? context.fetch(FetchDescriptor<Trip>()) else { return }

        for trip in trips {
            guard let link = loadLink(key: storageKey(for: trip.id)) else { continue }
            await reconcileItems(for: trip, link: link)
        }
    }

    private func reconcileItems(for trip: Trip, link: SharedTripLink) async {
        let zoneID = CKRecordZone.ID(zoneName: link.zoneName, ownerName: CKCurrentUserDefaultName)
        let itemRecords: [CKRecord]
        do {
            itemRecords = try await Self.queryRecords(type: SharedRecordType.item, zoneID: zoneID, database: container.privateCloudDatabase)
        } catch {
            return
        }

        // record name -> this device's storage key for that item, so we
        // can match a fetched CKRecord back to its local PackingItem
        // without any crash-prone identifier lookup — trip.items is
        // already loaded, so a simple linear match is enough here.
        let keyByRecordName = Dictionary(uniqueKeysWithValues: link.itemRecordNames.map { ($1, $0) })

        for record in itemRecords {
            guard let itemKey = keyByRecordName[record.recordID.recordName] else { continue }
            guard let localItem = trip.items.first(where: { storageKey(for: $0.id) == itemKey }) else { continue }

            let remoteIsPacked = (record[SharedItemField.isPacked] as? Int ?? 0) != 0
            if localItem.isPacked != remoteIsPacked {
                localItem.isPacked = remoteIsPacked
            }
        }
    }

    private func fetchSharedTrips() async throws -> [RemoteTrip] {
        let database = container.sharedCloudDatabase
        let zones = try await database.allRecordZones()

        // Self-healing: re-asserting this here (rather than only at
        // accept-time) means a lapsed or never-created subscription gets
        // fixed on the next refresh automatically. One call covers every
        // shared zone — see ensureSharedDatabaseSubscription's doc comment
        // for why this can't be done per-zone like the owner's side does.
        await ensureSharedDatabaseSubscription()

        // Every zone's trip is fetched concurrently rather than one at a
        // time. This used to be a plain sequential `for zone in zones`
        // loop — with N shared trips that meant N sequential round trips
        // here, stacked on top of the 4 sequential queries per zone in
        // fetchRemoteTrip below, which is what made "My Trips" take
        // ~25s to finish loading once someone had more than a handful of
        // shared trips.
        return await withTaskGroup(of: RemoteTrip?.self) { group in
            for zone in zones {
                group.addTask {
                    try? await Self.fetchRemoteTrip(in: zone.zoneID, database: database)
                }
            }
            var trips: [RemoteTrip] = []
            for await trip in group {
                if let trip {
                    trips.append(trip)
                }
            }
            return trips
        }
    }

    /// Creates (or refreshes) a silent push subscription for a shared
    /// zone in the *owner's* private database, so a participant's edit
    /// wakes the owner. Private-database only — CloudKit rejects a
    /// per-zone CKRecordZoneSubscription in the shared database (see
    /// ensureSharedDatabaseSubscription below, which is what the
    /// participant side uses instead). Saving a subscription with an ID
    /// that already exists just updates it, so this is safe to call
    /// repeatedly rather than needing separate "have I already
    /// subscribed" bookkeeping.
    private func ensureZoneSubscription(zoneID: CKRecordZone.ID, database: CKDatabase) async {
        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: "zoneChanges.\(zoneID.zoneName)")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // silent — no banner, just wakes the app
        subscription.notificationInfo = notificationInfo
        _ = try? await database.save(subscription)
    }

    /// The participant-side equivalent of ensureZoneSubscription. Confirmed
    /// via a captured CKError that CloudKit rejects a per-zone
    /// CKRecordZoneSubscription in the shared database outright: "Subscription
    /// evaluation type not allowed in shared database" — that's the actual
    /// root cause behind owner-edits never live-pushing to a participant
    /// (the reverse direction worked because the owner's zone-scoped
    /// subscription lives in their *private* database, where it's allowed).
    /// A CKDatabaseSubscription is the supported mechanism for the shared
    /// database instead: one subscription, fires for a change in *any*
    /// zone shared to this device. handleRemoteNotification already does a
    /// full resync regardless of which zone the push names, so a single
    /// database-wide subscription is all this side needs — no per-zone
    /// loop required. Saving with an ID that already exists just updates
    /// it, so safe to call on every refresh.
    private func ensureSharedDatabaseSubscription() async {
        let subscription = CKDatabaseSubscription(subscriptionID: "sharedDatabaseChanges")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // silent — no banner, just wakes the app
        subscription.notificationInfo = notificationInfo
        _ = try? await container.sharedCloudDatabase.save(subscription)
    }

    // static + nonisolated so a batch of these can run concurrently from
    // fetchSharedTrips' TaskGroup without hopping back through the
    // MainActor for each one — neither this nor queryRecords touches any
    // of this service's own state, just the zoneID/database passed in.
    private static func fetchRemoteTrip(in zoneID: CKRecordZone.ID, database: CKDatabase) async throws -> RemoteTrip? {
        // All 4 record types live in the same zone and don't depend on
        // one another, so they're queried concurrently instead of one
        // after another — that was the other half of the ~25s "My Trips"
        // load time (4 sequential round trips per shared zone). If the
        // trip record itself turns out to be missing, the other three
        // async-lets are simply left un-awaited and get cancelled when
        // this function returns.
        async let tripRecordsTask = queryRecords(type: SharedRecordType.trip, zoneID: zoneID, database: database)
        async let travelerRecordsTask = queryRecords(type: SharedRecordType.traveler, zoneID: zoneID, database: database)
        async let petRecordsTask = queryRecords(type: SharedRecordType.pet, zoneID: zoneID, database: database)
        async let itemRecordsTask = queryRecords(type: SharedRecordType.item, zoneID: zoneID, database: database)

        guard let tripRecord = try await tripRecordsTask.first else {
            return nil
        }
        let travelerRecords = try await travelerRecordsTask
        let petRecords = try await petRecordsTask
        let itemRecords = try await itemRecordsTask

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

    private static func queryRecords(type: String, zoneID: CKRecordZone.ID, database: CKDatabase) async throws -> [CKRecord] {
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
        do {
            let record = try await database.record(for: item.recordID)
            record[SharedItemField.isPacked] = isPacked ? 1 : 0
            _ = try await database.save(record)
        } catch {
            // The optimistic in-memory update above already reflects the
            // tap; a failed push just means it'll look stale to the owner
            // until the next successful sync.
        }
    }

    // MARK: - Link storage

    /// A stable string key for UserDefaults, derived from each model's own
    /// `id: UUID` (not persistentModelID — confirmed via diagnostic
    /// logging that persistentModelID embeds a per-launch store-session
    /// identifier and produces a *different* string for the same logical
    /// object across separate app launches, silently breaking every
    /// lookup keyed off it after any relaunch).
    private func storageKey(for id: UUID) -> String {
        id.uuidString
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

    // MARK: - Unsharing

    /// Whether this trip currently has an active CloudKit share — used to
    /// decide whether deleting it needs the stronger "this will remove it
    /// from everyone you've shared it with" warning.
    func isShared(_ trip: Trip) -> Bool {
        loadLink(key: storageKey(for: trip.id)) != nil
    }

    /// Revokes this trip's share entirely: deletes its CloudKit zone,
    /// which deletes the share record and every record in it, and — per
    /// CloudKit's own semantics — removes the zone from every
    /// participant's shared-database view automatically. Call this
    /// before deleting a shared trip locally, so "delete" actually means
    /// gone for everyone, not just orphaned CloudKit data nobody can
    /// reach through the app anymore.
    func stopSharing(_ trip: Trip) async {
        let key = storageKey(for: trip.id)
        guard let link = loadLink(key: key) else { return }
        let zoneID = CKRecordZone.ID(zoneName: link.zoneName, ownerName: CKCurrentUserDefaultName)
        _ = try? await container.privateCloudDatabase.modifyRecordZones(saving: [], deleting: [zoneID])
        UserDefaults.standard.removeObject(forKey: linkDefaultsKey(key))
    }

    // MARK: - Recipient side: "Add to My Trips" + leaving a share

    func isPinnedToMyTrips(_ trip: RemoteTrip) -> Bool {
        pinnedSharedTripIDs.contains(trip.id)
    }

    /// Surfaces this shared trip in "My Trips" too, alongside owned
    /// trips — purely a local bookkeeping flag, the trip itself stays
    /// backed by CloudKit/sharedTrips, never copied into SwiftData.
    func addToMyTrips(_ trip: RemoteTrip) {
        pinnedSharedTripIDs.insert(trip.id)
        UserDefaults.standard.set(Array(pinnedSharedTripIDs), forKey: Self.pinnedDefaultsKey)
        AnalyticsService.tripAddedToMyTrips()
    }

    /// Un-pins a shared trip from "My Trips" — it stays reachable under
    /// Shared With Me, this doesn't leave the share. See leaveSharedTrip
    /// for actually leaving.
    func removeFromMyTrips(_ trip: RemoteTrip) {
        pinnedSharedTripIDs.remove(trip.id)
        UserDefaults.standard.set(Array(pinnedSharedTripIDs), forKey: Self.pinnedDefaultsKey)
    }

    /// Leaves a share entirely — deletes this device's view of the
    /// shared zone from CloudKit's shared database, the standard
    /// participant-side way to remove yourself from a share without
    /// needing the owner to do anything. Doesn't touch the owner's data
    /// or any other participant. Also un-pins it from My Trips, since a
    /// left share has nothing left to pin.
    func leaveSharedTrip(_ trip: RemoteTrip) async {
        _ = try? await container.sharedCloudDatabase.modifyRecordZones(saving: [], deleting: [trip.zoneID])
        removeFromMyTrips(trip)
        sharedTrips.removeAll { $0.id == trip.id }
        AnalyticsService.sharedTripLeft()
    }
}
