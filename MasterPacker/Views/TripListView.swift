import SwiftUI
import SwiftData

struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @ObservedObject private var sharingService = TripSharingService.shared
    @State private var isPresentingAddTrip = false
    @State private var isPresentingProfiles = false
    @State private var isPresentingMap = false
    @State private var isPresentingTemplates = false
    @State private var isPresentingSharedTrips = false
    @State private var selectedSharedTrip: RemoteTrip?

    /// A shared trip only shows up here once the user has explicitly
    /// pinned it via "Add to My Trips" — it's still backed live by
    /// CloudKit/sharingService.sharedTrips, never copied into SwiftData.
    private var entries: [TripListEntry] {
        let owned = trips.map(TripListEntry.owned)
        let shared = sharingService.sharedTrips
            .filter { sharingService.isPinnedToMyTrips($0) }
            .map(TripListEntry.shared)
        return (owned + shared).sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No trips yet",
                        systemImage: "suitcase",
                        description: Text("Add a trip to start building your packing list.")
                    )
                } else {
                    List {
                        ForEach(entries) { entry in
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
                                    Button(role: .destructive) {
                                        sharingService.removeFromMyTrips(trip)
                                    } label: {
                                        Label("Remove from My Trips", systemImage: "minus.circle")
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

/// One row in "My Trips" — either a trip this device owns, or a shared
/// trip the user has pinned here via "Add to My Trips". The shared case
/// stays backed live by TripSharingService.sharedTrips; it's never
/// copied into a local SwiftData Trip.
private enum TripListEntry: Identifiable {
    case owned(Trip)
    case shared(RemoteTrip)

    var id: String {
        switch self {
        case .owned(let trip): return "owned-\(trip.id.uuidString)"
        case .shared(let trip): return "shared-\(trip.id)"
        }
    }

    var startDate: Date {
        switch self {
        case .owned(let trip): return trip.startDate
        case .shared(let trip): return trip.startDate
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
                Text(tripDateRangeText(from: trip.startDate, to: trip.endDate))
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
                if let daysUntilStart = tripDaysUntilStart(from: trip.startDate, to: trip.endDate) {
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
}

/// A shared trip the user has pinned into "My Trips" — same layout as
/// TripRow (dates, days-until badge, packing progress), plus a small
/// "shared" badge next to the name so it reads as someone else's trip at
/// a glance. Tapping opens SharedTripDetailView, not TripDetailView.
private struct SharedTripCard: View {
    let trip: RemoteTrip

    var body: some View {
        HStack(spacing: 13) {
            IconBadge(systemImage: trip.travelMethod.symbol)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(trip.name)
                        .font(.system(.headline, design: .rounded))
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.brand)
                }
                Text(trip.destination)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(tripDateRangeText(from: trip.startDate, to: trip.endDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(trip.travelers.count) traveler\(trip.travelers.count == 1 ? "" : "s") · \(trip.durationInDays) day\(trip.durationInDays == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.85))
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                if let daysUntilStart = tripDaysUntilStart(from: trip.startDate, to: trip.endDate) {
                    DaysUntilBadge(days: daysUntilStart)
                }
                if !trip.items.isEmpty {
                    ProgressRing(progress: Double(trip.packedCount) / Double(trip.items.count))
                }
            }

            // Owned trips get this for free from NavigationLink; this
            // card is a plain Button instead (it opens a sheet, not a
            // push), so without this it's the only trip in "My Trips"
            // missing the disclosure chevron everything else has.
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .floatingCard()
    }
}

/// Shared by TripRow and SharedTripCard here, and by TripProgressHeader
/// in TripDetailView.swift — "Mar 12 – 19" (or "Mar 30 – Apr 2, 2027"
/// across a year boundary). Not private, so it's a single canonical
/// place for this formatting rather than three ad-hoc copies of it.
func tripDateRangeText(from startDate: Date, to endDate: Date) -> String {
    let sameYear = Calendar.current.isDate(startDate, equalTo: endDate, toGranularity: .year)
    let start = startDate.formatted(.dateTime.month(.abbreviated).day())
    let end = sameYear
        ? endDate.formatted(.dateTime.month(.abbreviated).day())
        : endDate.formatted(.dateTime.month(.abbreviated).day().year())
    return "\(start) – \(end)"
}

/// Shared by TripRow and SharedTripCard. Days until the trip starts, or
/// nil once the trip is underway/over — a countdown stops being
/// meaningful at that point, so the badge just doesn't show rather than
/// displaying a stale/negative number.
private func tripDaysUntilStart(from startDate: Date, to endDate: Date) -> Int? {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let start = calendar.startOfDay(for: startDate)
    let end = calendar.startOfDay(for: endDate)
    guard today <= end else { return nil }
    return max(0, calendar.dateComponents([.day], from: today, to: start).day ?? 0)
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
