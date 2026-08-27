import SwiftUI
import SwiftData

struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @State private var isPresentingAddTrip = false
    @State private var isPresentingProfiles = false

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No trips yet",
                        systemImage: "suitcase",
                        description: Text("Add a trip to start building your packing list.")
                    )
                } else {
                    List {
                        ForEach(trips) { trip in
                            NavigationLink(value: trip) {
                                TripRow(trip: trip)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                        .onDelete(perform: deleteTrips)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("My Trips")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresentingProfiles = true
                    } label: {
                        Label("Saved Travelers", systemImage: "person.crop.circle")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAddTrip = true
                    } label: {
                        Label("Add Trip", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddTrip) {
                AddTripView()
            }
            .sheet(isPresented: $isPresentingProfiles) {
                ProfileListView()
            }
        }
    }

    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(trips[index])
        }
    }
}

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 13) {
            IconBadge(systemImage: trip.travelMethod.symbol)

            VStack(alignment: .leading, spacing: 3) {
                Text(trip.name)
                    .font(.system(.headline, design: .rounded))
                Text(trip.destination)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.85))
            }

            Spacer(minLength: 8)

            if !trip.items.isEmpty {
                ProgressRing(progress: trip.progress)
            }
        }
        .padding(14)
        .floatingCard()
    }

    private var subtitle: String {
        var parts = ["\(trip.travelers.count) traveler\(trip.travelers.count == 1 ? "" : "s")"]
        if !trip.pets.isEmpty {
            parts.append("\(trip.pets.count) pet\(trip.pets.count == 1 ? "" : "s")")
        }
        parts.append("\(trip.durationInDays) day\(trip.durationInDays == 1 ? "" : "s")")
        return parts.joined(separator: " · ")
    }
}

#Preview {
    TripListView()
        .modelContainer(
            for: [Trip.self, PackingItem.self, Traveler.self, Pet.self, TravelerProfile.self, ProfileItem.self],
            inMemory: true
        )
}
