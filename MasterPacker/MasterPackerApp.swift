import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct MasterPackerApp: App {
    // Catches two system callbacks SwiftUI's App lifecycle has no direct
    // hook for: accepting an incoming trip-share invite, and incoming
    // silent push notifications for live trip-sharing sync. See
    // AppDelegate.swift.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Backed by CloudKit's private database — trips follow the signed-in
    /// iCloud account across the user's devices. Requires the iCloud +
    /// CloudKit capability (see MasterPacker.entitlements) to be present,
    /// or ModelContainer init below will throw and the app will refuse to
    /// launch.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Trip.self, Traveler.self, Pet.self, PackingItem.self, Luggage.self,
            TravelerProfile.self, PetProfile.self, ProfileItem.self, CustomCategory.self,
            CustomActivity.self, PackingTemplate.self, TemplateItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Must run before anything reads a `.id` — see its own doc
        // comment for why duplicates can exist at all.
        Self.deduplicateStableIDs(in: sharedModelContainer)

        // Must be registered before the app finishes launching, per
        // BGTaskScheduler's requirements — this just teaches the system
        // handler what to do when it decides to run one; the actual
        // request is submitted from ContentView when the app backgrounds.
        NotificationManager.shared.registerBackgroundTask(modelContainer: sharedModelContainer)
        // Lets TripSharingService pull a participant's edits back into
        // this device's own SwiftData copy for trips it owns — see
        // reconcileOwnedSharedTrips.
        TripSharingService.shared.configure(modelContainer: sharedModelContainer)
    }

    /// One-time repair for a real SwiftData/CloudKit footgun: `var id:
    /// UUID = UUID()`'s "default value at declaration" is only evaluated
    /// per-instance for objects created *after* the property existed.
    /// When the property is added to a model that already has rows on
    /// disk (exactly what happened when Trip/Traveler/Pet/PackingItem
    /// gained `id` for the sharing-sync fix), SwiftData's lightweight
    /// migration backfills every pre-existing row using a single static
    /// default — not a fresh `UUID()` call per row — so every trip/item
    /// that existed before that migration ended up with the *same*
    /// literal id. Confirmed via a SwiftUI ForEach duplicate-ID warning
    /// naming a UUID shared by more than one Trip.
    ///
    /// Fixes it by fetching each affected type once, and reassigning a
    /// fresh UUID to every object after the first one seen with a given
    /// id. Safe to run on every launch — once ids are unique there's
    /// nothing left to fix, so this is a cheap no-op from then on.
    private static func deduplicateStableIDs(in container: ModelContainer) {
        let context = container.mainContext
        var didChange = false

        func dedupe<T: PersistentModel>(_ type: T.Type, id keyPath: ReferenceWritableKeyPath<T, UUID>) {
            guard let all = try? context.fetch(FetchDescriptor<T>()) else { return }
            var seen = Set<UUID>()
            for object in all {
                let id = object[keyPath: keyPath]
                if seen.contains(id) {
                    object[keyPath: keyPath] = UUID()
                    didChange = true
                } else {
                    seen.insert(id)
                }
            }
        }

        dedupe(Trip.self, id: \.id)
        dedupe(Traveler.self, id: \.id)
        dedupe(Pet.self, id: \.id)
        dedupe(PackingItem.self, id: \.id)

        if didChange {
            try? context.save()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
