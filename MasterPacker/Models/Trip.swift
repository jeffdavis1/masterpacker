import Foundation
import SwiftData

@Model
final class Trip {
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var travelMethod: TravelMethod
    var notes: String

    /// Stored as raw strings because SwiftData attributes must be primitive-
    /// codable types; `activities` below bridges this to `Set<Activity>`.
    var activityRawValues: [String]

    @Relationship(deleteRule: .cascade, inverse: \Traveler.trip)
    var travelers: [Traveler] = []

    @Relationship(deleteRule: .cascade, inverse: \Pet.trip)
    var pets: [Pet] = []

    @Relationship(deleteRule: .cascade, inverse: \PackingItem.trip)
    var items: [PackingItem] = []

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
