import SwiftUI
import SwiftData

@main
struct MasterPackerApp: App {
    /// Backed by CloudKit's private database — trips follow the signed-in
    /// iCloud account across the user's devices. Requires the iCloud +
    /// CloudKit capability (see MasterPacker.entitlements) to be present,
    /// or ModelContainer init below will throw and the app will refuse to
    /// launch.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Trip.self, Traveler.self, Pet.self, PackingItem.self,
            TravelerProfile.self, ProfileItem.self, CustomCategory.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
