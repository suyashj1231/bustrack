import WidgetKit

struct ArrivalsEntry: TimelineEntry {
    let date: Date
    let stopID: Int?
    let stopName: String
    let arrivals: [Arrival]
    let message: String?

    static let placeholder = ArrivalsEntry(
        date: .now,
        stopID: nil,
        stopName: "CDS Stop #2 (111)",
        arrivals: [
            Arrival(routeID: 7, routeName: "A Line", colorHex: "#FBF140", date: .now.addingTimeInterval(240), isLive: true, vehicleID: 1),
            Arrival(routeID: 7, routeName: "A Line", colorHex: "#FBF140", date: .now.addingTimeInterval(780), isLive: true, vehicleID: 2),
            Arrival(routeID: 4, routeName: "H Line", colorHex: "#14B3C4", date: .now.addingTimeInterval(540), isLive: true, vehicleID: 3),
        ],
        message: nil
    )
}

struct ArrivalsProvider: AppIntentTimelineProvider {
    /// iOS only allows a few dozen widget reloads a day, so fetch once and pre-render
    /// a minute-by-minute countdown from the predicted arrival times.
    private let minutesOfEntries = 10
    private let reloadAfter: TimeInterval = 5 * 60

    func placeholder(in context: Context) -> ArrivalsEntry {
        .placeholder
    }

    func snapshot(for configuration: SelectStopIntent, in context: Context) async -> ArrivalsEntry {
        if context.isPreview { return .placeholder }
        return await load(configuration).first ?? .placeholder
    }

    func timeline(for configuration: SelectStopIntent, in context: Context) async -> Timeline<ArrivalsEntry> {
        let entries = await load(configuration)
        return Timeline(entries: entries, policy: .after(.now.addingTimeInterval(reloadAfter)))
    }

    private func load(_ configuration: SelectStopIntent) async -> [ArrivalsEntry] {
        guard let selected = configuration.stop else {
            return [ArrivalsEntry(date: .now, stopID: nil, stopName: "BusTrack", arrivals: [],
                                  message: "Long-press › Edit Widget to pick a stop")]
        }
        do {
            let client = TransLocClient.shared
            let routes = try await client.routes()
            let (stopArrivals, fetchedAt) = try await client.arrivals()
            guard let stop = StopCatalog.stops(from: routes).first(where: { $0.id == selected.id }) else {
                return [ArrivalsEntry(date: .now, stopID: selected.id, stopName: selected.name, arrivals: [],
                                      message: "Stop no longer served")]
            }
            let start = Date.now
            return (0..<minutesOfEntries).map { minute in
                let entryDate = start.addingTimeInterval(TimeInterval(minute * 60))
                let arrivals = ArrivalCalculator.arrivals(
                    at: stop, from: stopArrivals, routes: routes, fetchedAt: fetchedAt, now: entryDate
                )
                return ArrivalsEntry(date: entryDate, stopID: stop.id, stopName: stop.name, arrivals: arrivals,
                                     message: arrivals.isEmpty ? "No buses running" : nil)
            }
        } catch {
            return [ArrivalsEntry(date: .now, stopID: selected.id, stopName: selected.name, arrivals: [],
                                  message: "Can't reach TransLoc")]
        }
    }
}
