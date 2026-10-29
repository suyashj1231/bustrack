import SwiftUI

/// Colored route badge, e.g. a yellow dot with "A Line".
struct RouteBadge: View {
    let name: String
    let colorHex: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: colorHex))
                .overlay(Circle().stroke(.black.opacity(0.15)))
                .frame(width: 12, height: 12)
            Text(name)
                .font(.subheadline.weight(.semibold))
        }
    }
}

/// One route at a stop: "A Line   4 min · 13 min".
struct RouteArrivalsRow: View {
    let arrivals: [Arrival]
    var maxShown = 2

    var body: some View {
        if let first = arrivals.first {
            // Re-render every 15s so "4 min" counts down between network refreshes.
            TimelineView(.periodic(from: .now, by: 15)) { context in
                HStack {
                    RouteBadge(name: first.routeName, colorHex: first.colorHex)
                    Spacer()
                    Text(arrivals.prefix(maxShown).map { $0.label(relativeTo: context.date) }.joined(separator: " · "))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(first.isLive ? .primary : .secondary)
                    if !first.isLive {
                        Text("sched")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct NoBusesRow: View {
    var body: some View {
        Label("No buses running", systemImage: "moon.zzz")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}
