import SwiftUI
import SwiftData

struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @ObservedObject private var sharingService = TripSharingService.shared
    @State private var isPresentingAddTrip = false
    @State private var selectedSharedTrip: RemoteTrip?
    @State private var path = NavigationPath()

    /// A shared trip only shows up here once the user has explicitly
    /// pinned it via "Add to My Trips" — it's still backed live by
    /// CloudKit/sharingService.sharedTrips, never copied into SwiftData.
    /// Archived trips (owned or pinned-shared) are excluded — they live
    /// on the Archived page instead, which is the whole point of
    /// archiving: keep this list to current/upcoming travel.
    private var entries: [TripListEntry] {
        let owned = trips.filter { !$0.isArchived }.map(TripListEntry.owned)
        let shared = sharingService.sharedTrips
            .filter { sharingService.isPinnedToMyTrips($0) && !sharingService.isArchived($0) }
            .map(TripListEntry.shared)
        return (owned + shared).sorted { $0.startDate < $1.startDate }
    }

    /// Active trips grouped by the month their start date falls in,
    /// closest month first — empty months simply don't produce a
    /// section, since monthSections only ever groups entries that exist.
    private var sections: [MonthSection] {
        monthSections(for: entries, dateKeyPath: \.startDate, ascending: true)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No trips yet",
                        systemImage: "suitcase",
                        description: Text("Add a trip to start building your packing list.")
                    )
                } else {
                    List {
                        ForEach(sections) { section in
                            Section(section.title) {
                                ForEach(section.entries) { entry in
                                    switch entry {
                                    case .owned(let trip):
                                        // A plain Button + programmatic push
                                        // rather than NavigationLink(value:) —
                                        // NavigationLink auto-adds a trailing
                                        // disclosure chevron in a List, which
                                        // didn't earn its keep here (every
                                        // card is already obviously tappable).
                                        Button {
                                            path.append(trip)
                                        } label: {
                                            TripRow(trip: trip)
                                        }
                                        .buttonStyle(.plain)
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
                // The old "More" menu (Saved Travelers, My Bag, Trip Map,
                // Shared With Me, Archived, Manage Categories, Manage
                // Activities) is gone — each of those now has its own
                // tab in RootTabView, or lives under the Profile tab
                // (Trip Map included — its removal from the nav redesign
                // turned out to be a mistake, restored as the last row
                // in ProfileMenuView).
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAddTrip = true
                    } label: {
                        Label("Add Trip", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddTrip) {
                // Go straight into the new trip once it's created,
                // instead of dropping the user back on this list.
                AddTripView { trip in
                    path.append(trip)
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

/// One row in "My Trips" (or the Archived page) — either a trip this
/// device owns, or a shared trip the user has pinned here via "Add to My
/// Trips". The shared case stays backed live by TripSharingService.
/// sharedTrips; it's never copied into a local SwiftData Trip. Not
/// private — ArchivedTripsView reuses this alongside TripRow/
/// SharedTripCard below, rather than duplicating the owned/shared split.
enum TripListEntry: Identifiable {
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

    var endDate: Date {
        switch self {
        case .owned(let trip): return trip.endDate
        case .shared(let trip): return trip.endDate
        }
    }
}

struct TripRow: View {
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
struct SharedTripCard: View {
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
        }
        .padding(14)
        .floatingCard()
    }
}

/// One month's worth of trips in a sectioned list — used by both
/// TripListView (active trips, grouped by start date) and
/// ArchivedTripsView (archived trips, grouped by end date). id is a
/// locale-independent "year-month" key, purely for List/ForEach identity;
/// title is what's actually shown ("August 2026").
struct MonthSection: Identifiable {
    let id: String
    let title: String
    let entries: [TripListEntry]
}

/// Groups entries by the month/year of whichever date dateKeyPath picks
/// out, sorted `ascending` (closest month first) or not (most recent
/// month first). A month with no entries never produces a section at
/// all — there's nothing to hide, since this only ever groups the
/// entries actually passed in, never walks a fixed calendar range.
func monthSections(for entries: [TripListEntry], dateKeyPath: KeyPath<TripListEntry, Date>, ascending: Bool) -> [MonthSection] {
    struct MonthKey: Hashable {
        let year: Int
        let month: Int
    }

    let calendar = Calendar.current
    let grouped = Dictionary(grouping: entries) { entry -> MonthKey in
        let components = calendar.dateComponents([.year, .month], from: entry[keyPath: dateKeyPath])
        return MonthKey(year: components.year ?? 0, month: components.month ?? 0)
    }

    let sortedKeys = grouped.keys.sorted { lhs, rhs in
        let lhsOrder = (lhs.year, lhs.month)
        let rhsOrder = (rhs.year, rhs.month)
        return ascending ? lhsOrder < rhsOrder : lhsOrder > rhsOrder
    }

    return sortedKeys.map { key in
        let firstOfMonth = calendar.date(from: DateComponents(year: key.year, month: key.month, day: 1)) ?? .now
        let sectionEntries = (grouped[key] ?? []).sorted { $0[keyPath: dateKeyPath] < $1[keyPath: dateKeyPath] }
        return MonthSection(
            id: "\(key.year)-\(key.month)",
            title: firstOfMonth.formatted(.dateTime.month(.wide).year()),
            entries: sectionEntries
        )
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
                Trip.self, PackingItem.self, Luggage.self, Traveler.self, Pet.self,
                TravelerProfile.self, PetProfile.self, ProfileItem.self, CustomCategory.self,
                PackingTemplate.self, TemplateItem.self,
            ],
            inMemory: true
        )
}
