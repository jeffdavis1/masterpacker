import SwiftUI
import SwiftData

struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @State private var isPresentingAddTrip = false

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
                        }
                        .onDelete(perform: deleteTrips)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Trips")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
            .toolbar {
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
        HStack {
            Image(systemName: trip.travelMethod.symbol)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading) {
                Text(trip.name).font(.headline)
                Text(trip.destination).font(.subheadline).foregroundStyle(.secondary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !trip.items.isEmpty {
                ProgressView(value: trip.progress)
                    .tint(AppTheme.sage)
                    .frame(width: 50)
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        var parts = ["\(trip.travelers.count) traveler\(trip.travelers.count == 1 ? "" : "s")"]
        if !trip.pets.isEmpty {
            parts.append("\(trip.pets.count) pet\(trip.pets.count == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    TripListView()
        .modelContainer(for: [Trip.self, PackingItem.self, Traveler.self, Pet.self], inMemory: true)
}
