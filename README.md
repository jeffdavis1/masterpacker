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
├── MasterPackerApp.swift        # App entry point, SwiftData + CloudKit container setup
├── ContentView.swift            # Root view — splash screen, then applies app-wide tint/font
├── DesignSystem.swift           # Shared design tokens (AppTheme) — see Design System below
├── Models/
│   ├── Trip.swift                       # Trip SwiftData model (dates, travel method, activities, notes)
│   ├── Traveler.swift                    # Traveler SwiftData model + AgeBracket enum
│   ├── Pet.swift                         # Pet SwiftData model + PetSpecies enum
│   ├── Activity.swift                    # Activity chip enum (Beach, Hiking, Business, ...)
│   ├── TravelMethod.swift                # TravelMethod enum (Car, Plane, Train, Other)
│   ├── PackingItem.swift                 # PackingItem model + PackingCategory enum + PackingIcon resolver
│   ├── PackingRulesEngine.swift          # Generates a starter checklist from trip + travelers + pets
│   ├── TravelerProfile.swift             # Reusable saved-person profile
│   ├── ProfileItem.swift                 # A profile's "always pack" item
│   ├── CustomCategory.swift              # User-defined categories, scoped to profile items
│   ├── CommonProfileItems.swift          # Curated common-item suggestions for profiles
│   ├── WeatherService.swift              # Geocoding + Open-Meteo forecast fetching/caching
│   └── DestinationSearchCompleter.swift  # MKLocalSearchCompleter wrapper for destination autocomplete
└── Views/
    ├── SplashScreenView.swift    # Brief branded splash shown on cold launch
    ├── DestinationField.swift    # Reusable destination text field + autocomplete dropdown
    ├── TripListView.swift        # List of trips, entry point for navigation
    ├── AddTripView.swift         # Form to create a trip: travelers, basics, activities, pets
    ├── EditTripView.swift        # Edit an existing trip's basics
    ├── TripDetailView.swift      # Packing checklist for one trip, grouped by traveler/pet/shared
    ├── AddItemView.swift         # Form to add a custom packing item, with assignee picker
    ├── ProfileListView.swift     # Saved traveler profiles, entry point (person icon on trip list)
    ├── NewProfileView.swift      # Create a new saved profile
    ├── ProfileDetailView.swift   # Edit a profile's always-pack list + suggestions
    └── AddProfileItemView.swift  # Add a custom item to a profile, incl. custom categories
