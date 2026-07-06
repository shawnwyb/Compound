import SwiftUI
import SwiftData

@main
struct CompoundApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: AppSchema.model,
                configurations: ModelConfiguration()
            )
            SeedData.seedIfNeeded(context: container.mainContext)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
