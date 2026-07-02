import SwiftUI

/// The one place expiry is rendered as a pill. List rows, the detail screen,
/// and previews all use this so color, icon, and wording never disagree.
struct ExpiryBadge: View {
    let item: FridgeItem
    var referenceDate: Date = .now

    private var status: ExpiryStatus {
        item.expiryStatus(asOf: referenceDate)
    }

    private var text: String {
        item.expiryBadgeText(asOf: referenceDate)
    }

    var body: some View {
        Label(text, systemImage: Theme.statusIcon(status))
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.statusColor(status))
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.statusColor(status).opacity(0.15), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(Theme.statusLabel(status)), \(text)")
    }
}
