import Foundation
import Testing
@testable import BusTrack

private final class FixtureToken {}

private func fixture<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
    let url = try #require(Bundle(for: FixtureToken.self).url(forResource: name, withExtension: "json"))
    return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
}

struct DecodingTests {
    @Test func decodesRoutes() throws {
        let routes: [Route] = try fixture("routes")
        #expect(routes.count == 2)
        let aLine = try #require(routes.first { $0.routeID == 7 })
        #expect(aLine.name == "A Line")
        #expect(aLine.colorHex == "#FBF140")
        #expect(aLine.isRunning)
        #expect(aLine.stops.count == 4)
        #expect(aLine.stops.last?.isLoopTerminus == true)
    }

    @Test func decodesArrivals() throws {
        let arrivals: [StopArrivals] = try fixture("arrivals")
        #expect(arrivals.count == 3)
        let hLine = try #require(arrivals.first { $0.routeStopID == 24 })
        #expect(hLine.vehicleEstimates.isEmpty)
        #expect(hLine.scheduledTimes.first?.arrival.date == Date(timeIntervalSince1970: 1_793_066_700))
    }

    @Test func decodesVehicles() throws {
        let vehicles: [VehiclePoint] = try fixture("vehicles")
        #expect(vehicles.map(\.name) == ["AE-03", "AE-06"])
        #expect(vehicles[0].heading == 75)
    }

    @Test func parsesDotNetDates() {
        #expect(DotNetDate.parse("/Date(1793066400000)/") == Date(timeIntervalSince1970: 1_793_066_400))
        // The offset is informational; the milliseconds are already UTC.
        #expect(DotNetDate.parse("/Date(1793064428000-0600)/") == Date(timeIntervalSince1970: 1_793_064_428))
        #expect(DotNetDate.parse("garbage") == nil)
    }

    @Test func routesRoundTripThroughDiskCacheFormat() throws {
        let routes: [Route] = try fixture("routes")
        let decoded = try JSONDecoder().decode([Route].self, from: JSONEncoder().encode(routes))
        #expect(decoded == routes)
    }
}

struct StopCatalogTests {
    @Test func groupsRouteStopsByAddress() throws {
        let stops = StopCatalog.stops(from: try fixture("routes"))
        let cds2 = try #require(stops.first { $0.id == 3 })
        #expect(cds2.name == "CDS Stop #2 (111)")
        #expect(cds2.routeStopIDs == [53, 24])
        #expect(cds2.routeIDs == [7, 4]) // A Line (order 10) before H Line (order 40)
    }

    @Test func skipsLoopTerminusDuplicates() throws {
        let stops = StopCatalog.stops(from: try fixture("routes"))
        let ucNorth = try #require(stops.first { $0.id == 8 })
        #expect(ucNorth.routeStopIDs == [49])
        #expect(stops.count == 4) // UC North, CDS #1, CDS #2, UC South
    }
}

struct ArrivalCalculatorTests {
    @Test func liveEstimatesAreSortedAndOffRouteIgnored() throws {
        let routes: [Route] = try fixture("routes")
        let stopArrivals: [StopArrivals] = try fixture("arrivals")
        let stop = try #require(StopCatalog.stops(from: routes).first { $0.id == 3 })
        let fetchedAt = Date(timeIntervalSince1970: 1_793_042_430)

        let arrivals = ArrivalCalculator.arrivals(
            at: stop, from: stopArrivals, routes: routes, fetchedAt: fetchedAt, now: fetchedAt
        )

        let live = arrivals.filter(\.isLive)
        #expect(live.map(\.vehicleID) == [8, 7])
        #expect(live[0].date == fetchedAt.addingTimeInterval(30))
        #expect(live[0].label(relativeTo: fetchedAt) == "Now")
        #expect(live[1].label(relativeTo: fetchedAt) == "11 min")
        #expect(!arrivals.contains { $0.vehicleID == 99 })
    }

    @Test func fallsBackToScheduleWhenNoLiveEstimates() throws {
        let routes: [Route] = try fixture("routes")
        let stopArrivals: [StopArrivals] = try fixture("arrivals")
        let stop = try #require(StopCatalog.stops(from: routes).first { $0.id == 3 })
        let fetchedAt = Date(timeIntervalSince1970: 1_793_042_430)

        let arrivals = ArrivalCalculator.arrivals(
            at: stop, from: stopArrivals, routes: routes, fetchedAt: fetchedAt, now: fetchedAt
        )

        let scheduled = arrivals.filter { $0.routeID == 4 }
        #expect(scheduled.count == 2)
        #expect(scheduled.allSatisfy { !$0.isLive })
        #expect(scheduled[0].date == Date(timeIntervalSince1970: 1_793_066_700))
    }

    @Test func dropsBusesThatAlreadyLeft() throws {
        let routes: [Route] = try fixture("routes")
        let stopArrivals: [StopArrivals] = try fixture("arrivals")
        let stop = try #require(StopCatalog.stops(from: routes).first { $0.id == 3 })
        let fetchedAt = Date(timeIntervalSince1970: 1_793_042_430)

        // Five minutes later the bus that was 30s away is gone.
        let later = ArrivalCalculator.arrivals(
            at: stop, from: stopArrivals, routes: routes, fetchedAt: fetchedAt,
            now: fetchedAt.addingTimeInterval(300)
        )
        #expect(later.filter(\.isLive).map(\.vehicleID) == [7])
    }

    @Test func groupsByRouteInStopOrder() throws {
        let routes: [Route] = try fixture("routes")
        let stopArrivals: [StopArrivals] = try fixture("arrivals")
        let stop = try #require(StopCatalog.stops(from: routes).first { $0.id == 3 })
        let fetchedAt = Date(timeIntervalSince1970: 1_793_042_430)
        let arrivals = ArrivalCalculator.arrivals(
            at: stop, from: stopArrivals, routes: routes, fetchedAt: fetchedAt, now: fetchedAt
        )

        #expect(ArrivalCalculator.byRoute(arrivals, stop: stop).map(\.routeID) == [7, 4])
    }
}

struct PolylineTests {
    @Test func decodesGoogleReferenceExample() {
        let points = Polyline.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
        #expect(points.count == 3)
        #expect(abs(points[0].latitude - 38.5) < 1e-6)
        #expect(abs(points[0].longitude - -120.2) < 1e-6)
        #expect(abs(points[2].latitude - 43.252) < 1e-6)
        #expect(abs(points[2].longitude - -126.453) < 1e-6)
    }

    @Test func emptyStringGivesNoPoints() {
        #expect(Polyline.decode("").isEmpty)
    }
}
