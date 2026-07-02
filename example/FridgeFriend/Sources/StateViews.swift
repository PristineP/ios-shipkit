import SwiftUI

/// Shared empty state. Wraps `ContentUnavailableView` so call sites stay
/// stable if the presentation ever changes, and so every empty screen in the
/// app gets the same shape: icon, title, one sentence, optional action.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// Shared loading state. Used anywhere work is deferred off the first frame;
/// keeps "spinner + one quiet line" consistent across screens.
struct LoadingStateView: View {
    var label: String = "Loading…"

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            ProgressView()
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Empty") {
    EmptyStateView(
        icon: "refrigerator",
        title: "Nothing tracked yet",
        message: "Add what's in your fridge and FridgeFriend will watch the dates.",
        actionTitle: "Add First Item",
        action: {}
    )
}

#Preview("Loading") {
    LoadingStateView(label: "Calculating…")
}
