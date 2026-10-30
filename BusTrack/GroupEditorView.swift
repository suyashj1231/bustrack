import SwiftUI

/// Create or edit a stop group. Stops within walking distance of the ones picked are suggested first.
struct GroupEditorView: View {
    /// nil to create a new group.
    var group: StopGroup?

    @Environment(AppModel.self) private var model
    @Environment(StopGroupStore.self) private var groups
    @Environment(FavoritesStore.self) private var favorites
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selected: [Int] = []
    @State private var query = ""

    private static let nearbyMeters: Double = 100

    private var selectedStops: [Stop] {
        selected.compactMap { id in model.stops.first { $0.id == id } }
    }

    /// Unpicked stops close to any picked one, nearest first.
    private var nearby: [(stop: Stop, meters: Double)] {
        guard query.isEmpty else { return [] }
        return model.stops
            .filter { !selected.contains($0.id) }
            .compactMap { stop in
                let meters = selectedStops.map { StopCatalog.distance($0, stop) }.min() ?? .infinity
                return meters <= Self.nearbyMeters ? (stop, meters) : nil
            }
            .sorted { $0.meters < $1.meters }
    }

    private var others: [Stop] {
        let nearbyIDs = Set(nearby.map(\.stop.id))
        return model.stops.filter { stop in
            !selected.contains(stop.id) && !nearbyIDs.contains(stop.id)
                && (query.isEmpty || stop.name.localizedCaseInsensitiveContains(query))
        }
    }

    private var defaultName: String {
        selectedStops.map(\.name).joined(separator: " + ")
    }

    var body: some View {
        List {
            Section {
                TextField(defaultName.isEmpty ? "Group name" : defaultName, text: $name)
            } footer: {
                Text("Buses at any of these stops show up together, soonest first.")
            }

            if !selectedStops.isEmpty {
                Section("In this group") {
                    ForEach(selectedStops) { stop in
                        stopRow(stop, detail: nil, isSelected: true)
                    }
                }
            }
            if !nearby.isEmpty {
                Section("Nearby") {
                    ForEach(nearby, id: \.stop.id) { item in
                        stopRow(item.stop, detail: "\(Int(item.meters.rounded())) m", isSelected: false)
                    }
                }
            }
            Section(selected.isEmpty ? "Pick at least two stops" : "All stops") {
                ForEach(others) { stop in
                    stopRow(stop, detail: nil, isSelected: false)
                }
            }

            if let group {
                Section {
                    Button("Delete Group", role: .destructive) {
                        groups.delete(id: group.id)
                        if favorites.contains(group.id) { favorites.toggle(group.id) }
                        dismiss()
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Find a stop")
        .navigationTitle(group == nil ? "New Group" : "Edit Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(selected.count < 2)
            }
        }
        .onAppear {
            if let group, selected.isEmpty {
                name = group.name
                selected = group.stopIDs
            }
        }
    }

    private func stopRow(_ stop: Stop, detail: String?, isSelected: Bool) -> some View {
        Button {
            if isSelected {
                selected.removeAll { $0 == stop.id }
            } else {
                selected.append(stop.id)
            }
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.name)
                        .foregroundStyle(.primary)
                    Text(stop.routeIDs.compactMap { model.routesByID[$0]?.name }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let finalName = trimmed.isEmpty ? defaultName : trimmed
        if var group {
            group.name = finalName
            group.stopIDs = selected
            groups.update(group)
        } else {
            let created = groups.add(name: finalName, stopIDs: selected)
            if !favorites.contains(created.id) { favorites.toggle(created.id) }
        }
        dismiss()
    }
}
