import SwiftUI

/// All upcoming buses at one stop, with a bell per route to set a "bus is close" alert.
struct StopDetailView: View {
    let stopID: Int

    @Environment(AppModel.self) private var model
    @Environment(FavoritesStore.self) private var favorites
    @Environment(AlertManager.self) private var alertManager
    @Environment(StopGroupStore.self) private var groups
    @State private var editingGroup: StopGroup?

    private static let leadChoices = [1, 3, 5, 10]

    var body: some View {
        if let stop = model.stop(id: stopID) {
            content(stop)
        } else if stopID < 0, !model.stops.isEmpty {
            ContentUnavailableView("Group deleted", systemImage: "link")
        } else {
            ProgressView()
                .task { await model.loadRoutes() }
        }
    }

    private func content(_ stop: Stop) -> some View {
        let arrivals = model.arrivals(at: stop)
        let byRoute = ArrivalCalculator.byRoute(arrivals, stop: stop)
        return List {
            if let error = model.errorMessage {
                Label(error, systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.orange)
            }
            if alertManager.permissionDenied {
                Label("Turn on notifications for BusTrack in Settings to get alerts.", systemImage: "bell.slash")
                    .foregroundStyle(.orange)
            }
            if byRoute.isEmpty {
                NoBusesRow()
            }
            ForEach(byRoute, id: \.routeID) { group in
                Section {
                    TimelineView(.periodic(from: .now, by: 15)) { context in
                        ForEach(group.arrivals) { arrival in
                            arrivalRow(arrival, now: context.date)
                        }
                    }
                } header: {
                    HStack {
                        RouteBadge(name: group.arrivals[0].routeName, colorHex: group.arrivals[0].colorHex)
                            .textCase(nil)
                        Spacer()
                        alertMenu(stop: stop, arrival: group.arrivals.first { $0.isLive })
                    }
                }
            }
        }
        .navigationTitle(stop.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let group = groups.group(id: stop.id) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { editingGroup = group }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favorites.toggle(stop.id)
                } label: {
                    Image(systemName: favorites.contains(stop.id) ? "star.fill" : "star")
                }
            }
        }
        .sheet(item: $editingGroup) { group in
            NavigationStack {
                GroupEditorView(group: group)
            }
        }
        .refreshable { await model.refreshArrivals() }
        .task {
            await AppModel.poll(every: .seconds(15)) {
                await model.refreshArrivals()
                await alertManager.update(using: model)
            }
        }
    }

    private func arrivalRow(_ arrival: Arrival, now: Date) -> some View {
        HStack {
            Image(systemName: arrival.isLive ? "dot.radiowaves.left.and.right" : "calendar")
                .foregroundStyle(arrival.isLive ? .green : .secondary)
            Text(arrival.label(relativeTo: now))
                .font(.title3.monospacedDigit().weight(arrival.isLive ? .semibold : .regular))
            Spacer()
            Text(arrival.isLive
                 ? arrival.date.formatted(date: .omitted, time: .shortened)
                 : "Scheduled")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func alertMenu(stop: Stop, arrival: Arrival?) -> some View {
        if let arrival {
            let existing = alertManager.alert(stopID: stop.id, routeID: arrival.routeID)
            Menu {
                if let existing {
                    Text("Alerting \(existing.leadMinutes) min before")
                    Button("Cancel Alert", role: .destructive) { alertManager.cancel(existing) }
                } else {
                    Text("Notify me when the next bus is…")
                    ForEach(Self.leadChoices, id: \.self) { minutes in
                        Button("\(minutes) min away") {
                            Task { await alertManager.setAlert(for: arrival, at: stop, leadMinutes: minutes) }
                        }
                    }
                }
            } label: {
                Image(systemName: existing == nil ? "bell" : "bell.fill")
                    .font(.body)
            }
            .textCase(nil)
        }
    }
}
