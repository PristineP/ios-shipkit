import SwiftUI
import SwiftData

enum ItemFormMode {
    case add
    case edit(FridgeItem)
}

/// Form state lives in an `@Observable` model, not scattered `@State` vars,
/// so validation and the save path are testable without a view in the loop.
/// Nothing touches SwiftData until `save(in:)` — cancelling an edit can never
/// leave a half-mutated model behind.
@Observable
@MainActor
final class ItemFormModel {
    var name: String
    var quantity: Int
    var location: StorageLocation
    var expiryDate: Date
    var notes: String

    private let editingItem: FridgeItem?

    init(mode: ItemFormMode) {
        switch mode {
        case .add:
            name = ""
            quantity = 1
            location = .fridge
            // A week is the median shelf life of fresh groceries; a sensible
            // default beats forcing a picker interaction on every add.
            expiryDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
            notes = ""
            editingItem = nil
        case .edit(let item):
            name = item.name
            quantity = item.quantity
            location = item.location
            expiryDate = item.expiryDate
            notes = item.notes
            editingItem = item
        }
    }

    var isEditing: Bool {
        editingItem != nil
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        !trimmedName.isEmpty
    }

    /// Applies the form to the store. Returns false when validation fails,
    /// so the view can keep the sheet open instead of silently dropping input.
    @discardableResult
    func save(in context: ModelContext) -> Bool {
        guard canSave else { return false }
        if let item = editingItem {
            item.name = trimmedName
            item.quantity = quantity
            item.location = location
            item.expiryDate = expiryDate
            item.notes = notes
        } else {
            let item = FridgeItem(
                name: trimmedName,
                quantity: quantity,
                location: location,
                expiryDate: expiryDate,
                notes: notes
            )
            context.insert(item)
        }
        return true
    }
}

/// Add/edit sheet. Owns its own `NavigationStack` because it is a modal —
/// it must never push onto the main stack behind it.
struct ItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var model: ItemFormModel

    init(mode: ItemFormMode) {
        _model = State(initialValue: ItemFormModel(mode: mode))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name (e.g. Greek yogurt)", text: $model.name)
                        .textInputAutocapitalization(.sentences)
                    Stepper("Quantity: \(model.quantity)", value: $model.quantity, in: 1...99)
                    Picker("Location", selection: $model.location) {
                        ForEach(StorageLocation.allCases) { location in
                            Label(location.label, systemImage: location.icon)
                                .tag(location)
                        }
                    }
                }

                Section("Expiry") {
                    // Past dates are allowed on purpose: half the point of a
                    // first fill-up is logging the mystery jar from last month.
                    DatePicker("Expires", selection: $model.expiryDate, displayedComponents: .date)
                }

                Section("Notes") {
                    TextField("Optional (e.g. opened Tuesday)", text: $model.notes, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle(model.isEditing ? "Edit Item" : "New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if model.save(in: modelContext) {
                            dismiss()
                        }
                    }
                    .disabled(!model.canSave)
                }
            }
        }
    }
}
