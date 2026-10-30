import SwiftUI

/// Every stop, searchable, with a star to toggle favorites.
struct StopPickerView: View {
    var isSheet = false

    @Environment(AppModel.self) private var model
    @Environment(FavoritesStore.self) private var favorites
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [Stop] {
        guard !query.isEmpty else { return model.stops }
        return model.stops.filter { stop in
            stop.name.localizedCaseInsensitiveContains(query)
                || stop.routeIDs.contains { model.routesByID[$0]?.name.localizedCaseInsensitiveContains(query) == true }
        }
    }

    private var filteredGroups: [Stop] {
        model.groupStops.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            if !filteredGroups.isEmpty {
                Section("My Groups") {
                    ForEach(filteredGroups) { stopRow($0) }
                }
            }
            Section {
                ForEach(filtered) { stopRow($0) }
            }
        }
        .overlay {
            if model.stops.isEmpty {
                if let error = model.errorMessage {
                    ContentUnavailableView(error, systemImage: "wifi.exclamationmark")
                } else {
                    ProgressView("Loading stops…")
                }
            } else if filtered.isEmpty, filteredGroups.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query, prompt: "Stop or line")
        .navigationTitle(isSheet ? "Add Favorites" : "All Stops")
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .refreshable { await model.loadRoutes(forceRefresh: true) }
    }

    private func stopRow(_ stop: Stop) -> some View {
        HStack {
            if isSheet {
                stopLabel(stop)
            } else {
                NavigationLink(value: StopRoute(id: stop.id)) { stopLabel(stop) }
            }
            Button {
                favorites.toggle(stop.id)
            } label: {
                Image(systemName: favorites.contains(stop.id) ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
            }
            .buttonStyle(.borderless)
        }
    }

    private func stopLabel(_ stop: Stop) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stop.name)
            HStack(spacing: 4) {
                ForEach(stop.routeIDs, id: \.self) { id in
                    if let route = model.routesByID[id] {
                        Text(route.name)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: route.colorHex).opacity(0.35), in: Capsule())
                    }
                }
            }
        }
    }
}
