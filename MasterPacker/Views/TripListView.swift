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
                TripWeatherStrip(trip: trip)
                    .padding(.top, 2)
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

/// Small row of forecast icons for the first few days of a trip. Renders
/// nothing if the destination can't be geocoded or no forecast is
/// available yet (e.g. the trip is too far out) — no placeholder/error
/// state, it just quietly stays empty.
private struct TripWeatherStrip: View {
    let trip: Trip
    @State private var forecasts: [DayForecast] = []
    @State private var didLoad = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(forecasts) { day in
                VStack(spacing: 1) {
                    Text(day.date, format: .dateTime.weekday(.abbreviated))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: day.symbolName)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.brand)
                }
            }
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            forecasts = await WeatherService.shared.forecast(destination: trip.destination, startDate: trip.startDate, days: 3)
        }
    }
}

#Preview {
    TripListView()
        .modelContainer(
            for: [
                Trip.self, PackingItem.self, Traveler.self, Pet.self,
                TravelerProfile.self, ProfileItem.self, CustomCategory.self,
            ],
            inMemory: true
        )
}
