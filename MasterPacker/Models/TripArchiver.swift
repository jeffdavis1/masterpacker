import Foundation
import SwiftData

/// Auto-archives trips — owned trips and pinned shared trips alike — once
/// their end date is far enough in the past, so My Trips stays focused on
/// current/upcoming travel instead of accumulating every trip ever taken.
/// Call run(modelContext:sharingService:) once per launch/foreground, same
/// cadence as TripSharingService's own sync — cheap enough (a handful of
/// date comparisons) not to need any smarter scheduling of its own.
@MainActor
enum TripArchiver {
    /// A trip becomes eligible for auto-archiving the day *after* it ends,
    /// not the moment its end date ticks over — so a trip ending today
    /// still shows in My Trips through the rest of today. Shared by both
    /// the owned-trip scan below and TripSharingService's equivalent for
    /// pinned shared trips, so the threshold can't drift between the two.
    static func isPastArchiveThreshold(endDate: Date) -> Bool {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) else {
            return false
        }
        return cutoff <= .now
    }

    static func run(modelContext: ModelContext, sharingService: TripSharingService) {
        archiveOwnedTrips(modelContext: modelContext)
        sharingService.autoArchiveEligiblePinnedTrips()
    }

    private static func archiveOwnedTrips(modelContext: ModelContext) {
        guard let trips = try? modelContext.fetch(FetchDescriptor<Trip>()) else { return }
        var didChange = false
        for trip in trips where !trip.hasBeenAutoArchived && isPastArchiveThreshold(endDate: trip.endDate) {
            trip.isArchived = true
            trip.hasBeenAutoArchived = true
            didChange = true
        }
        if didChange {
            try? modelContext.save()
        }
    }
}
