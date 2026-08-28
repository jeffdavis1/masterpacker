import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            TripListView()

            if isShowingSplash {
                SplashScreenView()
                    .transition(.opacity)
            }
        }
        // App-wide brand styling — every current and future screen/sheet
        // inherits these from the environment automatically. See
        // DesignSystem.swift for the rest of the palette.
        .tint(AppTheme.brand)
        .fontDesign(.rounded)
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.5)) {
                isShowingSplash = false
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                Trip.self, PackingItem.self, Traveler.self, Pet.self,
                TravelerProfile.self, PetProfile.self, ProfileItem.self, CustomCategory.self,
            ],
            inMemory: true
        )
}
