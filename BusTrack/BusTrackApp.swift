import SwiftUI
import UserNotifications

@main
struct BusTrackApp: App {
    @State private var model = AppModel()
    @State private var favorites = FavoritesStore()
    @State private var alertManager = AlertManager()
    @Environment(\.scenePhase) private var scenePhase

    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(favorites)
                .environment(alertManager)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, !alertManager.alerts.isEmpty {
                AlertManager.scheduleBackgroundRefresh()
            }
        }
        .backgroundTask(.appRefresh(AlertManager.backgroundTaskID)) {
            await model.refreshArrivals()
            await alertManager.update(using: model)
            if await !alertManager.alerts.isEmpty {
                AlertManager.scheduleBackgroundRefresh()
            }
        }
    }
}

struct RootView: View {
    enum Tab: Hashable { case favorites, map, stops }

    @Environment(AppModel.self) private var model
    @State private var tab: Tab = .favorites
    @State private var favoritesPath = NavigationPath()

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $favoritesPath) {
                FavoritesView()
                    .navigationDestination(for: StopRoute.self) { StopDetailView(stopID: $0.id) }
            }
            .tabItem { Label("Favorites", systemImage: "star.fill") }
            .tag(Tab.favorites)

            NavigationStack {
                LiveMapView()
                    .navigationDestination(for: StopRoute.self) { StopDetailView(stopID: $0.id) }
            }
            .tabItem { Label("Map", systemImage: "map.fill") }
            .tag(Tab.map)

            NavigationStack {
                StopPickerView()
                    .navigationDestination(for: StopRoute.self) { StopDetailView(stopID: $0.id) }
            }
            .tabItem { Label("All Stops", systemImage: "list.bullet") }
            .tag(Tab.stops)
        }
        .task { await model.loadRoutes() }
        // Widget taps open bustrack://stop/<AddressID>.
        .onOpenURL { url in
            guard url.scheme == "bustrack", url.host() == "stop",
                  let id = Int(url.lastPathComponent) else { return }
            tab = .favorites
            favoritesPath = NavigationPath([StopRoute(id: id)])
        }
    }
}

/// Navigation value for a stop's detail screen.
struct StopRoute: Hashable {
    let id: Int
}
