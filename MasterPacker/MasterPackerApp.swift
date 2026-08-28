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
            Trip.self, Traveler.self, Pet.self, PackingItem.self,
            TravelerProfile.self, PetProfile.self, ProfileItem.self, CustomCategory.self,
            PackingTemplate.self, TemplateItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
