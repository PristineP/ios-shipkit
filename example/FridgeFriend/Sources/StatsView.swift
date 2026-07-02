import SwiftUI
import SwiftData

/// Aggregate numbers computed in one pass over the items. A plain value type
/// (models are not Sendable, summaries are) so it can be handed to any view
/// or, later, a widget without dragging SwiftData along.
struct StatsSummary: Equatable {
    var total = 0
    var expiringSoon = 0
    var fresh = 0
    var expired = 0
    var byLocation: [StorageLocation: Int] = [:]
    var nextToExpireName: String?
    var nextToExpireDate: Date?

    init(items: [FridgeItem], referenceDate: Date = .now) {
        total = items.count
        for item in items {
            switch item.expiryStatus(asOf: referenceDate) {
            case .expiringSoon: expiringSoon += 1
            case .fresh: fresh += 1
            case .expired: expired += 1
            }
            byLocation[item.location, default: 0] += 1
        }
        let nextUp = items
            .filter { $0.expiryStatus(asOf: referenceDate) != .expired }
            .min { $0.expiryDate < $1.expiryDate }
        nextToExpireName = nextUp?.name
        nextToExpireDate = nextUp?.expiryDate
    }
}

/// Small stats screen. The summary is computed in `.task(id:)` keyed on a
/// fingerprint of the data, so it recomputes exactly when items change and
/// stays off the first frame as the dataset grows.
struct StatsView: View {
    @Query(sort: \FridgeItem.expiryDate) private var items: [FridgeItem]
    @State private var summary: StatsSummary?

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyStateView(
                    icon: "chart.bar",
                    title: "No Stats Yet",
                    message: "Stats appear once you're tracking at least one item."
                )
            } else if let summary {
                statsList(summary)
            } else {
                LoadingStateView(label: "Calculating…")
            }
        }
        .navigationTitle("Stats")
        .task(id: fingerprint) {
            summary = StatsSummary(items: items)
        }
    }

    /// Changes whenever any input to the summary changes; `.task(id:)`
    /// restarts on a new value, so stats can never go stale after an edit.
    private var fingerprint: Int {
        var hasher = Hasher()
        for item in items {
            hasher.combine(item.persistentModelID)
            hasher.combine(item.expiryDate)
            hasher.combine(item.locationRaw)
        }
        return hasher.finalize()
    }

    private func statsList(_ summary: StatsSummary) -> some View {
        List {
            Section("Right Now") {
                StatRow(
                    label: "Tracked items",
                    count: summary.total,
                    icon: "list.bullet",
                    color: .accentColor
                )
                StatRow(
                    label: Theme.statusLabel(.expiringSoon),
                    count: summary.expiringSoon,
                    icon: Theme.statusIcon(.expiringSoon),
                    color: Theme.statusColor(.expiringSoon)
                )
                StatRow(
                    label: Theme.statusLabel(.fresh),
                    count: summary.fresh,
                    icon: Theme.statusIcon(.fresh),
                    color: Theme.statusColor(.fresh)
                )
                StatRow(
                    label: Theme.statusLabel(.expired),
                    count: summary.expired,
                    icon: Theme.statusIcon(.expired),
                    color: Theme.statusColor(.expired)
                )
            }

            Section("By Location") {
                ForEach(StorageLocation.allCases) { location in
                    StatRow(
                        label: location.label,
                        count: summary.byLocation[location] ?? 0,
                        icon: location.icon,
                        color: .secondary
                    )
                }
            }

            if let name = summary.nextToExpireName, let date = summary.nextToExpireDate {
                Section("Use Next") {
                    LabeledContent(name) {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
            }
        }
    }
}

private struct StatRow: View {
    let label: String
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        LabeledContent {
            Text("\(count)")
                .font(.body.weight(.semibold))
                .monospacedDigit()
        } label: {
            Label {
                Text(label)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
        }
    }
}
