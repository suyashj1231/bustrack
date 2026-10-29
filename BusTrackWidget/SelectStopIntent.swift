import AppIntents
import WidgetKit

/// A stop the user can pick when editing the widget.
struct StopEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Stop"
    static let defaultQuery = StopQuery()

    let id: Int
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
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
        return StopCatalog.stops(from: routes).map { StopEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectStopIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Stop"
    static let description = IntentDescription("Pick the stop whose next buses the widget shows.")

    @Parameter(title: "Stop")
    var stop: StopEntity?
}
