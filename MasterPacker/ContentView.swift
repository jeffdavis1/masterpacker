import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var isShowingSplash = true
    @Environment(\.scenePhase) private var scenePhase

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
        .task {
            await NotificationManager.shared.requestAuthorizationIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Background App Refresh requests are one-shot — make sure
            // there's always one pending for the weather watcher whenever
            // the app isn't in the foreground.
            if newPhase == .background {
                NotificationManager.shared.scheduleNextWeatherRefresh()
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
                PackingTemplate.self, TemplateItem.self,
            ],
            inMemory: true
        )
}
