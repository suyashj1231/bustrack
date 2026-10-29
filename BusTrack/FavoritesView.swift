import SwiftUI

struct FavoritesView: View {
    @Environment(AppModel.self) private var model
    @Environment(FavoritesStore.self) private var favorites
    @State private var showingPicker = false

    private var favoriteStops: [Stop] {
        favorites.stopIDs.compactMap { model.stop(id: $0) }
    }

    var body: some View {
        List {
            if let error = model.errorMessage {
                Label(error, systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.orange)
            }
            ForEach(favoriteStops) { stop in
                Section {
                    let byRoute = ArrivalCalculator.byRoute(model.arrivals(at: stop), stop: stop)
                    NavigationLink(value: StopRoute(id: stop.id)) {
                        VStack(alignment: .leading, spacing: 8) {
                            if byRoute.isEmpty {
                                NoBusesRow()
                            } else {
                                ForEach(byRoute, id: \.routeID) { group in
                                    RouteArrivalsRow(arrivals: group.arrivals)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(stop.name)
                }
            }
            .onMove { favorites.move(fromOffsets: $0, toOffset: $1) }
            .onDelete { favorites.remove(atOffsets: $0) }
        }
        .overlay {
            if favorites.stopIDs.isEmpty {
                ContentUnavailableView {
                    Label("No favorite stops", systemImage: "star")
                } description: {
                    Text("Star the stops you use so their next buses show up here.")
                } actions: {
                    Button("Add Stops") { showingPicker = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Favorites")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingPicker = true } label: { Image(systemName: "plus") }
            }
            if !favorites.stopIDs.isEmpty {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                StopPickerView(isSheet: true)
            }
        }
        .refreshable { await model.refreshArrivals() }
        .task { await AppModel.poll(every: .seconds(15)) { await model.refreshArrivals() } }
    }
}
