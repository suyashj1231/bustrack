import Foundation

/// The Anteater Express lines that loop out of University Center (north: A, N; south: E, H, M).
/// Everything else in the feed (e.g. "Emergency Management") is hidden app-wide.
enum TrackedLines {
    static let names: Set<String> = ["A Line", "E Line", "H Line", "M Line", "N Line"]
}

extension Route {
    var isTrackedLine: Bool { TrackedLines.names.contains(name) }
}

/// The widget idles until you tap ↻, then tracks live for a while before going idle again.
enum TrackingSession {
    static let duration: TimeInterval = 30 * 60
    /// How often to refetch while tracking; iOS won't reliably reload a widget faster than this.
    static let reloadInterval: TimeInterval = 5 * 60

    struct Plan: Equatable {
        /// One timeline entry per minute so the countdown ticks between fetches.
        let entryDates: [Date]
        /// When to fetch again, or nil to stay idle until the next tap.
        let reloadAt: Date?
    }

    static func plan(now: Date, trackingUntil: Date?) -> Plan {
        // A little slack so a reload that fires a few seconds early still ends the session.
        guard let trackingUntil, trackingUntil.timeIntervalSince(now) > 30 else {
            return Plan(entryDates: [now], reloadAt: nil)
        }
        let reloadAt = min(now.addingTimeInterval(reloadInterval), trackingUntil)
        let minutes = Int((reloadAt.timeIntervalSince(now) / 60).rounded(.up))
        let entryDates = (0..<max(1, minutes)).map { now.addingTimeInterval(TimeInterval($0 * 60)) }
        return Plan(entryDates: entryDates, reloadAt: reloadAt)
    }
}
