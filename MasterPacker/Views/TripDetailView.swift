import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingAddItem = false
    @State private var isPresentingEditTrip = false
    @State private var isPresentingApplyTemplate = false
    @State private var collapsedSections: Set<String> = []
    @State private var isPresentingShareSheet = false

    /// One category's items within a traveler/pet/shared group.
    private struct CategoryGroup: Identifiable {
        var id: String { category.rawValue }
        let category: PackingCategory
        let items: [PackingItem]
    }

    /// Shared/household items first, then one group per traveler (trip
    /// order), then one group per pet — each broken down further into
    /// per-category groups so e.g. all of one traveler's electronics sit
    /// together, separate from their toiletries.
    private var sections: [(label: String, categoryGroups: [CategoryGroup], items: [PackingItem])] {
        var result: [(String, [CategoryGroup], [PackingItem])] = []

        func addSection(_ label: String, _ items: [PackingItem]) {
            guard !items.isEmpty else { return }
            result.append((label, categoryGroups(for: items), items))
        }

        addSection("Shared", trip.items.filter { $0.traveler == nil && $0.pet == nil })
        for traveler in trip.travelers {
            addSection(traveler.name, trip.items.filter { $0.traveler == traveler })
        }
        for pet in trip.pets {
            addSection("\(pet.name) (pet)", trip.items.filter { $0.pet == pet })
        }
        return result
    }

    private func categoryGroups(for items: [PackingItem]) -> [CategoryGroup] {
        let grouped = Dictionary(grouping: items, by: \.category)
        return grouped.keys
            .sorted { $0.rawValue < $1.rawValue }
            .map { category in
                CategoryGroup(category: category, items: grouped[category]!.sorted { $0.name < $1.name })
            }
    }

    /// Watched so the "still unpacked" reminder's item count stays
    /// current as items are checked off, added, or removed.
    private var unpackedCount: Int {
        trip.items.filter { !$0.isPacked }.count
    }

    var body: some View {
        List {
            Section {
                TripProgressHeader(trip: trip)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                TripForecastCard(trip: trip)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            ForEach(sections, id: \.label) { section in
                Section {
                    if !collapsedSections.contains(section.label) {
                        ForEach(section.categoryGroups) { group in
                            CategoryHeaderRow(category: group.category)
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 2, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)

                            ForEach(group.items) { item in
                                ItemRow(item: item)
                                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                            .onDelete { offsets in
                                deleteItems(group.items, at: offsets)
                            }
                        }
                    }
                } header: {
                    SectionHeaderButton(
                        label: section.label,
                        packedCount: section.items.filter(\.isPacked).count,
                        totalCount: section.items.count,
                        isCollapsed: collapsedSections.contains(section.label)
                    ) {
                        toggleSection(section.label)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle(trip.name)
        .refreshable {
            // Pulls a participant's edits (item packed state) into this
            // trip's local SwiftData copy, if it's shared — the owner had
            // no way to manually do this before, only push notifications.
            await TripSharingService.shared.syncSharedTrips()
        }
        .onChange(of: unpackedCount) { _, _ in
            Task { await NotificationManager.shared.scheduleTripReminders(for: trip) }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isPresentingEditTrip = true
                } label: {
                    Label("Edit Trip", systemImage: "pencil")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isPresentingShareSheet = true
                } label: {
                    Label("Share Trip", systemImage: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        isPresentingAddItem = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    Button {
                        isPresentingApplyTemplate = true
                    } label: {
                        Label("Apply Template", systemImage: "list.bullet.clipboard")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddItem) {
            AddItemView(trip: trip)
        }
        .sheet(isPresented: $isPresentingEditTrip) {
            EditTripView(trip: trip)
        }
        .sheet(isPresented: $isPresentingApplyTemplate) {
            ApplyTemplateView(trip: trip)
        }
        .background(CloudSharingPresenter(trip: trip, isPresented: $isPresentingShareSheet))
    }

    private func deleteItems(_ items: [PackingItem], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
        Task { await TripSharingService.shared.resyncIfShared(trip) }
    }

    private func toggleSection(_ label: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if collapsedSections.contains(label) {
                collapsedSections.remove(label)
            } else {
                collapsedSections.insert(label)
            }
        }
    }
}

/// A tappable section header showing who the group is for, its packed
/// count, and a chevron indicating expanded/collapsed state.
private struct SectionHeaderButton: View {
    let label: String
    let packedCount: Int
    let totalCount: Int
    let isCollapsed: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Text(label.uppercased())
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .tracking(0.6)
                Spacer()
                Text("\(packedCount)/\(totalCount)")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A small non-interactive label marking one category's items within a
/// traveler/pet/shared group — e.g. "ELECTRONICS" above phone charger,
/// battery pack, etc. Unlike the outer traveler group, these aren't
/// individually collapsible; they're just a visual break.
private struct CategoryHeaderRow: View {
    let category: PackingCategory

    var body: some View {
        Label(category.rawValue.uppercased(), systemImage: category.symbol)
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(.secondary.opacity(0.8))
    }
}

private struct TripProgressHeader: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(trip.name)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Text("\(trip.durationInDays) day\(trip.durationInDays == 1 ? "" : "s") · \(trip.destination)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            ProgressBar(progress: trip.progress)

            Text("\(trip.packedCount) of \(trip.items.count) packed")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(18)
        .background(AppTheme.brandGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius + 4, style: .continuous))
        .shadow(color: AppTheme.navy.opacity(0.25), radius: 16, y: 10)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

/// Horizontally-scrolling forecast for the trip's dates, shown prominently
/// right below the progress header. Renders nothing if the destination
/// can't be geocoded or no forecast is available yet — no error state,
/// it just quietly stays empty.
private struct TripForecastCard: View {
    let trip: Trip
    @State private var forecasts: [DayForecast] = []

    var body: some View {
        Group {
            if !forecasts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Forecast", systemImage: "cloud.sun.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(forecasts) { day in
                                ForecastDayColumn(day: day)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                .padding(16)
                .floatingCard()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        // Re-fetches automatically if the trip's destination or start date
        // changes (e.g. after editing the trip) — WeatherService caches
        // internally, so re-running this for unchanged values is cheap.
        .task(id: "\(trip.destination)|\(trip.startDate)") {
            forecasts = await WeatherService.shared.forecast(destination: trip.destination, startDate: trip.startDate, days: 7)
        }
    }
}

private struct ForecastDayColumn: View {
    let day: DayForecast

    var body: some View {
        VStack(spacing: 6) {
            Text(day.date, format: .dateTime.weekday(.abbreviated))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Image(systemName: day.symbolName)
                .font(.title3)
                .foregroundStyle(AppTheme.brand)
            Text("\(Int(day.highTemperature.rounded()))°")
                .font(.system(.caption, design: .rounded, weight: .bold))
            Text("\(Int(day.lowTemperature.rounded()))°")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 46)
    }
}

private struct ItemRow: View {
    @Bindable var item: PackingItem

    var body: some View {
        Button {
            item.isPacked.toggle()
            // No-ops if this item's trip isn't shared — cheap to call
            // unconditionally so a shared trip's participant sees the
            // change on their next refresh without a full re-share.
            Task { await TripSharingService.shared.syncItemPackedIfShared(item) }
        } label: {
            HStack {
                Image(systemName: item.isPacked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isPacked ? AppTheme.sage : .secondary)
                Image(systemName: item.displaySymbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(item.name)
                    .strikethrough(item.isPacked)
                    .foregroundStyle(item.isPacked ? .secondary : .primary)
                Spacer()
                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .floatingCard(radius: AppTheme.cornerRadius - 2)
    }
}
