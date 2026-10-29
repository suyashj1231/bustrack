import Foundation

/// Talks to UCI's TransLoc relay service (the same endpoints the shuttle.uci.edu map uses).
actor TransLocClient {
    static let shared = TransLocClient()

    private let baseURL = URL(string: "https://ucirvine.transloc.com/Services/JSONPRelay.svc/")!
    private let session: URLSession
    private var cachedRoutes: [Route]?
    private var routesFetchedAt: Date?

    /// Routes and stops rarely change; refetch at most this often.
    private let routesMaxAge: TimeInterval = 6 * 60 * 60

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    func routes(forceRefresh: Bool = false) async throws -> [Route] {
        if !forceRefresh, let cachedRoutes, let routesFetchedAt,
           Date.now.timeIntervalSince(routesFetchedAt) < routesMaxAge {
            return cachedRoutes
        }
        do {
            let routes: [Route] = try await get(
                "GetRoutesForMapWithScheduleWithEncodedLine", query: ["IsDispatch": "false"]
            )
            cachedRoutes = routes
            routesFetchedAt = .now
            Self.saveToDisk(routes)
            return routes
        } catch {
            // Offline: fall back to whatever we saved last time.
            if let cachedRoutes { return cachedRoutes }
            if let saved = Self.loadFromDisk() {
                cachedRoutes = saved
                return saved
            }
            throw error
        }
    }

    /// Arrivals for every stop, plus the time they were fetched (SecondsToStop is relative to it).
    func arrivals() async throws -> (arrivals: [StopArrivals], fetchedAt: Date) {
        let arrivals: [StopArrivals] = try await get(
            "GetRouteStopArrivals", query: ["TimesPerStopString": "2"]
        )
        return (arrivals, .now)
    }

    func vehicles() async throws -> [VehiclePoint] {
        try await get("GetMapVehiclePoints", query: ["IsPublicMap": "true"])
    }

    private func get<T: Decodable>(_ method: String, query: [String: String]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(method), resolvingAgainstBaseURL: false)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        let (data, response) = try await session.data(from: components.url!)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static var cacheFile: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("routes.json")
    }

    private static func saveToDisk(_ routes: [Route]) {
        try? JSONEncoder().encode(routes).write(to: cacheFile, options: .atomic)
    }

    private static func loadFromDisk() -> [Route]? {
        guard let data = try? Data(contentsOf: cacheFile) else { return nil }
        return try? JSONDecoder().decode([Route].self, from: data)
    }
}
