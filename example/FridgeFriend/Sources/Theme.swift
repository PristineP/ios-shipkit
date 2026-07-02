import SwiftUI

/// Central design tokens. Every view pulls color, icon, and spacing decisions
/// from here, so a restyle is a one-file change and status semantics can never
/// drift between screens (the list, badges, and stats all agree on "orange").
enum Theme {

    // MARK: Status

    static func statusColor(_ status: ExpiryStatus) -> Color {
        switch status {
        case .expiringSoon: .orange
        case .fresh: .green
        case .expired: .red
        }
    }

    static func statusLabel(_ status: ExpiryStatus) -> String {
        switch status {
        case .expiringSoon: "Expiring Soon"
        case .fresh: "Fresh"
        case .expired: "Expired"
        }
    }

    static func statusIcon(_ status: ExpiryStatus) -> String {
        switch status {
        case .expiringSoon: "exclamationmark.triangle.fill"
        case .fresh: "checkmark.circle.fill"
        case .expired: "xmark.circle.fill"
        }
    }

    // MARK: Spacing

    /// Four-step scale. If a layout needs a value outside this scale,
    /// the layout is wrong, not the scale.
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    static let cornerRadius: CGFloat = 10
}
