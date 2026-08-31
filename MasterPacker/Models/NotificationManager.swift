import Foundation
import UserNotifications
import BackgroundTasks
import SwiftData

/// Schedules and manages the app's local notifications: per-trip packing
/// reminders (2 days before departure, and "still unpacked" the morning of),
/// plus a background weather-change watcher that only alerts on a
/// meaningful shift — the forecast flipping from dry to rain/snow, or a
/// high/low temperature moving more than 10°F — not a sunny-to-cloudy
/// wobble.
///
/// Everything here is a local notification (`UNUserNotificationCenter`) —
/// no APNs, no push server, no new entitlement. The one real capability
/// this adds is Background App Refresh (`BGTaskScheduler`), needed so the
/// weather watcher can run periodically without the app being open; see
/// Info.plist's `BGTaskSchedulerPermittedIdentifiers` / `UIBackgroundModes`.
@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    static let weatherRefreshTaskID = "com.jwarrengroup.masterpacker.weatherRefresh"

    /// Set when the user taps a trip notification (any of the three
    /// below) — ContentView observes this to deep-link straight into that
    /// trip's detail page rather than just opening to My Trips like a
    /// cold launch normally would. Cleared by whoever presents it. Mirrors
    /// TripSharingService.justAcceptedTripID's exact same pattern for the
    /// CloudKit-share-accept deep link.
    @Published var pendingNotificationTripID: String?

    private override init() {
        super.init()
    }

    // MARK: - Authorization

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    private func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    // MARK: - Per-trip reminders

    /// Refreshes both of this trip's scheduled local reminders — call
    /// whenever the trip's dates or packing list change (new trip, edited
    /// dates, item added/removed/toggled). Cheap and idempotent: each
    /// reminder has a stable identifier, so re-scheduling just replaces
    /// whatever was already pending.
    func scheduleTripReminders(for trip: Trip) async {
        guard await isAuthorized() else { return }
        let key = storageKey(for: trip)
        let center = UNUserNotificationCenter.current()

        let startReminderID = "trip.\(key).startReminder"
        center.removePendingNotificationRequests(withIdentifiers: [startReminderID])
        if let fireDate = date(relativeToStart: trip, offsetDays: -2, hour: 9), fireDate > .now {
            let content = UNMutableNotificationContent()
            content.title = "Trip in 2 days"
            content.body = "\(trip.name) starts in 2 days — time to start packing!"
            content.sound = .default
            content.userInfo = ["tripID": key]
            let request = UNNotificationRequest(identifier: startReminderID, content: content, trigger: calendarTrigger(for: fireDate))
            try? await center.add(request)
        }

        let unpackedID = "trip.\(key).unpackedReminder"
        center.removePendingNotificationRequests(withIdentifiers: [unpackedID])
        let unpackedCount = trip.items.filter { !$0.isPacked }.count
        if unpackedCount > 0, let fireDate = date(relativeToStart: trip, offsetDays: 0, hour: 8), fireDate > .now {
            let content = UNMutableNotificationContent()
            content.title = "\(trip.name) starts today"
            content.body = "You still have \(unpackedCount) unpacked item\(unpackedCount == 1 ? "" : "s") — check your list before you leave!"
            content.sound = .default
            content.userInfo = ["tripID": key]
            let request = UNNotificationRequest(identifier: unpackedID, content: content, trigger: calendarTrigger(for: fireDate))
            try? await center.add(request)
        }
    }

    /// Cancels all of a trip's pending reminders and clears its stored
    /// weather baseline — call when a trip is deleted.
    func cancelReminders(for trip: Trip) {
        let key = storageKey(for: trip)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "trip.\(key).startReminder",
            "trip.\(key).unpackedReminder",
            "trip.\(key).weatherAlert",
        ])
        UserDefaults.standard.removeObject(forKey: baselineDefaultsKey(key))
    }

    /// Clears just the stored weather baseline (not the reminders) — call
    /// when a trip's destination changes, so the next check compares
    /// against a fresh forecast instead of judging the new destination
    /// against the old one's.
    func resetWeatherBaseline(for trip: Trip) {
        UserDefaults.standard.removeObject(forKey: baselineDefaultsKey(storageKey(for: trip)))
    }

    /// Seeds a trip's weather baseline from a forecast the caller already
    /// fetched (AddTripView already asks WeatherService for one to feed
    /// the packing rules engine) — avoids a redundant fetch and means the
    /// very first background check has something to compare against.
    func establishWeatherBaseline(_ forecast: [DayForecast], for trip: Trip) {
        guard !forecast.isEmpty else { return }
        saveSnapshot(forecast, key: storageKey(for: trip))
    }

    private func date(relativeToStart trip: Trip, offsetDays: Int, hour: Int) -> Date? {
        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: offsetDays, to: calendar.startOfDay(for: trip.startDate)) else { return nil }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
    }

    private func calendarTrigger(for date: Date) -> UNCalendarNotificationTrigger {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    // MARK: - Background weather watcher

    func registerBackgroundTask(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.weatherRefreshTaskID, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            let workTask = Task { @MainActor in
                await self.handleWeatherRefresh(task: refreshTask, modelContainer: modelContainer)
            }
            refreshTask.expirationHandler = {
                workTask.cancel()
                refreshTask.setTaskCompleted(success: false)
            }
        }
    }

    /// Schedules the next opportunistic background check — call after
    /// handling one, and whenever the app is backgrounded, so there's
    /// always a request pending. iOS decides the actual timing; this only
    /// sets the earliest it's allowed to run.
    func scheduleNextWeatherRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.weatherRefreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleWeatherRefresh(task: BGAppRefreshTask, modelContainer: ModelContainer) async {
        scheduleNextWeatherRefresh()

        let context = modelContainer.mainContext
        let today = Calendar.current.startOfDay(for: .now)
        let trips = (try? context.fetch(FetchDescriptor<Trip>()))?.filter { $0.endDate >= today } ?? []

        await checkWeatherChanges(for: trips)
        task.setTaskCompleted(success: true)
    }

    /// Compares each upcoming trip's current forecast against its stored
    /// baseline and fires an alert only on a meaningful change: the
    /// forecast flipping from dry to rain/snow, or a high or low
    /// temperature shifting more than 10°F in either direction. A sunny
    /// day turning partly cloudy, or a small wobble, doesn't qualify.
    func checkWeatherChanges(for trips: [Trip]) async {
        for trip in trips {
            let days = min(trip.durationInDays, 16)
            let forecast = await WeatherService.shared.forecast(destination: trip.destination, startDate: trip.startDate, days: days)
            guard !forecast.isEmpty else { continue }

            let key = storageKey(for: trip)
            let previous = loadSnapshot(key: key)
            defer { saveSnapshot(forecast, key: key) }

            guard let previous, !previous.isEmpty, let change = significantChange(old: previous, new: forecast) else { continue }
            await sendWeatherAlert(trip: trip, message: change, key: key)
        }
    }

    /// WMO codes that mean some form of precipitation — rain, drizzle, or
    /// snow. Clear/cloudy/foggy are all "dry" for this purpose, matching
    /// the goal of only alerting on a real packing-relevant change.
    private static let wetCodes: Set<Int> = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99]

    private func significantChange(old: [ForecastSnapshot], new: [DayForecast]) -> String? {
        let calendar = Calendar.current
        let oldByDay = Dictionary(uniqueKeysWithValues: old.map { (calendar.startOfDay(for: $0.date), $0) })

        for day in new {
            guard let oldDay = oldByDay[calendar.startOfDay(for: day.date)] else { continue }

            let wasWet = Self.wetCodes.contains(oldDay.weatherCode)
            let isWet = Self.wetCodes.contains(day.weatherCode)
            if !wasWet && isWet {
                return "Rain or snow is now expected \(dayLabel(day.date)) — you may want to add a jacket."
            }

            let highDelta = day.highTemperature - oldDay.highTemperature
            let lowDelta = day.lowTemperature - oldDay.lowTemperature
            if abs(highDelta) > 10 || abs(lowDelta) > 10 {
                let biggerDelta = abs(highDelta) >= abs(lowDelta) ? highDelta : lowDelta
                let direction = biggerDelta > 0 ? "warmer" : "colder"
                return "Temperatures \(dayLabel(day.date)) shifted noticeably \(direction) — you may want to repack."
            }
        }
        return nil
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func sendWeatherAlert(trip: Trip, message: String, key: String) async {
        guard await isAuthorized() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Weather update: \(trip.name)"
        content.body = message
        content.sound = .default
        content.userInfo = ["tripID": key]
        // No trigger — delivers as soon as the system can, since this is
        // itself the notification (not a future reminder).
        let request = UNNotificationRequest(identifier: "trip.\(key).weatherAlert", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Baseline storage

    /// A Codable snapshot of one day's forecast, for stashing in
    /// UserDefaults between checks — DayForecast itself isn't Codable
    /// since it's a display-oriented type used across the app.
    private struct ForecastSnapshot: Codable {
        let date: Date
        let weatherCode: Int
        let highTemperature: Double
        let lowTemperature: Double
    }

    /// A stable per-trip key derived from `Trip.id` (not
    /// persistentModelID — confirmed via diagnostic logging in
    /// TripSharingService that persistentModelID embeds a per-launch
    /// store-session identifier and produces a *different* string for the
    /// same logical trip across separate app launches, silently breaking
    /// any lookup keyed off it after a relaunch).
    private func storageKey(for trip: Trip) -> String {
        trip.id.uuidString
    }

    private func baselineDefaultsKey(_ key: String) -> String {
        "weatherBaseline.\(key)"
    }

    private func loadSnapshot(key: String) -> [ForecastSnapshot]? {
        guard let data = UserDefaults.standard.data(forKey: baselineDefaultsKey(key)) else { return nil }
        return try? JSONDecoder().decode([ForecastSnapshot].self, from: data)
    }

    private func saveSnapshot(_ forecast: [DayForecast], key: String) {
        let snapshot = forecast.map {
            ForecastSnapshot(date: $0.date, weatherCode: $0.weatherCode, highTemperature: $0.highTemperature, lowTemperature: $0.lowTemperature)
        }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: baselineDefaultsKey(key))
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Without a delegate at all, iOS doesn't show an alert for a
    /// notification that arrives while the app is in the foreground —
    /// AppDelegate now sets NotificationManager.shared as the delegate
    /// (needed for didReceive below), so this opts back into the banner/
    /// sound/badge the app already relied on before that delegate existed.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    /// Fired when the user taps a notification (foreground, background, or
    /// cold launch alike). Every trip notification this class schedules
    /// carries the trip's stable id in userInfo — see scheduleTripReminders
    /// and sendWeatherAlert — so this just surfaces it for ContentView to
    /// deep-link into.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let tripID = response.notification.request.content.userInfo["tripID"] as? String else { return }
        pendingNotificationTripID = tripID
    }
}
