import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var isShowingSplash = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var sharingService = TripSharingService.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    // Only needed to resolve a tapped notification's tripID back to a
    // real Trip for the deep link below — TripListView runs its own
    // separate @Query for the actual My Trips display.
    @Query(sort: \Trip.startDate) private var trips: [Trip]

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
        // Deep link: tapping a trip notification (2-days-out reminder,
        // day-of unpacked reminder, or a weather alert) should drop the
        // user straight into that trip, not just open to My Trips. Same
        // pattern as justAcceptedTripID above — NotificationManager sets
        // pendingNotificationTripID when the notification is tapped (see
        // its UNUserNotificationCenterDelegate conformance).
        //
        // Gated on resolvedNotificationTrip rather than just "is
        // pendingNotificationTripID non-nil" — a tripID that doesn't
        // match any trip (stale notification for a since-deleted trip,
        // bad data, etc.) used to still pop the sheet open with nothing
        // in it, a blank white sheet instead of just doing nothing.
        .sheet(isPresented: Binding(
            get: { resolvedNotificationTrip != nil },
            set: { isPresented in
                if !isPresented { notificationManager.pendingNotificationTripID = nil }
            }
        )) {
            if let trip = resolvedNotificationTrip {
                NavigationStack {
                    TripDetailView(trip: trip)
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
            // Same cadence as the sync above — catches a trip crossing
            // the archive threshold while the app wasn't running.
            TripArchiver.run(modelContext: modelContext, sharingService: sharingService)
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
                Task {
                    await TripSharingService.shared.syncSharedTrips()
                    TripArchiver.run(modelContext: modelContext, sharingService: sharingService)
                }
            }
        }
    }

    /// The trip a tapped notification's tripID actually resolves to, or
    /// nil if there isn't one (bad/stale id) — see the notification deep
    /// link sheet above for why this needs to gate presentation, not just
    /// get consulted inside it.
    private var resolvedNotificationTrip: Trip? {
        guard let tripID = notificationManager.pendingNotificationTripID else { return nil }
        return trips.first(where: { $0.id.uuidString == tripID })
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                Trip.self, PackingItem.self, Luggage.self, Traveler.self, Pet.self,
                TravelerProfile.self, PetProfile.self, ProfileItem.self, CustomCategory.self,
                PackingTemplate.self, TemplateItem.self,
            ],
            inMemory: true
        )
}
