import Foundation
import SwiftData

@Model
final class Trip {
    // Every stored property below has a default value at the declaration
    // site (not just via `init`) — required for SwiftData's CloudKit sync,
    // which needs to be able to materialize a record without every field
    // being supplied.

    /// A stable identifier that survives app relaunches — unlike
    /// persistentModelID, which embeds a per-store-session identifier and
    /// is NOT guaranteed to stay the same for the same logical object
    /// across separate app launches (confirmed the hard way: it's what
    /// broke TripSharingService's owner-side item-sync lookup, since that
    /// key was being computed fresh on each launch and silently no
    /// longer matching what was saved the first time). Used by
    /// TripSharingService wherever a durable, launch-independent key is
    /// needed.
    var id: UUID = UUID()
    var name: String = ""
    var destination: String = ""
    var startDate: Date = Date.now
    var endDate: Date = Date.now
    var travelMethod: TravelMethod = TravelMethod.car
    var notes: String = ""

    /// Whether this trip is currently archived — hidden from My Trips,
    /// shown on the Archived page instead. Set automatically by
    /// TripArchiver once the trip is far enough in the past, or manually
    /// cleared by the user restoring it from the Archived page.
    var isArchived: Bool = false

    /// Sticky marker: true once this trip has EVER been auto-archived.
    /// TripArchiver's scan only acts on trips where this is still false —
    /// without it, restoring an old trip from the Archived page would just
    /// have it silently re-archived on the very next scan, since its end
    /// date is still just as far in the past as it ever was. Once a trip
    /// has been through the archive/restore cycle, it's the user's call
    /// from then on.
    var hasBeenAutoArchived: Bool = false

    /// Stored as raw strings because SwiftData attributes must be primitive-
    /// codable types; `activities` below bridges this to `Set<Activity>`.
    var activityRawValues: [String] = []

    // CloudKit requires every to-many relationship to be Optional (not just
    // have a default). These are kept private and exposed below as
    // non-optional computed properties so the rest of the app is unaffected.
    @Relationship(deleteRule: .cascade, inverse: \Traveler.trip)
    private var travelersStorage: [Traveler]? = []

    @Relationship(deleteRule: .cascade, inverse: \Pet.trip)
    private var petsStorage: [Pet]? = []

    @Relationship(deleteRule: .cascade, inverse: \PackingItem.trip)
    private var itemsStorage: [PackingItem]? = []

    @Relationship(deleteRule: .cascade, inverse: \Luggage.trip)
    private var luggageStorage: [Luggage]? = []

    init(
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        travelMethod: TravelMethod = .car,
        activities: Set<Activity> = [],
        notes: String = ""
    ) {
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.travelMethod = travelMethod
        self.activityRawValues = activities.map(\.rawValue)
        self.notes = notes
    }

    var activities: Set<Activity> {
        get { Set(activityRawValues.compactMap(Activity.init(rawValue:))) }
        set { activityRawValues = newValue.map(\.rawValue) }
    }

    var travelers: [Traveler] {
        get { travelersStorage ?? [] }
        set { travelersStorage = newValue }
    }

    var pets: [Pet] {
        get { petsStorage ?? [] }
        set { petsStorage = newValue }
    }

    var items: [PackingItem] {
        get { itemsStorage ?? [] }
        set { itemsStorage = newValue }
    }

    var luggage: [Luggage] {
        get { luggageStorage ?? [] }
        set { luggageStorage = newValue }
    }

    /// Trip length in whole days, inclusive of both start and end dates.
    var durationInDays: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(1, days + 1)
    }

    var packedCount: Int {
        items.filter(\.isPacked).count
    }

    var progress: Double {
        items.isEmpty ? 0 : Double(packedCount) / Double(items.count)
    }
}
