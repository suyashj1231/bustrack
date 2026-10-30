import Foundation
import Observation

/// Nearby stops the user wants treated as one, e.g. CDS Stop #3 + VDC Norte Stop #1.
struct StopGroup: Codable, Identifiable, Hashable {
    /// Negative, so it can share favorites, alerts and bustrack:// URLs with real AddressIDs.
    let id: Int
    var name: String
    var stopIDs: [Int]
}

@MainActor
@Observable
final class StopGroupStore {
    private static let key = "stopGroups"

    private(set) var groups: [StopGroup] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([StopGroup].self, from: data) {
            groups = saved
        }
    }

    func group(id: Int) -> StopGroup? {
        groups.first { $0.id == id }
    }

    @discardableResult
    func add(name: String, stopIDs: [Int]) -> StopGroup {
        let group = StopGroup(id: min(0, groups.map(\.id).min() ?? 0) - 1, name: name, stopIDs: stopIDs)
        groups.append(group)
        save()
        return group
    }

    func update(_ group: StopGroup) {
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[index] = group
        save()
    }

    func delete(id: Int) {
        groups.removeAll { $0.id == id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
