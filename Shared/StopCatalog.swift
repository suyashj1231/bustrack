import Foundation
import CoreLocation

/// A physical stop (one AddressID), possibly served by several routes.
struct Stop: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let routeStopIDs: Set<Int>
    let routeIDs: [Int]

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}

enum StopCatalog {
    /// Groups every route's stops by AddressID, skipping the loop-terminus duplicates.
    static func stops(from routes: [Route]) -> [Stop] {
        var grouped: [Int: [RouteStop]] = [:]
        for route in routes where route.isVisibleOnMap {
            for stop in route.stops where !stop.isLoopTerminus {
                grouped[stop.addressID, default: []].append(stop)
            }
        }
        let routeOrder = Dictionary(uniqueKeysWithValues: routes.map { ($0.routeID, $0.order) })
        return grouped.map { addressID, members in
            // "CDS Stop #2 (111)" is more useful than "CDS Stop #2", so prefer the longest description.
            let name = members.map(\.detail).max { $0.count < $1.count } ?? members[0].name
            let routeIDs = Array(Set(members.map(\.routeID)))
                .sorted { (routeOrder[$0] ?? 0) < (routeOrder[$1] ?? 0) }
            return Stop(
                id: addressID,
                name: name.isEmpty ? members[0].name : name,
                latitude: members[0].latitude,
                longitude: members[0].longitude,
                routeStopIDs: Set(members.map(\.routeStopID)),
                routeIDs: routeIDs
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Several nearby stops treated as one: buses at any of them, on every line they serve.
    static func group(_ members: [Stop], id: Int, name: String, routes: [Route]) -> Stop? {
        guard let first = members.first else { return nil }
        let routeOrder = Dictionary(uniqueKeysWithValues: routes.map { ($0.routeID, $0.order) })
        let routeIDs = Array(Set(members.flatMap(\.routeIDs)))
            .sorted { (routeOrder[$0] ?? 0) < (routeOrder[$1] ?? 0) }
        return Stop(
            id: id,
            name: name,
            latitude: first.latitude,
            longitude: first.longitude,
            routeStopIDs: members.reduce(into: Set()) { $0.formUnion($1.routeStopIDs) },
            routeIDs: routeIDs
        )
    }

    /// Straight-line distance in meters.
    static func distance(_ a: Stop, _ b: Stop) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}
