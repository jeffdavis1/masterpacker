import Foundation

/// Generates a starter packing list for a trip: per-traveler clothing scaled
/// to trip length and age, activity-driven gear, shared/household items, and
/// pet supplies. Deterministic, no network/LLM calls — easy to extend by
/// adding cases below.
enum PackingRulesEngine {
    struct GeneratedItem {
        let name: String
        let category: PackingCategory
        let quantity: Int
        let assignee: Assignee

        enum Assignee {
            case shared
            case traveler(Traveler)
            case pet(Pet)
        }
    }

    static func generate(for trip: Trip, weatherForecast: [DayForecast] = []) -> [GeneratedItem] {
        let days = trip.durationInDays
        var items: [GeneratedItem] = []

        for traveler in trip.travelers {
            var travelerGenerated = travelerItems(traveler: traveler, days: days, activities: trip.activities, travelMethod: trip.travelMethod)

            // Only add a weather-suggested item if its name isn't already
            // covered by an activity-based item (e.g. hiking already adds
            // "Rain jacket") — avoids literal duplicates.
            let existingNames = Set(travelerGenerated.map { $0.name.lowercased() })
            for weatherItem in weatherItems(forecast: weatherForecast, traveler: traveler) {
                if !existingNames.contains(weatherItem.name.lowercased()) {
                    travelerGenerated.append(weatherItem)
                }
            }
            items += travelerGenerated
        }

        items += sharedItems(trip: trip, days: days)

        for pet in trip.pets {
            items += petItems(pet: pet, days: days)
        }

        return items
    }

    // MARK: - Per traveler

    private static func travelerItems(
        traveler: Traveler,
        days: Int,
        activities: Set<Activity>,
        travelMethod: TravelMethod
    ) -> [GeneratedItem] {
        var items: [GeneratedItem] = []

        func add(_ name: String, _ category: PackingCategory, _ quantity: Int) {
            items.append(GeneratedItem(name: name, category: category, quantity: quantity, assignee: .traveler(traveler)))
        }

        switch traveler.ageBracket {
        case .infant:
            add("Onesies / outfits", .clothing, days + 2)
            add("Diapers", .toiletries, days * 6)
            add("Wipes (travel pack)", .toiletries, 1)
            add("Swaddle blanket", .gear, 1)
            add("Bottles & feeding supplies", .gear, 1)
            add("Pacifier", .misc, 1)
            // Infants skip general/activity/travel-method items below.
            return items

        case .toddler:
            add("Outfits", .clothing, days + 2)
            add("Diapers / pull-ups", .toiletries, days * 5)
            add("Socks", .clothing, days + 1)
            add("Pajamas", .clothing, 1)
            add("Comfort item (stuffed animal/blanket)", .misc, 1)
            add("Sippy cup", .gear, 1)

        case .child, .tween, .adult, .senior:
            add("Underwear", .clothing, days + 1)
            add("Socks", .clothing, days + 1)
            add("T-shirts / tops", .clothing, max(2, days))
            // Pants and shorts used to be one combined "Pants / shorts"
            // item — split so each is its own trackable checklist row.
            // Quantities are each roughly half the old combined total,
            // so the overall bottoms count for a given trip length is
            // unchanged, just spread across two clearer items.
            add("Pants", .clothing, max(1, days / 4 + 1))
            add("Shorts", .clothing, max(1, days / 4 + 1))
            // A week+ trip usually means pajamas actually need a change,
            // not just a single pair worn the whole time.
            add("Pajamas", .clothing, days > 6 ? 2 : 1)
            add("Toothbrush", .toiletries, 1)
        }

        if traveler.ageBracket.carriesDocuments {
            add("Passport / ID", .documents, 1)
        }
        if traveler.ageBracket != .toddler {
            add("Phone charger", .electronics, 1)
            for activity in activities {
                items += activityItems(for: activity, traveler: traveler, days: days)
            }
        }
        if travelMethod == .plane {
            add("Travel-size toiletries (TSA 3-1-1)", .toiletries, 1)
        }

        return items
    }

