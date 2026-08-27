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

- ✅ **Phase 2:** SwiftData + CloudKit private database sync — trips follow
  the signed-in iCloud account across the user's devices. Requires the
  Simulator (or device) to actually be signed into an iCloud account under
  **Settings → [your name]** for sync to do anything; without that, the app
  still runs fine, it just stays local-only.
- **Phase 3 (deferred):** CloudKit sharing (`CKShare`) so a trip can be
  shared/edited with travel companions. Higher-risk/less-common API surface
  than Phase 2 (needs an `AppDelegate` hook for accepting invite links, and
  real testing needs two Apple IDs/devices bouncing an invite back and
  forth) — picking this back up after the backlog below.

### Backlog (not yet started, no particular priority order)

- Launch splash screen
- Visual polish — a real color palette / design system instead of default
  SwiftUI styling
- Weather forecast integration for the destination/dates, feeding into
  packing suggestions (e.g. rain in the forecast → add a rain jacket)
- **Traveler profiles**: a reusable person (not tied to one trip) with an
  "always pack" list (e.g. contact solution, specific medications) that
  auto-seeds every new trip they're added to. Needs a data model change —
  `Traveler` is currently trip-scoped, would need to become
  profile-scoped with per-trip instances referencing a profile
- **Pet profiles**: same idea for pets — reusable defaults (food bowl,
  water bowl, treats, waste bags, medications) that auto-populate whenever
  that pet is added to a trip
- Map view with pins for every past/future trip destination (needs
  geocoding the destination text into coordinates)
- Reusable packing templates you can save and reapply
- Widgets / Live Activities for "days until trip" and packing progress
- (more to come)
