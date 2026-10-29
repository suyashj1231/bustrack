import CoreLocation

/// Decodes Google's encoded polyline format (precision 5), which TransLoc uses for route shapes.
enum Polyline {
    static func decode(_ encoded: String) -> [CLLocationCoordinate2D] {
        let bytes = Array(encoded.utf8)
        var index = 0
        var lat = 0
        var lng = 0
        var coordinates: [CLLocationCoordinate2D] = []

        func nextValue() -> Int? {
            var result = 0
            var shift = 0
            while index < bytes.count {
                let byte = Int(bytes[index]) - 63
                index += 1
                result |= (byte & 0x1F) << shift
                shift += 5
                if byte < 0x20 {
                    return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
                }
            }
            return nil
        }

        while index < bytes.count {
            guard let dLat = nextValue(), let dLng = nextValue() else { break }
            lat += dLat
            lng += dLng
            coordinates.append(.init(latitude: Double(lat) / 1e5, longitude: Double(lng) / 1e5))
        }
        return coordinates
    }
}
