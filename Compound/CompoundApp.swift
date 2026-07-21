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
            Self.discardOrphanedWorkouts(in: container.mainContext)
            #if DEBUG
            DemoData.handleLaunchArguments(context: container.mainContext)
            #endif
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    /// Clean up in-progress workouts left over from a previous launch (crash or
    /// force-quit — nothing was tracking them anymore). Scaffolding with no
    /// completed sets is deleted so it can't linger with a running timer; a
    /// session with real logged sets survives and is adopted by `RootTabView` as
    /// the minimized active workout. Runs before the UI so no view reads a
    /// workout mid-delete.
    private static func discardOrphanedWorkouts(in context: ModelContext) {
        let orphans = (try? context.fetch(
            FetchDescriptor<Workout>(predicate: #Predicate { $0.finishedAt == nil })
        )) ?? []
        let plan = WorkoutRecovery.plan(for: orphans)
        guard !plan.discard.isEmpty else { return }
        for doomed in plan.discard { context.delete(doomed) }
        try? context.save()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
