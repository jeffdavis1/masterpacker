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
├── MasterPackerApp.swift      # App entry point, SwiftData container setup
├── ContentView.swift          # Root view
├── Models/
│   ├── Trip.swift             # Trip SwiftData model + TripType enum
│   ├── PackingItem.swift      # PackingItem SwiftData model + PackingCategory enum
│   └── PackingTemplate.swift  # Generates a starter checklist per trip type/length
└── Views/
    ├── TripListView.swift     # List of trips, entry point for navigation
    ├── AddTripView.swift      # Form to create a new trip
    ├── TripDetailView.swift   # Packing checklist for one trip, grouped by category
    └── AddItemView.swift      # Form to add a custom packing item
```

## Current features (v1)

- Create trips with a name, destination, date range, and trip type
- Auto-generated starter packing list based on trip type and trip length
- Packing list grouped by category (Clothing, Toiletries, Electronics,
  Documents, Gear, Misc.)
- Check items off as you pack; per-trip progress bar
- Add custom items, delete trips/items
- All data persisted locally on-device via SwiftData

## Ideas for later

- iCloud sync across devices (SwiftData + CloudKit)
- Weather-aware suggestions (pull forecast for the destination/dates)
- Shareable/collaborative packing lists
- Reusable packing templates you can save and reapply
- Widgets / Live Activities for "days until trip" and packing progress
