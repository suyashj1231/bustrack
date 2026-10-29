import Foundation

/// TransLoc's relay service serializes dates the old WCF way: "/Date(1793066400000)/" or
/// "/Date(1793064428000-0600)/". The milliseconds are already UTC; the offset is informational.
struct DotNetDate: Codable, Hashable, Sendable {
    let date: Date

    init(_ date: Date) { self.date = date }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let date = DotNetDate.parse(raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad /Date()/ value: \(raw)")
        }
        self.date = date
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("/Date(\(Int64(date.timeIntervalSince1970 * 1000)))/")
    }

    static func parse(_ raw: String) -> Date? {
        guard let open = raw.firstIndex(of: "(") else { return nil }
        var digits = ""
        for ch in raw[raw.index(after: open)...] {
            if ch.isNumber || (digits.isEmpty && ch == "-") {
                digits.append(ch)
            } else {
                break
            }
        }
        guard let ms = Int64(digits) else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
    }
}