    private static func activityItems(for activity: Activity, traveler: Traveler, days: Int) -> [GeneratedItem] {
        func item(_ name: String, _ category: PackingCategory, _ quantity: Int) -> GeneratedItem {
            GeneratedItem(name: name, category: category, quantity: quantity, assignee: .traveler(traveler))
        }

        // Formal/business items don't apply to young children.
        let isOldEnoughForFormalWear = [.tween, .adult, .senior].contains(traveler.ageBracket)

        switch activity {
        case .beach, .swimming:
            return [
                item("Swimsuit", .clothing, 2),
                item("Sunscreen", .toiletries, 1),
                item("Sunglasses", .gear, 1),
                item("Flip-flops / sandals", .clothing, 1),
                item("Beach towel", .gear, 1),
            ]
        case .hiking:
            return [
                item("Hiking boots", .clothing, 1),
                item("Rain jacket", .clothing, 1),
                item("Backpack", .gear, 1),
                item("Reusable water bottle", .gear, 1),
            ]
        case .camping:
            return [
                item("Sleeping bag", .gear, 1),
                item("Headlamp / flashlight", .gear, 1),
            ]
        case .skiing:
            return [
                item("Snow jacket", .clothing, 1),
                item("Snow pants", .clothing, 1),
                item("Gloves", .clothing, 1),
                item("Warm hat", .clothing, 1),
                item("Thermal base layers", .clothing, 2),
                item("Ski goggles", .gear, 1),
            ]
        case .business:
            guard isOldEnoughForFormalWear else { return [] }
            return [
                item("Business attire", .clothing, days),
                item("Laptop & charger", .electronics, 1),
            ]
        case .formalEvent:
            guard isOldEnoughForFormalWear else { return [] }
            return [
                item("Formal outfit", .clothing, 1),
                item("Dress shoes", .clothing, 1),
            ]
        case .running:
            return [
                item("Workout clothes", .clothing, min(days, 4)),
                item("Running shoes", .clothing, 1),
            ]
        case .cityWalking:
            return [
                item("Comfortable walking shoes", .clothing, 1),
                item("Day bag", .gear, 1),
            ]
        }
    }

    // MARK: - Weather

    /// Extra items suggested by the destination's forecast — e.g. a rain
    /// jacket if rain is expected, or a warm layer if it'll be cold.
    /// `forecast` may be empty (destination not yet geocodable, offline,
    /// etc.) in which case this quietly returns nothing.
    private static func weatherItems(forecast: [DayForecast], traveler: Traveler) -> [GeneratedItem] {
        guard !forecast.isEmpty, traveler.ageBracket != .infant else { return [] }

        func item(_ name: String, _ category: PackingCategory, _ quantity: Int) -> GeneratedItem {
            GeneratedItem(name: name, category: category, quantity: quantity, assignee: .traveler(traveler))
        }

        let rainCodes: Set<Int> = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]
        let snowCodes: Set<Int> = [71, 73, 75, 77, 85, 86]

        let willRain = forecast.contains { rainCodes.contains($0.weatherCode) }
        let willSnow = forecast.contains { snowCodes.contains($0.weatherCode) }
        let lowestLow = forecast.map(\.lowTemperature).min() ?? 100
        let highestHigh = forecast.map(\.highTemperature).max() ?? 0

        var items: [GeneratedItem] = []
        if willRain {
            items.append(item("Rain jacket", .clothing, 1))
            items.append(item("Umbrella", .gear, 1))
        }
        if willSnow {
            items.append(item("Snow boots", .clothing, 1))
        }
        if lowestLow < 45 {
            items.append(item("Warm jacket", .clothing, 1))
            items.append(item("Gloves", .clothing, 1))
        }
        if highestHigh > 85 {
            items.append(item("Sunscreen", .toiletries, 1))
        }
        return items
    }

    // MARK: - Shared / household

    private static func sharedItems(trip: Trip, days: Int) -> [GeneratedItem] {
        var items: [GeneratedItem] = [
            GeneratedItem(name: "First aid kit", category: .gear, quantity: 1, assignee: .shared),
            GeneratedItem(name: "Travel documents / reservations", category: .documents, quantity: 1, assignee: .shared),
        ]

        let hasYoungTraveler = trip.travelers.contains {
            $0.ageBracket == .child || $0.ageBracket == .toddler || $0.ageBracket == .infant
        }
        if trip.travelMethod == .car && hasYoungTraveler {
            items.append(GeneratedItem(name: "Road trip snacks & entertainment", category: .misc, quantity: 1, assignee: .shared))
        }

        if trip.activities.contains(.camping) {
            items.append(GeneratedItem(name: "Tent", category: .gear, quantity: 1, assignee: .shared))
            items.append(GeneratedItem(name: "Camp stove", category: .gear, quantity: 1, assignee: .shared))
        }

        if days > 3 {
            items.append(GeneratedItem(name: "Laundry bag", category: .misc, quantity: 1, assignee: .shared))
        }

        return items
    }

    // MARK: - Pets

    private static func petItems(pet: Pet, days: Int) -> [GeneratedItem] {
        [
            GeneratedItem(name: "Food (enough for \(days) days)", category: .petSupplies, quantity: 1, assignee: .pet(pet)),
            GeneratedItem(name: "Food & water bowls", category: .petSupplies, quantity: 1, assignee: .pet(pet)),
            GeneratedItem(name: "Leash & collar", category: .petSupplies, quantity: 1, assignee: .pet(pet)),
            GeneratedItem(
                name: pet.species == .cat ? "Litter & travel litter box" : "Waste bags",
                category: .petSupplies,
                quantity: 1,
                assignee: .pet(pet)
            ),
            GeneratedItem(name: "Medications & vet records", category: .petSupplies, quantity: 1, assignee: .pet(pet)),
            GeneratedItem(name: "Favorite toy / bed", category: .petSupplies, quantity: 1, assignee: .pet(pet)),
        ]
    }
}
