import SwiftUI

/// Entry point for trips shared *to* this device by someone else — its
/// own tab in RootTabView. Reads from TripSharingService.shared.
/// sharedTrips; refreshing (on appear + pull-to-refresh) is the only way
/// to see the owner's latest changes, since there's no push-driven live
/// sync yet.
struct SharedTripsListView: View {
    @ObservedObject private var service = TripSharingService.shared
    @State private var selectedTrip: RemoteTrip?

    var body: some View {
        NavigationStack {
            Group {
                if service.sharedTrips.isEmpty {
                    ContentUnavailableView(
                        "No shared trips",
                        systemImage: "person.2",
                        description: Text("Trips someone shares with you will show up here once you accept the invite link.")
                    )
                } else {
                    List {
                        ForEach(service.sharedTrips) { trip in
                            Button {
                                selectedTrip = trip
                            } label: {
                                SharedTripRow(trip: trip, isPinned: service.isPinnedToMyTrips(trip))
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await service.leaveSharedTrip(trip) }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                if service.isPinnedToMyTrips(trip) {
                                    Button {
                                        service.removeFromMyTrips(trip)
                                    } label: {
                                        Label("Remove from My Trips", systemImage: "minus.circle")
                                    }
                                    .tint(AppTheme.brand)
                                } else {
                                    Button {
                                        service.addToMyTrips(trip)
                                    } label: {
                                        Label("Add to My Trips", systemImage: "plus.circle")
                                    }
                                    .tint(AppTheme.brand)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await service.syncSharedTrips()
                    }
                }
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("Shared With Me")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedTrip) { trip in
                NavigationStack {
                    SharedTripDetailView(trip: trip)
                }
            }
            .task {
                await service.syncSharedTrips()
            }
        }
    }
}

private struct SharedTripRow: View {
    let trip: RemoteTrip
    var isPinned: Bool = false

    var body: some View {
        HStack(spacing: 13) {
            IconBadge(systemImage: trip.travelMethod.symbol)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(trip.name)
                        .font(.system(.headline, design: .rounded))
                    if isPinned {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.sage)
                    }
                }
                Text(trip.destination)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.85))
            }

            Spacer(minLength: 8)

            if !trip.items.isEmpty {
                ProgressRing(progress: Double(trip.packedCount) / Double(trip.items.count))
            }
        }
        .padding(14)
        .floatingCard()
    }

    private var subtitle: String {
        "\(trip.travelers.count) traveler\(trip.travelers.count == 1 ? "" : "s") · \(trip.durationInDays) day\(trip.durationInDays == 1 ? "" : "s")"
    }
}

#Preview {
    SharedTripsListView()
}
