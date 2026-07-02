import SwiftUI
import SwiftData

/// Owns the one `NavigationStack` and the one `.sheet` in the app.
/// All routing decisions live here; child views only talk to `Router`.
struct RootView: View {
    @State private var router = Router()

    var body: some View {
        NavigationStack(path: $router.path) {
            ItemListView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .itemDetail(let item):
                        ItemDetailView(item: item)
                    case .stats:
                        StatsView()
                    }
                }
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .addItem:
                ItemFormView(mode: .add)
            case .editItem(let item):
                ItemFormView(mode: .edit(item))
            }
        }
        .environment(router)
    }
}

#Preview {
    RootView()
        .modelContainer(for: FridgeItem.self, inMemory: true)
}
