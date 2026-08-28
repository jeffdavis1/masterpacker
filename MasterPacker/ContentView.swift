import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var isShowingSplash = true
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var sharingService = TripSharingService.shared

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
        // Deep link: opening a share invite (cold or warm start) should
        // drop the user straight into that trip, not leave them to go
        // find it under Shared With Me themselves. Reads justAcceptedTripID
        // directly rather than an event stream, so this shows correctly
        // even if the id was set before this view first appeared (e.g.
        // a cold-start accept that happened during the splash screen).
        .sheet(isPresented: Binding(
            get: { sharingService.justAcceptedTripID != nil },
            set: { isPresented in
                if !isPresented { sharingService.justAcceptedTripID = nil }
            }
        )) {
            if let tripID = sharingService.justAcceptedTripID {
                NavigationStack {
                    SharedTripDetailView(tripID: tripID)
                }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.5)) {
                isShowingSplash = false
            }
        }
        .task {
            await NotificationManager.shared.requestAuthorizationIfNeeded()
        }
        .task {
            await TripSharingService.shared.syncSharedTrips()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Background App Refresh requests are one-shot — make sure
            // there's always one pending for the weather watcher whenever
            // the app isn't in the foreground.
            if newPhase == .background {
                NotificationManager.shared.scheduleNextWeatherRefresh()
            }
            // Push-driven sync (see TripSharingService) covers most
            // cases, but silent push delivery isn't instant or
            // guaranteed — syncing again on foreground is a reliable
            // backstop for "opening the app should show the latest
            // state right away."
            if newPhase == .active {
                Task { await TripSharingService.shared.syncSharedTrips() }
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
