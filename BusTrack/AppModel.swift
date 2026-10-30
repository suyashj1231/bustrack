import Foundation
import Observation

/// Holds the latest TransLoc data for the whole app. Views start/stop polling as they appear.
@MainActor
@Observable
final class AppModel {
    private(set) var routes: [Route] = []
    private(set) var stops: [Stop] = []
    private(set) var stopArrivals: [StopArrivals] = []
    private(set) var arrivalsFetchedAt: Date = .distantPast
    private(set) var vehicles: [VehiclePoint] = []
    private(set) var errorMessage: String?

    private let client = TransLocClient.shared
    private let groupStore: StopGroupStore

    init(groups: StopGroupStore) {
        groupStore = groups
    }

    var routesByID: [Int: Route] {
        Dictionary(uniqueKeysWithValues: routes.map { ($0.routeID, $0) })
    }

    /// A real stop, or a user's stop group (negative id) merged into one.
    func stop(id: Int) -> Stop? {
        if let group = groupStore.group(id: id) {
            return StopCatalog.group(group.stopIDs.compactMap { stop(id: $0) }, id: group.id, name: group.name, routes: routes)
        }
        return stops.first { $0.id == id }
    }

    /// Every stop group that still has at least one served stop.
    var groupStops: [Stop] {
        groupStore.groups.compactMap { stop(id: $0.id) }
    }

    func arrivals(at stop: Stop, now: Date = .now) -> [Arrival] {
        ArrivalCalculator.arrivals(
            at: stop, from: stopArrivals, routes: routes, fetchedAt: arrivalsFetchedAt, now: now
        )
    }

    var anyBusRunning: Bool {
        routes.contains(where: \.isRunning)
    }

    func loadRoutes(forceRefresh: Bool = false) async {
        do {
            routes = try await client.routes(forceRefresh: forceRefresh)
                .filter(\.isVisibleOnMap)
                .sorted { $0.order < $1.order }
            stops = StopCatalog.stops(from: routes)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load routes. Check your connection."
        }
    }

    func refreshArrivals() async {
        if routes.isEmpty { await loadRoutes() }
        do {
            let result = try await client.arrivals()
            stopArrivals = result.arrivals
            arrivalsFetchedAt = result.fetchedAt
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't refresh arrival times."
        }
    }

    func refreshVehicles() async {
        if routes.isEmpty { await loadRoutes() }
        do {
            vehicles = try await client.vehicles()
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't refresh bus positions."
        }
    }

    /// Calls `refresh` now and then every `interval` until the calling task is cancelled
    /// (i.e. until the view using `.task` disappears).
    static func poll(every interval: Duration, _ refresh: @MainActor () async -> Void) async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: interval)
        }
    }
}
