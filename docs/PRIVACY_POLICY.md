# MasterPacker Privacy Policy

**Effective date:** September 3, 2026

J Warren Group, LLC ("we," "us," or "our") built MasterPacker (the "App") to help you plan and pack for trips. This policy explains what data the App handles, how it's stored, and what choices you have. We wrote it to describe exactly what the App does — not more, not less.

## The short version

- MasterPacker doesn't have user accounts, passwords, or logins of its own. There's nothing to sign up for.
- Authentication is silent: if you're signed into iCloud on your device, the App automatically uses your Apple ID for authentication and data sync. iCloud isn't required to use the App — without it, your data just stays local to that device and doesn't sync.
- Your trips, packing lists, travelers, pets, and saved bags are stored in **your own private iCloud account** (via Apple's CloudKit), not on our servers. We don't operate a database of your content and can't see it.
- We use Firebase Analytics to understand how the App is used, in the aggregate — not to identify you personally.
- We don't collect your precise location. Ever.
- We don't sell your data, and we don't use it for advertising.

## Data we store, and where

### Authentication

There is no separate MasterPacker login, account creation, or password. If you're signed into iCloud on your device, the App automatically uses your Apple ID to authenticate and sync your data — transparently, with no login screen or additional step required. If you're not signed into iCloud, the App still works; your data simply stays local to that device rather than syncing.

### Your trips and packing data

Everything you create in the App — trips, travelers, pets, packing items, luggage, saved bags, and saved traveler/pet profiles — is stored using Apple's CloudKit, in the **private iCloud database tied to your Apple ID**. This is not a public or third-party database; it's part of your own iCloud account, the same way Apple stores your Notes or Reminders.

- Your data automatically syncs across all your own devices signed into the same Apple ID.
- We — the developers of MasterPacker — do not have access to this data. It lives in your iCloud account, governed by Apple's own iCloud terms and security, not ours.
- This data does not appear in the Files app, iCloud Drive, or on iCloud.com — CloudKit's private database isn't a visible file store, it's only accessible through the App itself.

### Trip sharing

If you choose to share a trip with another person, the App uses CloudKit's sharing feature (`CKShare`) to give that specific person access to that specific trip's data — its items, travelers, and pets. Only trips you explicitly choose to share are shared; nothing is shared automatically. The person you share with sees the shared trip's contents in their own copy of the App. Removing someone from a shared trip, or leaving one you were invited to, revokes that access.

To keep a shared trip in sync promptly, the App registers for silent (invisible) push notifications tied to that trip's data changes. These notifications carry no visible content and are used only to tell the App "something changed, go sync" — nothing is transmitted through them beyond that signal.

### Destination weather

When you set a trip's destination, the App looks up that place name (e.g., "Denver, CO") to show you a weather forecast and suggest weather-appropriate packing items. This uses:

- Apple's own geocoding (`CLGeocoder`) to turn your typed destination into approximate coordinates.
- [Open-Meteo](https://open-meteo.com), a free weather data service, which receives only those coordinates and a date range — no name, no device identifier, no account information of any kind. Open-Meteo does not require or receive an API key or user identity from us. For more information, see [Open-Meteo's Privacy Policy](https://open-meteo.com/en/privacy).

We do not request or use your device's actual location (GPS). The App has no location-permission prompt because it never asks for one — weather lookups are based entirely on the destination you type in.

### Notifications

Packing reminders (e.g., "start packing" or "you haven't finished packing") are scheduled **locally on your device**, based on your trip dates and, where relevant, forecasted weather changes for your destination. These are not sent from a server — your device schedules and delivers them itself.

### Usage analytics

We use Firebase Analytics (a Google service) to understand how people use the App in aggregate — for example, that trips are being created, that packing lists are being completed, or that a particular feature is being used — so we can improve it. This is limited to named product events (like "trip created" or "item packed") and does not include the content of your trips, packing lists, or personal data. Firebase manages its own anonymized installation and session identifiers for this purpose; we do not generate, store, or transmit any device identifier of our own. For more information, see [Firebase's Privacy Policy](https://firebase.google.com/support/privacy).

## What we don't do

- We don't require an account, email address, or password (iCloud authentication is built-in).
- We don't collect your precise location.
- We don't run ads or use advertising-tracking SDKs.
- We don't sell or share your data with data brokers or third parties for marketing.
- We don't have a server-side database of your trips or packing lists — we simply don't have access to that content.

## Deleting your data

You can delete individual trips, bags, travelers, pets, and items at any time from within the App — this removes them from your iCloud account.

Because your data lives in your own private iCloud account rather than on our servers, deleting the App from your device removes it from that device but does not, by itself, delete the copy stored in your iCloud account — the same way deleting most iCloud-connected apps doesn't delete your iCloud-stored content for that app. To remove MasterPacker's data from your iCloud account entirely, delete the relevant items within the App before removing your device, or manage the App's iCloud storage from **Settings → [your name] → iCloud → Manage Account Storage** on your iPhone.

## Children's privacy

MasterPacker is not directed at children under 13, and we do not knowingly collect personal information from children under 13.

## Security

Your trip and packing data is protected by Apple's iCloud/CloudKit security and encryption, the same infrastructure used by Apple's own first-party apps. Analytics data sent to Firebase is transmitted securely.

## Changes to this policy

If we make material changes to this policy, we'll update the effective date above and post the revised version at this same location.

## Contact us

Questions about this policy or how MasterPacker handles data? Reach us at privacy@jwarrengroup.com.

---

*This policy describes MasterPacker's data handling as implemented in the App. If you're a developer updating this document after a change to the App's data practices, review it against the current codebase before publishing — this text should always match what the App actually does, not what it's planned or assumed to do.*
