import WidgetKit

struct ArrivalsEntry: TimelineEntry {
    struct Section: Identifiable {
        let title: String
        let stopID: Int?
        let stopName: String
        let arrivals: [Arrival]
        let message: String?

        var id: String { title }
    }

    let date: Date
    let sections: [Section]
    /// Set while a tracking session is running; nil means idle (times shown as clock times).
    let trackingUntil: Date?
    let message: String?

    var isTracking: Bool { trackingUntil != nil }

    static let placeholder = ArrivalsEntry(
        date: .now,
        sections: [
            Section(title: "Leaving home", stopID: nil, stopName: "CDS Stop #2 (111)", arrivals: [
                Arrival(routeID: 7, routeName: "A Line", colorHex: "#FBF140", date: .now.addingTimeInterval(240), isLive: true, vehicleID: 1),
                Arrival(routeID: 4, routeName: "H Line", colorHex: "#14B3C4", date: .now.addingTimeInterval(540), isLive: true, vehicleID: 3),
            ], message: nil),
            Section(title: "Going home", stopID: nil, stopName: "University Center, North (107)", arrivals: [
                Arrival(routeID: 7, routeName: "A Line", colorHex: "#FBF140", date: .now.addingTimeInterval(420), isLive: true, vehicleID: 2),
                Arrival(routeID: 6, routeName: "N Line", colorHex: "#E24FA7", date: .now.addingTimeInterval(900), isLive: true, vehicleID: 4),
            ], message: nil),
        ],
        trackingUntil: .now.addingTimeInterval(TrackingSession.duration),
        message: nil
    )
}

/// Idle by default: one fetch, no scheduled reloads. Tapping ↻ starts a 30-minute session that
/// refetches every 5 minutes and pre-renders a minute-by-minute countdown in between.
struct ArrivalsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ArrivalsEntry {
        .placeholder
    }

    func snapshot(for configuration: SelectStopIntent, in context: Context) async -> ArrivalsEntry {
        if context.isPreview { return .placeholder }
        return await load(configuration, plan: TrackingSession.plan(now: .now, trackingUntil: nil)).first ?? .placeholder
    }

    func timeline(for configuration: SelectStopIntent, in context: Context) async -> Timeline<ArrivalsEntry> {
        let plan = TrackingSession.plan(now: .now, trackingUntil: RefreshIntent.trackingUntil)
        let entries = await load(configuration, plan: plan)
        return Timeline(entries: entries, policy: plan.reloadAt.map { .after($0) } ?? .never)
    }

    private func load(_ configuration: SelectStopIntent, plan: TrackingSession.Plan) async -> [ArrivalsEntry] {
        let picks = [("Leaving home", configuration.homeStops ?? []), ("Going home", configuration.returnStops ?? [])]
        let trackingUntil = plan.reloadAt == nil ? nil : RefreshIntent.trackingUntil
        guard picks.contains(where: { !$0.1.isEmpty }) else {
            return [ArrivalsEntry(date: .now, sections: [], trackingUntil: nil,
                                  message: "Long-press › Edit Widget to pick your stops")]
        }
        do {
            let client = TransLocClient.shared
            let routes = try await client.routes()
            let (stopArrivals, fetchedAt) = try await client.arrivals()
            let stops = StopCatalog.stops(from: routes)
            return plan.entryDates.map { entryDate in
                let sections = picks.map { title, picked in
                    guard let first = picked.first else {
                        return ArrivalsEntry.Section(title: title, stopID: nil, stopName: "Not set",
                                                     arrivals: [], message: "Edit widget")
                    }
                    // Several picks are merged so whichever nearby stop's bus comes first wins.
                    let members = stops.filter { stop in picked.contains { $0.id == stop.id } }
                    guard let stop = members.count > 1
                        ? StopCatalog.group(members, id: members[0].id,
                                            name: members.map(\.name).joined(separator: " + "), routes: routes)
                        : members.first else {
                        return ArrivalsEntry.Section(title: title, stopID: first.id, stopName: first.name,
                                                     arrivals: [], message: "Stop not served")
                    }
                    // Live buses only: a timetable guess for a line that isn't running just wastes a row.
                    let arrivals = ArrivalCalculator.arrivals(
                        at: stop, from: stopArrivals, routes: routes, fetchedAt: fetchedAt, now: entryDate
                    ).filter(\.isLive)
                    return ArrivalsEntry.Section(title: title, stopID: stop.id, stopName: stop.name,
                                                 arrivals: arrivals, message: arrivals.isEmpty ? "No buses running" : nil)
                }
                return ArrivalsEntry(date: entryDate, sections: sections, trackingUntil: trackingUntil, message: nil)
            }
        } catch {
            return [ArrivalsEntry(date: .now, sections: [], trackingUntil: nil, message: "Can't reach TransLoc")]
        }
    }
}
