import Foundation
import CoreLocation

/// A route as returned by GetRoutesForMapWithScheduleWithEncodedLine.
struct Route: Codable, Identifiable, Hashable, Sendable {
    let routeID: Int
    let name: String
    let colorHex: String
    let encodedPolyline: String?
    let isRunning: Bool
    let isVisibleOnMap: Bool
    let order: Int
    let stops: [RouteStop]

    var id: Int { routeID }

    enum CodingKeys: String, CodingKey {
        case routeID = "RouteID"
        case name = "Description"
        case colorHex = "MapLineColor"
        case encodedPolyline = "EncodedPolyline"
        case isRunning = "IsRunning"
        case isVisibleOnMap = "IsVisibleOnMap"
        case order = "Order"
        case stops = "Stops"
    }
}

/// One stop on one route. The same physical stop has a different RouteStopID on every route
/// that serves it, but shares an AddressID.
struct RouteStop: Codable, Hashable, Sendable {
    let routeStopID: Int
    let routeID: Int
    let addressID: Int
    let name: String
    let detail: String
    let latitude: Double
    let longitude: Double
    let order: Int

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }

    /// TransLoc repeats the first stop at the end of each loop with Order 1000; it has no estimates.
    var isLoopTerminus: Bool { order >= 1000 }

    enum CodingKeys: String, CodingKey {
        case routeStopID = "RouteStopID"
        case routeID = "RouteID"
        case addressID = "AddressID"
        case name = "Name"
        case detail = "Description"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case order = "Order"
    }
}

/// Arrivals for one RouteStop, from GetRouteStopArrivals.
struct StopArrivals: Codable, Hashable, Sendable {
    let routeID: Int
    let routeStopID: Int
    let vehicleEstimates: [VehicleEstimate]
    let scheduledTimes: [ScheduledTime]

    enum CodingKeys: String, CodingKey {
        case routeID = "RouteID"
        case routeStopID = "RouteStopID"
        case vehicleEstimates = "VehicleEstimates"
        case scheduledTimes = "ScheduledTimes"
    }
}

struct VehicleEstimate: Codable, Hashable, Sendable {
    let vehicleID: Int
    let onRoute: Bool
    let secondsToStop: Int

    enum CodingKeys: String, CodingKey {
        case vehicleID = "VehicleID"
        case onRoute = "OnRoute"
        case secondsToStop = "SecondsToStop"
    }
}

struct ScheduledTime: Codable, Hashable, Sendable {
    let arrival: DotNetDate
    let assignedVehicleID: Int?

    enum CodingKeys: String, CodingKey {
        case arrival = "ArrivalTimeUTC"
        case assignedVehicleID = "AssignedVehicleId"
    }
}

/// A live bus position, from GetMapVehiclePoints.
struct VehiclePoint: Codable, Identifiable, Hashable, Sendable {
    let vehicleID: Int
    let routeID: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let heading: Double
    let groundSpeed: Double
    let isOnRoute: Bool

    var id: Int { vehicleID }
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }

    enum CodingKeys: String, CodingKey {
        case vehicleID = "VehicleID"
        case routeID = "RouteID"
        case name = "Name"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case heading = "Heading"
        case groundSpeed = "GroundSpeed"
        case isOnRoute = "IsOnRoute"
    }
}
