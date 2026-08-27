import Foundation

enum TravelMethod: String, Codable, CaseIterable, Identifiable {
    case car = "Car"
    case plane = "Plane"
    case train = "Train"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .car: return "car"
        case .plane: return "airplane"
        case .train: return "tram"
        case .other: return "questionmark.circle"
        }
    }
}
