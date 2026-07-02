import SwiftUI
import SwiftData

/// Root screen: every tracked item, grouped by expiry status in a fixed
/// order (Expiring Soon → Fresh → Expired) and sorted by expiry date inside
/// each group. Status is computed against `referenceDate`, which refreshes
/// when the app returns to the foreground so an app left in memory overnight
/// doesn't show yesterday's grouping.
struct ItemListView: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \FridgeItem.expiryDate) private var items: [FridgeItem]

    @State private var referenceDate = Date.now

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyStateView(
                    icon: "refrigerator",
                    title: "Nothing tracked yet",
                    message: "Add what's in your fridge, freezer, and pantry, and FridgeFriend will watch the dates for you.",
                    actionTitle: "Add First Item",
                    action: { router.present(.addItem) }
                )
            } else {
                itemList
            }
        }
        .navigationTitle("FridgeFriend")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    router.push(.stats)
                } label: {
                    Label("Stats", systemImage: "chart.bar")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.present(.addItem)
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                referenceDate = .now
            }
        }
    }

    private var itemList: some View {
        List {
            ForEach(ExpiryStatus.allCases, id: \.self) { status in
                let sectionItems = items.filter { $0.expiryStatus(asOf: referenceDate) == status }
                if !sectionItems.isEmpty {
                    Section {
                        ForEach(sectionItems) { item in
                            NavigationLink(value: Route.itemDetail(item)) {
                                ItemRow(item: item, referenceDate: referenceDate)
                            }
                        }
                        .onDelete { offsets in
                            delete(offsets, in: sectionItems)
                        }
                    } header: {
                        HStack {
                            Text(Theme.statusLabel(status))
                            Spacer()
                            Text("\(sectionItems.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func delete(_ offsets: IndexSet, in sectionItems: [FridgeItem]) {
        for offset in offsets where sectionItems.indices.contains(offset) {
            modelContext.delete(sectionItems[offset])
        }
    }
}

private struct ItemRow: View {
    let item: FridgeItem
    let referenceDate: Date

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: item.location.icon)
                .foregroundStyle(.secondary)
                .frame(width: 28)
                .accessibilityLabel(item.location.label)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(item.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: Theme.Spacing.s)

            ExpiryBadge(item: item, referenceDate: referenceDate)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}
