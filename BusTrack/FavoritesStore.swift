import Foundation
import Observation

/// The user's starred stops (AddressIDs), in the order they were added.
@MainActor
@Observable
final class FavoritesStore {
    private static let key = "favoriteStopIDs"

    private(set) var stopIDs: [Int]

    init() {
        stopIDs = UserDefaults.standard.array(forKey: Self.key) as? [Int] ?? []
    }

    func contains(_ stopID: Int) -> Bool {
        stopIDs.contains(stopID)
    }

    func toggle(_ stopID: Int) {
        if let index = stopIDs.firstIndex(of: stopID) {
            stopIDs.remove(at: index)
        } else {
            stopIDs.append(stopID)
        }
        save()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        stopIDs.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func remove(atOffsets offsets: IndexSet) {
        stopIDs.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        UserDefaults.standard.set(stopIDs, forKey: Self.key)
    }
}
