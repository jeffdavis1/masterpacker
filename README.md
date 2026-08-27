# MasterPacker

An iOS app that helps you plan what to pack for a trip. Create a trip, pick a
trip type (beach, hiking, business, cold weather, ...), and MasterPacker
generates a starter packing checklist scaled to how many days you're away —
then you check items off as you pack.

## Requirements

- Xcode 15 or later
- iOS 17+ (simulator or device) — the app uses SwiftData for persistence

## Getting started

1. Clone the repo and open `MasterPacker.xcodeproj` in Xcode.
2. Select a simulator (e.g. iPhone 15) and hit Run (⌘R).

No external dependencies — this is a pure SwiftUI + SwiftData app, no
package manager setup required.

## Project structure

```
MasterPacker/
├── MasterPackerApp.swift        # App entry point, SwiftData container setup
├── ContentView.swift            # Root view
├── Models/
│   ├── Trip.swift                # Trip SwiftData model (dates, travel method, activities, notes)
│   ├── Traveler.swift             # Traveler SwiftData model + AgeBracket enum
│   ├── Pet.swift                  # Pet SwiftData model + PetSpecies enum
│   ├── Activity.swift             # Activity chip enum (Beach, Hiking, Business, ...)
│   ├── TravelMethod.swift         # TravelMethod enum (Car, Plane, Train, Other)
│   ├── PackingItem.swift          # PackingItem SwiftData model + PackingCategory enum
│   └── PackingRulesEngine.swift   # Generates a starter checklist from trip + travelers + pets
└── Views/
    ├── TripListView.swift       # List of trips, entry point for navigation
    ├── AddTripView.swift        # Form to create a trip: basics, activities, travelers, pets
    ├── TripDetailView.swift     # Packing checklist for one trip, grouped by traveler/pet/shared
    └── AddItemView.swift        # Form to add a custom packing item, with assignee picker
```

## Current features (v1)

- Create trips: name, destination, dates, travel method (car/plane/train/other)
- Select activities via chips (Beach, Hiking, Skiing, Business, Camping, ...) + free-text notes
- Add travelers with age brackets (Infant/Toddler/Child/Tween-Teen/Adult/Senior)
  — each bracket changes what gets suggested (e.g. diapers for infants, no
  business attire for young kids)
- Add pets (dog/cat/other) — pulls in pet-specific supplies
- Auto-generated starter packing list, scaled by trip length, travel method,
  activities, and each traveler's age bracket (e.g. a beach trip never gets
  boots suggested, because no activity chip that calls for boots was picked)
- Packing list grouped by who it's for: Shared/household, then each
  traveler, then each pet
- Check items off as you pack; per-trip progress bar
- Add custom items (with category + assignee), delete trips/items
- All data persisted locally on-device via SwiftData

## Roadmap

- **Phase 2:** SwiftData + CloudKit private database sync, so a trip follows
  the signed-in iCloud account across their devices
- **Phase 3:** CloudKit sharing (`CKShare`) so a trip can be shared/edited
  with travel companions — needs an iCloud container provisioned via Xcode's
  Signing & Capabilities (requires a paid Apple Developer Program account)
- Weather-aware suggestions (pull forecast for the destination/dates)
- Reusable packing templates you can save and reapply
- Widgets / Live Activities for "days until trip" and packing progress
