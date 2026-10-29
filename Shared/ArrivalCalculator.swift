import Foundation

/// A bus expected at a stop.
struct Arrival: Identifiable, Hashable, Sendable {
    let routeID: Int
    let routeName: String
    let colorHex: String
    let date: Date
    /// True when this comes from a live GPS estimate, false when it is only the timetable.
    let isLive: Bool
    let vehicleID: Int?

    var id: String { "\(routeID)-\(vehicleID ?? -1)-\(Int(date.timeIntervalSince1970))" }

    func minutesAway(from now: Date = .now) -> Int {
        max(0, Int((date.timeIntervalSince(now) / 60).rounded(.down)))
    }

    /// "Now", "4 min", or "12:25 PM" for timetable-only arrivals.
    func label(relativeTo now: Date = .now) -> String {
        guard isLive else { return date.formatted(date: .omitted, time: .shortened) }
        let minutes = minutesAway(from: now)
        return minutes == 0 ? "Now" : "\(minutes) min"
    }
}

enum ArrivalCalculator {
    /// Next arrivals at a stop across all of its routes, soonest first.
    /// - Parameter fetchedAt: when the arrivals response was received; SecondsToStop is relative to it.
    static func arrivals(
        at stop: Stop,
        from stopArrivals: [StopArrivals],
        routes: [Route],
        fetchedAt: Date,
        now: Date = .now
    ) -> [Arrival] {
        let routesByID = Dictionary(uniqueKeysWithValues: routes.map { ($0.routeID, $0) })
        var result: [Arrival] = []
        for entry in stopArrivals where stop.routeStopIDs.contains(entry.routeStopID) {
            guard let route = routesByID[entry.routeID] else { continue }
            let live = entry.vehicleEstimates.filter(\.onRoute)
            if !live.isEmpty {
                result += live.map {
                    Arrival(
                        routeID: route.routeID, routeName: route.name, colorHex: route.colorHex,
                        date: fetchedAt.addingTimeInterval(TimeInterval($0.secondsToStop)),
                        isLive: true, vehicleID: $0.vehicleID
                    )
                }
            } else {
                result += entry.scheduledTimes.map {
                    Arrival(
                        routeID: route.routeID, routeName: route.name, colorHex: route.colorHex,
                        date: $0.arrival.date, isLive: false, vehicleID: $0.assignedVehicleID
                    )
                }
            }
        }
        // Keep buses that are at most a minute "late" so "Now" doesn't vanish early.
        return result
            .filter { $0.date >= now.addingTimeInterval(-60) }
            .sorted { $0.date < $1.date }
    }

    /// The same arrivals grouped per route, in the stop's route order.
    static func byRoute(_ arrivals: [Arrival], stop: Stop) -> [(routeID: Int, arrivals: [Arrival])] {
        let grouped = Dictionary(grouping: arrivals, by: \.routeID)
        return stop.routeIDs.compactMap { id in
            grouped[id].map { (routeID: id, arrivals: $0) }
        }
    }
}
