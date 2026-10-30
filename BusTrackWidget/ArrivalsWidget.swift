import AppIntents
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
                .widgetURL(entry.sections.first?.stopID.flatMap { URL(string: "bustrack://stop/\($0)") })
        }
        .configurationDisplayName("Next Bus")
        .description("Next buses at the stop you leave home from and the stop you take home. Tap ↻ to track for 30 minutes.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct ArrivalsWidgetView: View {
    let entry: ArrivalsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if entry.sections.isEmpty, family != .accessoryInline {
            messageOnly
        } else {
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
    }

    // MARK: Home screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            ForEach(entry.sections) { section in
                VStack(alignment: .leading, spacing: 1) {
                    Text(section.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let line = lines(section).first {
                        lineRow(line)
                            .font(.subheadline.weight(.bold).monospacedDigit())
                    } else {
                        sectionMessage(section)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            HStack(alignment: .top, spacing: 12) {
                ForEach(entry.sections) { section in
                    stopLink(section) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(section.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(section.stopName)
                                .font(.caption)
                                .lineLimit(1)
                            if section.arrivals.isEmpty {
                                sectionMessage(section)
                            } else {
                                ForEach(lines(section).prefix(3), id: \.first?.routeID) { line in
                                    lineRow(line)
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Lock screen

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entry.sections) { section in
                if let next = section.arrivals.first {
                    Text("\(section.title): \(next.routeName) \(timeString(next))")
                        .font(.caption.monospacedDigit())
                        .lineLimit(1)
                } else {
                    Text("\(section.title): \(section.message ?? "No buses")")
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            if !entry.isTracking {
                Text("Idle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        // Whichever stop has the sooner bus.
        let next = entry.sections.compactMap(\.arrivals.first).min { $0.date < $1.date }
        if let next {
            return Text("\(Image(systemName: "bus.fill")) \(next.routeName) \(timeString(next))")
        } else {
            return Text("\(Image(systemName: "bus.fill")) \(entry.message ?? "No buses")")
        }
    }

    // MARK: Pieces

    /// Live/idle status plus the ↻ button that starts a 30-minute tracking session.
    private var header: some View {
        HStack(spacing: 4) {
            if let until = entry.trackingUntil {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text("Live till \(until.formatted(date: .omitted, time: .shortened))")
            } else {
                Text("Idle · tap ↻")
            }
            Spacer(minLength: 0)
            Button(intent: RefreshIntent()) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption.weight(.bold))
                    .padding(4)
                    .background(.fill.secondary, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    /// Tapping a column opens that stop in the app.
    @ViewBuilder
    private func stopLink(_ section: ArrivalsEntry.Section, @ViewBuilder content: () -> some View) -> some View {
        if let id = section.stopID, let url = URL(string: "bustrack://stop/\(id)") {
            Link(destination: url, label: content)
        } else {
            content()
        }
    }

    /// One entry per line, soonest line first, each holding that line's upcoming buses in order.
    private func lines(_ section: ArrivalsEntry.Section) -> [[Arrival]] {
        Dictionary(grouping: section.arrivals, by: \.routeID).values
            .sorted { $0[0].date < $1[0].date }
    }

    /// "A   4 · 12 min" while tracking, "A   11:57 · 12:05" when idle.
    private func lineRow(_ line: [Arrival]) -> some View {
        let shown = line.prefix(2)
        let times: String
        if entry.isTracking {
            let minutes = shown.map { $0.minutesAway(from: entry.date) }
            times = minutes.map { $0 == 0 ? "Now" : "\($0)" }.joined(separator: " · ")
                + (minutes.last == 0 ? "" : " min")
        } else {
            times = shown.map { $0.date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()) }
                .joined(separator: " · ")
        }
        return HStack(spacing: 4) {
            routeLabel(line[0])
            Spacer(minLength: 2)
            Text(times)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// Countdown while tracking; clock time when idle, since a countdown would go stale.
    private func timeString(_ arrival: Arrival) -> String {
        entry.isTracking ? arrival.label(relativeTo: entry.date)
            : arrival.date.formatted(date: .omitted, time: .shortened)
    }

    private func routeLabel(_ arrival: Arrival) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: arrival.colorHex))
                .frame(width: 8, height: 8)
            Text(arrival.routeName.replacingOccurrences(of: " Line", with: ""))
                .font(.subheadline.weight(.semibold))
            if !arrival.isLive {
                Text("sched")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sectionMessage(_ section: ArrivalsEntry.Section) -> some View {
        Text(section.message ?? "No buses")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var messageOnly: some View {
        VStack(alignment: .leading, spacing: 6) {
            if family == .systemSmall || family == .systemMedium { header }
            Spacer(minLength: 0)
            Text(entry.message ?? "No buses running")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
