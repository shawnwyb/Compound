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

    /// Remove any in-progress workout left over from a previous session. Nothing
    /// tracks it once the app relaunches (the live session didn't survive a crash
    /// or force-quit), so it would otherwise linger with a running timer and
    /// reappear as a resume card. Runs before the UI so no view reads it mid-delete.
    /// (Resuming an interrupted workout is a possible future enhancement.)
    private static func discardOrphanedWorkouts(in context: ModelContext) {
        let orphans = (try? context.fetch(
            FetchDescriptor<Workout>(predicate: #Predicate { $0.finishedAt == nil })
        )) ?? []
        guard !orphans.isEmpty else { return }
        for orphan in orphans { context.delete(orphan) }
        try? context.save()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
