import Foundation

/// A trip activity chip. Drives which items the rules engine adds (or never
/// adds in the first place — e.g. skip boots on a beach trip simply because
/// no activity chip that calls for boots was selected).
enum Activity: String, Codable, CaseIterable, Identifiable {
    case beach = "Beach"
    case swimming = "Swimming / Pool"
    case hiking = "Hiking / Outdoors"
    case camping = "Camping"
    case skiing = "Skiing / Snow"
    case business = "Business"
    case formalEvent = "Formal Event"
    case running = "Running / Fitness"
    case cityWalking = "City Sightseeing"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .beach: return "beach.umbrella"
        case .swimming: return "figure.pool.swim"
        case .hiking: return "figure.hiking"
        case .camping: return "tent"
        case .skiing: return "figure.skiing.downhill"
        case .business: return "briefcase"
        case .formalEvent: return "sparkles"
        case .running: return "figure.run"
        case .cityWalking: return "building.2"
        }
    }
}
