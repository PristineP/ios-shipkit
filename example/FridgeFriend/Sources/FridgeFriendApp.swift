import SwiftUI
import SwiftData

@main
struct FridgeFriendApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: FridgeItem.self)
        } catch {
            // A corrupt store on disk must not turn into a crash loop at
            // launch. Fall back to an in-memory container so the app stays
            // usable; losing the on-disk data is bad, bricking the app is worse.
            let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: FridgeItem.self, configurations: fallback)
            } catch {
                // If even an in-memory container fails, SwiftData itself is
                // broken on this device; there is nothing sensible to render.
                fatalError("Failed to create in-memory ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
