import Foundation
import SwiftData

/// A physical bag/suitcase a trip's items can be assigned to — e.g.
/// "Carry-on", "Checked Bag", "Personal Item", or a custom name the user
/// adds. Scoped to one trip, not shared across trips (what goes in the
/// carry-on is different every time). Deliberately called "Luggage"
/// everywhere in the UI, never "Bag" — "My Bag" already means something
/// else entirely in this app (the reusable PackingTemplate list), and
/// this is a completely unrelated, per-trip concept.
///
/// Owner-device-only for now: unlike Trip/Traveler/Pet/PackingItem, a
/// luggage assignment doesn't travel through TripSharingService's CKRecord
/// snapshot, so a participant on a shared trip won't see it — acceptable
/// since packing/luggage organization is inherently a per-device,
/// personal-use feature, not something that needs to stay in sync across
/// everyone a trip is shared with.
@Model
final class Luggage {
    var id: UUID = UUID()
    var name: String = ""
    var trip: Trip?

    // Gives PackingItem.luggage a declared inverse — CloudKit requires
    // every relationship to have one. Optional, per CloudKit's requirement
    // that all to-many relationships be Optional. Mirrors Traveler.packingItems.
    @Relationship(inverse: \PackingItem.luggage)
    var items: [PackingItem]? = []

    init(name: String, trip: Trip? = nil) {
        self.name = name
        self.trip = trip
    }

    /// The three bags almost every trip starts with. Seeded once, lazily
    /// — the first time a trip's luggage list is actually needed (see
    /// TripDetailView) — rather than at trip creation, so AddTripView
    /// stays completely untouched by this feature.
    static let defaultNames = ["Carry-on", "Checked Bag", "Personal Item"]

    /// Creates the default set for `trip` if it has no luggage at all yet
    /// — a trip with any luggage already (default or user-added) is left
    /// alone, so this is safe to call on every screen appearance without
    /// re-seeding or duplicating.
    static func ensureDefaults(for trip: Trip, in modelContext: ModelContext) {
        guard trip.luggage.isEmpty else { return }
        for name in defaultNames {
            modelContext.insert(Luggage(name: name, trip: trip))
        }
    }
}
