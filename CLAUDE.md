# MasterPacker — Notes for Claude

## Privacy policy must stay in sync with the app

`docs/PRIVACY_POLICY.md` is the live privacy policy posted on the website. It describes MasterPacker's actual data practices — CloudKit private-database storage and sync, trip sharing via CKShare, destination weather lookups (CLGeocoder + Open-Meteo, no device location), local-only notifications, Firebase Analytics as named events with no custom device ID, and in-app data deletion.

**Whenever a change touches anything that document describes, update `docs/PRIVACY_POLICY.md` in the same piece of work — don't wait to be asked.** That includes (non-exhaustive):

- Adding, removing, or changing what's stored in the SwiftData/CloudKit schema, or how it syncs
- Any new third-party service, SDK, or network call (analytics, weather, ads, crash reporting, etc.)
- Changes to trip sharing / CKShare behavior, or who can see what
- Adding any form of user account, login, or authentication
- Adding location permissions or any use of device location (currently none)
- Changes to notification behavior (currently all local, no server-pushed content)
- Changes to what Firebase Analytics collects, or adding any device/user identifier
- Changes to how data is deleted or how long it's retained

If a change is genuinely ambiguous as to whether it affects the policy, err on the side of re-reading `docs/PRIVACY_POLICY.md` and flagging the discrepancy to Jeff rather than silently leaving it stale.
