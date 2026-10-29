import SwiftUI
import WidgetKit

@main
struct BusTrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        ArrivalsWidget()
    }
}

struct ArrivalsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ArrivalsWidget", intent: SelectStopIntent.self, provider: ArrivalsProvider()) { entry in
            ArrivalsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(entry.stopID.flatMap { URL(string: "bustrack://stop/\($0)") })
        }
        .configurationDisplayName("Next Bus")
        .description("Upcoming Anteater Express buses at a stop.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct ArrivalsWidgetView: View {
    let entry: ArrivalsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryRectangular:
            rectangular
        case .systemMedium:
            medium
        default:
            small
        }
    }

    // MARK: Home screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.stopName)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let next = entry.arrivals.first {
                routeLabel(next)
                Text(next.label(relativeTo: entry.date))
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let then = entry.arrivals.dropFirst().first {
                    Text("then \(then.routeName) \(then.label(relativeTo: entry.date))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                messageView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.stopName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if entry.arrivals.isEmpty {
                Spacer(minLength: 0)
                messageView
                Spacer(minLength: 0)
            } else {
                ForEach(groupedByRoute.prefix(3), id: \.routeID) { group in
                    HStack {
                        routeLabel(group.arrivals[0])
                        Spacer()
                        Text(group.arrivals.prefix(2).map { $0.label(relativeTo: entry.date) }.joined(separator: " · "))
                            .font(.headline.monospacedDigit())
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Lock screen

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.stopName)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            if entry.arrivals.isEmpty {
                Text(entry.message ?? "No buses")
                    .font(.caption)
            } else {
                ForEach(entry.arrivals.prefix(2)) { arrival in
                    Text("\(arrival.routeName)  \(arrival.label(relativeTo: entry.date))")
                        .font(.caption.monospacedDigit())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        if let next = entry.arrivals.first {
            Text("\(Image(systemName: "bus.fill")) \(next.routeName) \(next.label(relativeTo: entry.date))")
        } else {
            Text("\(Image(systemName: "bus.fill")) \(entry.message ?? "No buses")")
        }
    }

    // MARK: Pieces

    private var groupedByRoute: [(routeID: Int, arrivals: [Arrival])] {
        var order: [Int] = []
        var groups: [Int: [Arrival]] = [:]
        for arrival in entry.arrivals {
            if groups[arrival.routeID] == nil { order.append(arrival.routeID) }
            groups[arrival.routeID, default: []].append(arrival)
        }
        return order.map { (routeID: $0, arrivals: groups[$0]!) }
    }

    private func routeLabel(_ arrival: Arrival) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: arrival.colorHex))
                .frame(width: 10, height: 10)
            Text(arrival.routeName)
                .font(.subheadline.weight(.semibold))
            if !arrival.isLive {
                Text("sched")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var messageView: some View {
        Text(entry.message ?? "No buses running")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

#Preview(as: .systemSmall) {
    ArrivalsWidget()
} timeline: {
    ArrivalsEntry.placeholder
}

#Preview(as: .systemMedium) {
    ArrivalsWidget()
} timeline: {
    ArrivalsEntry.placeholder
}
