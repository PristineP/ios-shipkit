import SwiftUI
import SwiftData

/// Read-only view of one item, with edit (sheet) and delete (confirmed).
/// Guards against the item being deleted underneath it — e.g. a swipe-delete
/// racing a push, or a future sync feature — by checking `isDeleted` before
/// touching any property of the model.
struct ItemDetailView: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var modelContext
    let item: FridgeItem

    @State private var isConfirmingDelete = false

    var body: some View {
        Group {
            if item.isDeleted {
                EmptyStateView(
                    icon: "trash",
                    title: "Item Removed",
                    message: "This item is no longer in your list.",
                    actionTitle: "Back to List",
                    action: { router.popToRoot() }
                )
            } else {
                detailList
            }
        }
        .navigationTitle(item.isDeleted ? "" : item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !item.isDeleted {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        router.present(.editItem(item))
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this item?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(item)
                router.pop()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var detailList: some View {
        List {
            Section {
                LabeledContent("Status") {
                    ExpiryBadge(item: item)
                }
                LabeledContent("Expires") {
                    Text(item.expiryDate.formatted(date: .abbreviated, time: .omitted))
                }
                LabeledContent("Location") {
                    Label(item.location.label, systemImage: item.location.icon)
                }
                LabeledContent("Quantity") {
                    Text("\(item.quantity)")
                }
                LabeledContent("Added") {
                    Text(item.addedDate.formatted(date: .abbreviated, time: .omitted))
                }
            }

            if !item.notes.isEmpty {
                Section("Notes") {
                    Text(item.notes)
                }
            }

            Section {
                Button("Delete Item", role: .destructive) {
                    isConfirmingDelete = true
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
