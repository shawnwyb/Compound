import Foundation
import SwiftData

/// In-memory container for SwiftUI previews, pre-seeded with the starter data.
enum PreviewData {
    static let container: ModelContainer = {
        do {
            let container = try ModelContainer(
                for: AppSchema.model,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            SeedData.seedIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("Failed to build preview container: \(error)")
        }
    }()

    /// A routine pre-populated with a few exercises, for previews.
    @MainActor
    static var sampleRoutine: Routine {
        let context = container.mainContext
        if let existing = try? context.fetch(FetchDescriptor<Routine>()).first {
            return existing
        }
        let routine = Routine(name: "Push Day", sortOrder: 0)
        context.insert(routine)
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        for (index, exercise) in exercises.prefix(3).enumerated() {
            let item = RoutineExercise(exercise: exercise, targetSets: 3, position: index)
            context.insert(item)
            item.routine = routine
        }
        return routine
    }
}
