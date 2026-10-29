import BackgroundTasks
import Foundation
import Observation
import UserNotifications

/// "Tell me when the bus is N minutes away" — implemented with local notifications, because a
/// free Apple developer account can't receive push notifications.
///
/// The notification is scheduled for (estimated arrival − lead time). Every time fresh arrivals
/// come in (every 15s while the app is open, occasionally in the background) it is rescheduled.
@MainActor
@Observable
final class AlertManager {
    nonisolated static let backgroundTaskID = "com.suyashjain.bustrack.refresh"

    struct BusAlert: Codable, Identifiable, Hashable {
        var id: String { "\(stopID)-\(routeID)" }
        let stopID: Int
        let stopName: String
        let routeID: Int
        let routeName: String
        let leadMinutes: Int
        /// The bus we're tracking; if it disappears we follow the route's next bus instead.
        var vehicleID: Int?
        var arrivalDate: Date
    }

    private static let storageKey = "busAlerts"
    private let center = UNUserNotificationCenter.current()

    private(set) var alerts: [BusAlert] = []
    private(set) var permissionDenied = false

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([BusAlert].self, from: data) {
            alerts = saved.filter { $0.arrivalDate > .now.addingTimeInterval(-120) }
        }
    }

    func alert(stopID: Int, routeID: Int) -> BusAlert? {
        alerts.first { $0.stopID == stopID && $0.routeID == routeID }
    }

    func setAlert(for arrival: Arrival, at stop: Stop, leadMinutes: Int) async {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        permissionDenied = !granted
        guard granted else { return }

        let alert = BusAlert(
            stopID: stop.id, stopName: stop.name, routeID: arrival.routeID, routeName: arrival.routeName,
            leadMinutes: leadMinutes, vehicleID: arrival.vehicleID, arrivalDate: arrival.date
        )
        alerts.removeAll { $0.id == alert.id }
        alerts.append(alert)
        await schedule(alert)
        save()
        Self.scheduleBackgroundRefresh()
    }

    func cancel(_ alert: BusAlert) {
        center.removePendingNotificationRequests(withIdentifiers: [alert.id])
        alerts.removeAll { $0.id == alert.id }
        save()
    }

    /// Re-aim every alert at the latest estimate for its bus.
    func update(using model: AppModel) async {
        guard !alerts.isEmpty else { return }
        var changed = false
        for (index, alert) in alerts.enumerated() {
            guard let stop = model.stop(id: alert.stopID) else { continue }
            let candidates = model.arrivals(at: stop).filter { $0.routeID == alert.routeID }
            let match = candidates.first { $0.vehicleID == alert.vehicleID && $0.isLive }
                ?? candidates.first { $0.isLive && $0.date > .now }
            guard let match, abs(match.date.timeIntervalSince(alert.arrivalDate)) >= 20
                    || match.vehicleID != alert.vehicleID else { continue }
            alerts[index].arrivalDate = match.date
            alerts[index].vehicleID = match.vehicleID
            await schedule(alerts[index])
            changed = true
        }
        let before = alerts.count
        alerts.removeAll { $0.arrivalDate < .now.addingTimeInterval(-120) }
        if changed || alerts.count != before { save() }
    }

    private func schedule(_ alert: BusAlert) async {
        let content = UNMutableNotificationContent()
        content.title = "\(alert.routeName) is \(alert.leadMinutes) min away"
        content.body = "Arriving at \(alert.stopName) around \(alert.arrivalDate.formatted(date: .omitted, time: .shortened))."
        content.sound = .default

        let fireDate = alert.arrivalDate.addingTimeInterval(TimeInterval(-alert.leadMinutes * 60))
        let delay = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        // Same identifier replaces the previously scheduled notification for this alert.
        try? await center.add(UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger))
    }

    private func save() {
        if let data = try? JSONEncoder().encode(alerts) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// Ask iOS to wake us in the background so alerts can track the bus. iOS decides when (if ever).
    nonisolated static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskID)
        request.earliestBeginDate = .now.addingTimeInterval(60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

/// Shows alert banners even while the app is in the foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