```

## Design system

Colors, corner radii, and card styling live in `DesignSystem.swift` (the
`AppTheme` enum), pulled from the app icon — brand blue, navy, cream, and an
olive "sage" used for packed/success states instead of plain system green.

Most of this applies itself automatically, so **new screens should need
little to no extra styling code**:

- The `AccentColor` asset is set to the brand blue, so every button, link,
  toggle, and selected control uses it by default, everywhere, with no code.
- `ContentView` applies `.tint(AppTheme.brand)` and `.fontDesign(.rounded)`
  once at the root — every current and future screen, sheet, or navigation
  push inherits both automatically via the SwiftUI environment.
- Reach for `AppTheme` explicitly only when you need something the
  environment doesn't cover — e.g. `AppTheme.sage` for a "packed"/success
  color, or `.cardStyle()` for a custom card container outside of a
  List/Form.

When adding a new feature, don't hardcode colors (`.green`, `.blue`, raw hex,
etc.) — use `AppTheme` tokens, or just let the inherited tint/font handle it.

## Current features (v1)

- Create trips: name, destination (live autocomplete via MapKit — pick a
  real place, not free text), dates, travel method (car/plane/train/other)
- Select activities via chips (Beach, Hiking, Skiing, Business, Camping, ...) + free-text notes
- Edit an existing trip's name/destination/dates/travel method after creation
- Add travelers with age brackets (Infant/Toddler/Child/Tween-Teen/Adult/Senior)
  — each bracket changes what gets suggested (e.g. diapers for infants, no
  business attire for young kids)
- **Saved traveler profiles**: save a person once (name, age bracket, an
  "always pack" list) and reuse them on any future trip — pick one or more
  from a multi-select picker, or create a new one on the spot. Profiles
  support custom user-defined categories alongside the built-in ones.
  Suggested "always pack" items come from a curated common list plus items
  you've actually packed on 2+ past trips.
- Add pets (dog/cat/other) — pulls in pet-specific supplies. Like
  travelers, pets are saved profiles too — reusable, multi-select,
  with their own "always pack" list and suggestions (food/water
  bowls, leash, waste bags, crate, vet records, ...)
- Auto-generated starter packing list, scaled by trip length, travel method,
  activities, and each traveler's age bracket (e.g. a beach trip never gets
  boots suggested, because no activity chip that calls for boots was picked)
- Packing list grouped by who it's for: Shared/household, then each
  traveler, then each pet — each group's header shows a packed/total count
  and can be collapsed/expanded
- Check items off as you pack; per-trip and per-group progress
- Smarter item icons — e.g. "Hiking boots" gets a shoe icon rather than the
  generic clothing icon, resolved from the item's name
- Weather forecast: icons for the first 3 days on each trip tile, a full
  7-day forecast card prominently on the trip detail page (Open-Meteo, no
  API key — see Weather below)
- Add custom items (with category + assignee), delete trips/items
- Branded splash screen and a consistent visual design system (see below)
- All data synced across the signed-in iCloud account's devices via
  SwiftData + CloudKit (falls back to local-only if not signed into iCloud)
- **Trip map**: every trip plotted as a pin (navy for past, brand blue for
  upcoming) via MapKit — geocoded from `Trip.destination`, no stored
  coordinates or location permission needed. Tap a pin to jump to that trip.
- **Reusable packing templates**: save a named, trip-wide item list (e.g.
  "Camping Essentials") once and apply it to any trip — either at creation
  time or afterward from the trip detail page. Distinct from traveler/pet
  profiles, which are per-person/per-pet rather than trip-wide.
- **Weather-aware suggestions**: the auto-generated packing list factors in
  the destination's forecast, not just activities/age/trip length — rain
  adds a rain jacket + umbrella, snow adds snow boots, a cold low adds a
  warm jacket + gloves, a hot high adds sunscreen (skipped if an activity
  already covers the same item, e.g. hiking's own rain jacket)
- **Local notifications**: a "2 days before your trip" packing reminder, a
  morning-of reminder naming how many items are still unpacked (stays
  current as you check things off), and a background weather-change
  alert that only fires on a meaningful shift — see Notifications below.

## Weather

`WeatherService` (in `Models/`) resolves a trip's destination via
`CLGeocoder`, then fetches a forecast from Open-Meteo — free, no API key,
plain HTTPS. Deliberately not persisted to SwiftData (short-lived,
destination-derived, doesn't need to sync); results are cached in memory
per destination/date-range for the session, and expires after 3 hours so
the background weather watcher (below) can actually notice a change
instead of comparing a stale cached forecast to itself. Forecasts only
exist ~16 days out, so trips further out than that just show nothing
yet — that's expected.

## Notifications

`NotificationManager` (in `Models/`) schedules all of the app's local
notifications via `UNUserNotificationCenter` — no APNs, no push server, no
new entitlement:

- **2-days-before reminder** and a **morning-of "N items still
  unpacked" reminder**, both re-scheduled automatically whenever a trip's
  dates change or its packing list changes (item toggled/added/removed),
  so they always reflect current state.
- **Weather-change watcher**: periodically re-checks each upcoming trip's
  forecast against a stored baseline and only alerts on a meaningful
  change — a day flipping from dry to rain/snow, or a high/low
  temperature moving more than 10°F. A sunny day turning partly cloudy,
  or a small temperature wobble, doesn't trigger anything. Baselines are
  small JSON snapshots in `UserDefaults`, keyed off each trip's own
  SwiftData identifier (no schema change needed), and reset if you edit
  a trip's destination.

The weather watcher runs via `BGTaskScheduler`/`BGAppRefreshTask`, which
needed one new capability: Background App Refresh (`UIBackgroundModes:
fetch` + `BGTaskSchedulerPermittedIdentifiers` in Info.plist). Unlike
iCloud/CloudKit, this is Info.plist-only — no entitlement, no Apple
Developer portal capability — so it should be low-risk, but it's still a
new capability worth knowing about. iOS decides the actual timing of
background runs opportunistically (battery, usage patterns), so don't
expect a precise clock tick.

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

### Backlog (in progress order)

- Widgets / Live Activities for "days until trip" and packing progress —
  meaningfully bigger lift than most items here: needs a separate Widget
  Extension Xcode target with its own Info.plist and an App Group
  entitlement to share data with the main app, similar in kind (though
  probably not degree) to the iCloud capability setup that gave us trouble
- Phase 3: CloudKit sharing (`CKShare`, see Roadmap above)
- (more to come)
