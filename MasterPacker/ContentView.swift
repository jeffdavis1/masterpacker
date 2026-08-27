import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TripListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Trip.self, PackingItem.self, Traveler.self, Pet.self], inMemory: true)
}
