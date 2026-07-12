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

    /// A finished workout for Log / editor previews.
    @MainActor
    static var sampleWorkout: Workout {
        let context = container.mainContext
        if let existing = try? context.fetch(FetchDescriptor<Workout>()).first {
            return existing
        }
        let routine = sampleRoutine
        let workout = Workout(
            routineID: routine.id,
            routineName: routine.name,
            date: .now,
            startedAt: .now.addingTimeInterval(-2700),
            durationSeconds: 2700
        )
        context.insert(workout)
        for (index, planned) in routine.orderedExercises.prefix(2).enumerated() {
            let performed = WorkoutExercise(
                exercise: planned.exercise,
                exerciseName: planned.exercise?.name ?? "Exercise",
                position: index
            )
            context.insert(performed)
            performed.workout = workout
            for setNumber in 1...3 {
                let entry = SetEntry(
                    setNumber: setNumber,
                    reps: 8,
                    weight: 135,
                    completed: setNumber < 3
                )
                context.insert(entry)
                entry.workoutExercise = performed
            }
        }
        return workout
    }
}
