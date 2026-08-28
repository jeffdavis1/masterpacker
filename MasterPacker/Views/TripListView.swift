import SwiftUI
import SwiftData

struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @State private var isPresentingAddTrip = false
    @State private var isPresentingProfiles = false
    @State private var isPresentingMap = false
    @State private var isPresentingTemplates = false
    @State private var isPresentingSharedTrips = false

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
                    Menu {
                        Button {
                            isPresentingProfiles = true
                        } label: {
                            Label("Saved Travelers", systemImage: "person.crop.circle")
                        }
                        Button {
                            isPresentingTemplates = true
                        } label: {
                            Label("My Bag", systemImage: "bag")
                        }
                        Button {
                            isPresentingMap = true
                        } label: {
                            Label("Trip Map", systemImage: "map")
                        }
                        Button {
                            isPresentingSharedTrips = true
                        } label: {
                            Label("Shared With Me", systemImage: "person.2")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
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
            .sheet(isPresented: $isPresentingMap) {
                TripMapView()
            }
            .sheet(isPresented: $isPresentingProfiles) {
                ProfileListView()
            }
            .sheet(isPresented: $isPresentingTemplates) {
                TemplateListView()
            }
            .sheet(isPresented: $isPresentingSharedTrips) {
                SharedTripsListView()
            }
        }
    }

    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            NotificationManager.shared.cancelReminders(for: trips[index])
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
                Text(dateRangeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.85))
                TripWeatherStrip(trip: trip)
                    .padding(.top, 2)
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                if let daysUntilStart {
                    DaysUntilBadge(days: daysUntilStart)
                }
                if !trip.items.isEmpty {
                    ProgressRing(progress: trip.progress)
                }
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

    private var dateRangeText: String {
        let sameYear = Calendar.current.isDate(trip.startDate, equalTo: trip.endDate, toGranularity: .year)
        let start = trip.startDate.formatted(.dateTime.month(.abbreviated).day())
        let end = sameYear
            ? trip.endDate.formatted(.dateTime.month(.abbreviated).day())
            : trip.endDate.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(start) – \(end)"
    }

    /// Days until the trip starts, or nil once the trip is underway/over
    /// — a countdown stops being meaningful at that point, so the badge
    /// just doesn't show rather than displaying a stale/negative number.
    private var daysUntilStart: Int? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.startOfDay(for: trip.startDate)
        let end = calendar.startOfDay(for: trip.endDate)
        guard today <= end else { return nil }
        return max(0, calendar.dateComponents([.day], from: today, to: start).day ?? 0)
    }
}

/// A small "N days" countdown badge — deliberately distinct from
/// ProgressRing (a labeled pill vs. a bag-icon ring) so the two can't be
/// mistaken for each other on the same card.
private struct DaysUntilBadge: View {
    let days: Int

    var body: some View {
        VStack(spacing: 0) {
            Text(days == 0 ? "Today" : "\(days)")
                .font(.system(days == 0 ? .caption : .title3, design: .rounded, weight: .heavy))
            if days != 0 {
                Text(days == 1 ? "day" : "days")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .textCase(.uppercase)
            }
        }
        .foregroundStyle(AppTheme.brand)
        .frame(minWidth: 38)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(AppTheme.brand.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Small row of forecast icons for the first few days of a trip. Renders
/// nothing if the destination can't be geocoded or no forecast is
/// available yet (e.g. the trip is too far out) — no placeholder/error
/// state, it just quietly stays empty.
private struct TripWeatherStrip: View {
    let trip: Trip
    @State private var forecasts: [DayForecast] = []

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
        // Re-fetches automatically if the trip's destination or start date
        // changes — WeatherService caches internally, so re-running this
        // for unchanged values is cheap.
        .task(id: "\(trip.destination)|\(trip.startDate)") {
            forecasts = await WeatherService.shared.forecast(destination: trip.destination, startDate: trip.startDate, days: 3)
        }
    }
}

#Preview {
    TripListView()
        .modelContainer(
            for: [
                Trip.self, PackingItem.self, Traveler.self, Pet.self,
                TravelerProfile.self, PetProfile.self, ProfileItem.self, CustomCategory.self,
                PackingTemplate.self, TemplateItem.self,
            ],
            inMemory: true
        )
}
