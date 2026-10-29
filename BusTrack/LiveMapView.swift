import CoreLocation
import MapKit
import SwiftUI

/// Buses moving on the map, with route lines and tappable stops.
struct LiveMapView: View {
    @Environment(AppModel.self) private var model
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.6455, longitude: -117.8320),
            span: MKCoordinateSpan(latitudeDelta: 0.022, longitudeDelta: 0.022)
        )
    )
    /// Route IDs to show; empty means all.
    @State private var selectedRoutes: Set<Int> = []
    @State private var locationManager = CLLocationManager()

    private var visibleRoutes: [Route] {
        model.routes.filter { selectedRoutes.isEmpty || selectedRoutes.contains($0.routeID) }
    }

    private var visibleStops: [Stop] {
        let ids = Set(visibleRoutes.map(\.routeID))
        return model.stops.filter { !ids.isDisjoint(with: $0.routeIDs) }
    }

    var body: some View {
        let routesByID = model.routesByID
        Map(position: $position) {
            UserAnnotation()

            ForEach(visibleRoutes) { route in
                if let encoded = route.encodedPolyline {
                    MapPolyline(coordinates: Polyline.decode(encoded))
                        .stroke(Color(hex: route.colorHex).opacity(0.8), lineWidth: 4)
                }
            }

            ForEach(visibleStops) { stop in
                Annotation(stop.name, coordinate: stop.coordinate, anchor: .center) {
                    NavigationLink(value: StopRoute(id: stop.id)) {
                        Circle()
                            .fill(.white)
                            .stroke(.black.opacity(0.6), lineWidth: 2)
                            .frame(width: 12, height: 12)
                    }
                }
                .annotationTitles(.hidden)
            }

            ForEach(model.vehicles.filter { v in visibleRoutes.contains { $0.routeID == v.routeID } }) { vehicle in
                Annotation(vehicle.name, coordinate: vehicle.coordinate, anchor: .center) {
                    BusMarker(
                        color: Color(hex: routesByID[vehicle.routeID]?.colorHex ?? "#888888"),
                        heading: vehicle.heading,
                        isMoving: vehicle.groundSpeed > 1
                    )
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .safeAreaInset(edge: .top) {
            routeFilter
        }
        .navigationTitle("Live Map")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { locationManager.requestWhenInUseAuthorization() }
        // Only poll while the map is on screen.
        .task { await AppModel.poll(every: .seconds(5)) { await model.refreshVehicles() } }
    }

    private var routeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.routes) { route in
                    let isOn = selectedRoutes.contains(route.routeID)
                    Button {
                        if isOn { selectedRoutes.remove(route.routeID) } else { selectedRoutes.insert(route.routeID) }
                    } label: {
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: route.colorHex)).frame(width: 10, height: 10)
                            Text(route.name).font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isOn ? AnyShapeStyle(Color(hex: route.colorHex).opacity(0.35)) : AnyShapeStyle(.regularMaterial), in: Capsule())
                        .opacity(route.isRunning ? 1 : 0.5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
}

private struct BusMarker: View {
    let color: Color
    let heading: Double
    let isMoving: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .stroke(.white, lineWidth: 2)
                .frame(width: 26, height: 26)
                .shadow(radius: 2)
            Image(systemName: isMoving ? "location.north.fill" : "bus.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black.opacity(0.75))
                .rotationEffect(.degrees(isMoving ? heading : 0))
        }
    }
}
