import AppIntents
import WidgetKit

/// A stop the user can pick when editing the widget.
struct StopEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Stop"
    static let defaultQuery = StopQuery()

    let id: Int
    let name: String
    /// e.g. "H, N", so similar names like 631 VDC Stop #1 and VDC Norte Stop #1 are easy to tell apart.
    var lines = ""

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: lines.isEmpty ? nil : "\(lines)")
    }
}

struct StopQuery: EntityStringQuery {
    func entities(for identifiers: [Int]) async throws -> [StopEntity] {
        try await allStops().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [StopEntity] {
        try await allStops().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [StopEntity] {
        try await allStops()
    }

    private func allStops() async throws -> [StopEntity] {
        let routes = try await TransLocClient.shared.routes()
        let letters = Dictionary(uniqueKeysWithValues: routes.map {
            ($0.routeID, $0.name.replacingOccurrences(of: " Line", with: ""))
        })
        return StopCatalog.stops(from: routes).map { stop in
            StopEntity(id: stop.id, name: stop.name,
                       lines: stop.routeIDs.compactMap { letters[$0] }.joined(separator: ", "))
        }
    }
}

struct SelectStopIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Stops"
    static let description = IntentDescription(
        "Pick the stops you leave home from and the stops you take home. Pick several nearby stops to see whichever bus comes first."
    )

    @Parameter(title: "Leaving home")
    var homeStops: [StopEntity]?

    @Parameter(title: "Going home")
    var returnStops: [StopEntity]?
}

/// The widget's ↻ button: fetch now and keep tracking for `TrackingSession.duration`.
struct RefreshIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Bus Times"
    static let isDiscoverable = false

    static let trackingUntilKey = "trackingUntil"

    static var trackingUntil: Date? {
        UserDefaults.standard.object(forKey: trackingUntilKey) as? Date
    }

    func perform() async throws -> some IntentResult {
        // Runs in the widget extension, so the provider reads the same UserDefaults.
        UserDefaults.standard.set(Date.now.addingTimeInterval(TrackingSession.duration), forKey: Self.trackingUntilKey)
        // WidgetKit reloads the widget's timeline after a button intent finishes.
        return .result()
    }
}
