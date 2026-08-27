import SwiftUI
import SwiftData

@main
struct MasterPackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Trip.self, PackingItem.self])
    }
}
