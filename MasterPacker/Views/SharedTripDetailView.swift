import SwiftUI

/// Read/interact view for a trip shared *to* this device. Always renders
/// off TripSharingService.shared.sharedTrips (matched by id) rather than
/// a fixed snapshot, so a toggle here — or a pull-to-refresh picking up
/// the owner's latest changes — shows up immediately.
struct SharedTripDetailView: View {
    let tripID: String
    @ObservedObject private var service = TripSharingService.shared

    init(trip: RemoteTrip) {
        tripID = trip.id
    }

    /// Used when only the id is known up front — e.g. deep-linking
    /// straight into a just-accepted share, before the caller has a full
    /// RemoteTrip in hand. `trip` above resolves live from sharedTrips
    /// either way, so this works the moment refreshSharedTrips() catches up.
    init(tripID: String) {
        self.tripID = tripID
    }

    private var trip: RemoteTrip? {
        service.sharedTrips.first { $0.id == tripID }
    }

    var body: some View {
        Group {
            if let trip {
                List {
                    Section {
                        SharedTripProgressHeader(trip: trip)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    ForEach(sections(for: trip), id: \.label) { section in
                        Section(section.label) {
                            ForEach(section.categoryGroups) { group in
                                SharedCategoryHeaderRow(category: group.category)
                                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 2, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)

                                ForEach(group.items) { item in
                                    SharedItemRow(item: item)
                                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await service.syncSharedTrips()
                }
                .navigationTitle(trip.name)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            if service.isPinnedToMyTrips(trip) {
                                service.removeFromMyTrips(trip)
                            } else {
                                service.addToMyTrips(trip)
                            }
                        } label: {
                            if service.isPinnedToMyTrips(trip) {
                                Label("In My Trips", systemImage: "checkmark.circle.fill")
                            } else {
                                Label("Add to My Trips", systemImage: "plus.circle")
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Trip No Longer Available",
                    systemImage: "person.2.slash",
                    description: Text("Pull to refresh, or ask the owner to re-share.")
                )
                .navigationTitle("Shared Trip")
            }
        }
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private struct CategoryGroup: Identifiable {
        var id: String { category.rawValue }
        let category: PackingCategory
        let items: [RemoteItem]
    }

    /// Same shared/traveler/pet-then-category grouping as TripDetailView,
    /// applied to RemoteItem instead of PackingItem.
    private func sections(for trip: RemoteTrip) -> [(label: String, categoryGroups: [CategoryGroup])] {
        var result: [(String, [CategoryGroup])] = []

        func addSection(_ label: String, _ items: [RemoteItem]) {
            guard !items.isEmpty else { return }
            let grouped = Dictionary(grouping: items, by: \.category)
            let groups = grouped.keys
                .sorted { $0.rawValue < $1.rawValue }
                .map { category in
                    CategoryGroup(category: category, items: grouped[category]!.sorted { $0.name < $1.name })
                }
            result.append((label, groups))
        }

        addSection("Shared", trip.items.filter { $0.travelerRecordName == nil && $0.petRecordName == nil })
        for traveler in trip.travelers {
            addSection(traveler.name, trip.items.filter { $0.travelerRecordName == traveler.id })
        }
        for pet in trip.pets {
            addSection("\(pet.name) (pet)", trip.items.filter { $0.petRecordName == pet.id })
        }
        return result
    }
}

private struct SharedTripProgressHeader: View {
    let trip: RemoteTrip

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(trip.name)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Text("\(trip.durationInDays) day\(trip.durationInDays == 1 ? "" : "s") · \(trip.destination)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            if !trip.items.isEmpty {
                ProgressBar(progress: Double(trip.packedCount) / Double(trip.items.count))
                Text("\(trip.packedCount) of \(trip.items.count) packed")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
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

private struct SharedCategoryHeaderRow: View {
    let category: PackingCategory

    var body: some View {
        Label(category.rawValue.uppercased(), systemImage: category.symbol)
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(.secondary.opacity(0.8))
    }
}

private struct SharedItemRow: View {
    let item: RemoteItem

    var body: some View {
        Button {
            Task { await TripSharingService.shared.setRemoteItemPacked(!item.isPacked, item: item) }
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
