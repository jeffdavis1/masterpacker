import SwiftUI
import SwiftData

/// Trips that have aged out of My Trips — an owned trip or pinned shared
/// trip TripArchiver auto-archived once its end date passed (or one the
/// user archived and hasn't restored). Grouped by the month/year the trip
/// ended, most recently ended first, so a trip you just got back from is
/// easy to find without scrolling through years of travel history.
///
/// Reuses TripListEntry/TripRow/SharedTripCard/monthSections from
/// TripListView rather than duplicating the owned/shared row split —
/// this is the same list, just filtered to isArchived and sorted the
/// other direction.
struct ArchivedTripsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Trip> { $0.isArchived }, sort: \Trip.endDate, order: .reverse) private var archivedTrips: [Trip]
    @ObservedObject private var sharingService = TripSharingService.shared
    @State private var selectedSharedTrip: RemoteTrip?

    private var entries: [TripListEntry] {
        let owned = archivedTrips.map(TripListEntry.owned)
        let shared = sharingService.sharedTrips
            .filter { sharingService.isPinnedToMyTrips($0) && sharingService.isArchived($0) }
            .map(TripListEntry.shared)
        return owned + shared
    }

    private var sections: [MonthSection] {
        monthSections(for: entries, dateKeyPath: \.endDate, ascending: false)
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No archived trips",
                        systemImage: "archivebox",
                        description: Text("Trips move here automatically once they're over.")
                    )
                } else {
                    List {
                        ForEach(sections) { section in
                            Section(section.title) {
                                ForEach(section.entries) { entry in
                                    switch entry {
                                    case .owned(let trip):
                                        NavigationLink(value: trip) {
                                            TripRow(trip: trip)
                                        }
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                deleteTrip(trip)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                trip.isArchived = false
                                            } label: {
                                                Label("Restore", systemImage: "arrow.uturn.backward")
                                            }
                                            .tint(AppTheme.brand)
                                        }
                                    case .shared(let trip):
                                        Button {
                                            selectedSharedTrip = trip
                                        } label: {
                                            SharedTripCard(trip: trip)
                                        }
                                        .buttonStyle(.plain)
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                        .swipeActions(edge: .trailing) {
                                            // Can't delete someone else's trip outright —
                                            // this is the same "unpin" removeFromMyTrips
                                            // already uses elsewhere, just reachable from
                                            // here too since that's where this row lives now.
                                            Button(role: .destructive) {
                                                sharingService.removeFromMyTrips(trip)
                                            } label: {
                                                Label("Remove from My Trips", systemImage: "minus.circle")
                                            }
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                sharingService.restoreFromArchive(trip)
                                            } label: {
                                                Label("Restore", systemImage: "arrow.uturn.backward")
                                            }
                                            .tint(AppTheme.brand)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("Archived")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $selectedSharedTrip) { trip in
                NavigationStack {
                    SharedTripDetailView(trip: trip)
                }
            }
        }
    }

    private func deleteTrip(_ trip: Trip) {
        NotificationManager.shared.cancelReminders(for: trip)
        modelContext.delete(trip)
    }
}

#Preview {
    ArchivedTripsView()
        .modelContainer(
            for: [
                Trip.self, PackingItem.self, Traveler.self, Pet.self,
                TravelerProfile.self, PetProfile.self, ProfileItem.self, CustomCategory.self,
                PackingTemplate.self, TemplateItem.self,
            ],
            inMemory: true
        )
}
