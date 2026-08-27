import Foundation
import SwiftData

@Model
final class Traveler {
    var name: String
    var ageBracket: AgeBracket
    var trip: Trip?

    init(name: String, ageBracket: AgeBracket, trip: Trip? = nil) {
        self.name = name
        self.ageBracket = ageBracket
        self.trip = trip
    }
}

enum AgeBracket: String, Codable, CaseIterable, Identifiable {
    case infant = "Infant (0–1)"
    case toddler = "Toddler (1–3)"
    case child = "Child (4–9)"
    case tween = "Tween/Teen (10–17)"
    case adult = "Adult (18–64)"
    case senior = "Senior (65+)"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .infant: return "figure.child.and.lock"
        case .toddler: return "figure.child"
        case .child: return "figure.child"
        case .tween: return "figure"
        case .adult: return "figure.wave"
        case .senior: return "figure.walk"
        }
    }

    /// Whether this age bracket carries their own travel documents (ID/passport).
    var carriesDocuments: Bool {
        switch self {
        case .infant, .toddler: return false
        case .child, .tween, .adult, .senior: return true
        }
    }
}
