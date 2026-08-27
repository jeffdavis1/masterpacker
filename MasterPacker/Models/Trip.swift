import Foundation
import SwiftData

@Model
final class Trip {
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var tripType: TripType

    @Relationship(deleteRule: .cascade, inverse: \PackingItem.trip)
    var items: [PackingItem] = []

    init(
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        tripType: TripType = .general
    ) {
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.tripType = tripType
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

enum TripType: String, Codable, CaseIterable, Identifiable {
    case general = "General"
    case beach = "Beach"
    case cityBreak = "City Break"
    case hiking = "Hiking / Outdoors"
    case business = "Business"
    case coldWeather = "Cold Weather"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .general: return "airplane"
        case .beach: return "beach.umbrella"
        case .cityBreak: return "building.2"
        case .hiking: return "figure.hiking"
        case .business: return "briefcase"
        case .coldWeather: return "snowflake"
        }
    }
}
