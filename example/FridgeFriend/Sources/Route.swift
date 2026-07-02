import SwiftUI
import Observation

/// Every push destination in the app. Adding a screen means adding a case
/// here plus one branch in `RootView`'s `navigationDestination` — nothing else.
enum Route: Hashable {
    case itemDetail(FridgeItem)
    case stats
}

/// Every modal in the app. `Identifiable` so a single `.sheet(item:)` in
/// `RootView` drives all presentation.
enum SheetRoute: Identifiable, Hashable {
    case addItem
    case editItem(FridgeItem)

    var id: Self { self }
}

/// Single source of truth for navigation. Views never build their own
/// `NavigationPath`; they ask the router, which makes deep links and
/// programmatic pops (e.g. after a delete) one-liners.
@Observable
@MainActor
final class Router {
    var path: [Route] = []
    var sheet: SheetRoute?

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    func present(_ sheet: SheetRoute) {
        self.sheet = sheet
    }

    func dismissSheet() {
        sheet = nil
    }
}
