# App Store Screenshot Demo Data

**Purpose:** A repeatable "shooting script" for populating a freshly-erased simulator with clean, good-looking demo data for App Store screenshots. Matches the screenshot sequence from the "Create App Store screenshots with captions" roadmap item (My Trips, Create Trip flow, My Bags, packing progress, sharing).

**Updated:** 2026-09-03

## Prerequisite: start from a clean state

```bash
xcrun simctl list devices          # find the exact simulator name/UDID
xcrun simctl shutdown all
xcrun simctl erase "iPhone 16 Pro" # or whichever device you're shooting on
```

Simulators aren't signed into a real iCloud account by default, so this gives a genuinely empty MasterPacker — no risk of old CloudKit-synced trips reappearing (see the earlier CloudKit sync discussion this session for why a plain reinstall on a real device wouldn't achieve this).

## Travelers & pets (Travelers tab)

| Name | Type | Essentials (2-3 each, for a populated profile card) |
|---|---|---|
| Alex | Traveler | Phone charger, Passport |
| Sam | Traveler | Contact lenses, Headphones |
| Bailey | Pet (dog) | Leash, Food bowl |

## My Bags (My Bags tab) — screenshot #3, the differentiator

| Bag | Owner | Items |
|---|---|---|
| Ski Gear | Alex | Ski jacket, Ski pants, Goggles, Gloves, Base layers, Helmet |
| Gym Kit | Unowned (offered on every trip) | Running shoes, Gym shorts, Water bottle, Headphones |

Matches the shipped description copy ("Going skiing? Hitting the gym...").

## Trips

| Trip | Destination | Timing | Travelers | Activities | Bag applied |
|---|---|---|---|---|---|
| Aspen Ski Trip | Aspen, CO | ~2 weeks out, 4 days | Alex + Sam | Skiing/Snowboarding | Ski Gear |
| Maui Getaway | Maui, HI | ~2 months out, 7 days | Alex + Sam + Bailey | Beach | — |
| NYC Business Trip | New York, NY | ~1 week out, 2 days | Alex only | Business | Gym Kit |

Real, geocodable place names so weather and the Trip Map pins actually render. Spanning different date ranges keeps My Trips from looking sparse (screenshot #1).

## Screenshot-specific notes

- **#1 My Trips:** all 3 trips created, list should look active/populated.
- **#2 Create Trip flow:** stage on the Aspen trip's creation (or re-demo the flow fresh).
- **#3 My Bag:** both bags visible in the My Bags tab.
- **#4 Packing list:** use the Aspen trip. Check off **~60-70%** of items before shooting — a mid-progress bar reads better than 0% or 100%. Leave a couple of eye-catching items (jacket, goggles) unchecked.
- **#5 Sharing:** actually completing a share needs two real Apple IDs — hard to stage solo. Simplest: tap **Share Trip** on the Aspen trip and screenshot Apple's native CloudKit share sheet itself, no second participant needed.
