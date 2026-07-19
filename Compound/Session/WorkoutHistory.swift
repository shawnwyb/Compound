import Foundation
import SwiftData

/// Bridges SwiftData models and the pure session logic: starts a persisted
/// in-progress `Workout` from a routine and reduces past workouts to the plain
/// history structs prefill consumes.
enum WorkoutHistory {

    /// Reduce persisted workouts to the plain history structs prefill consumes.
    /// Pass only finished workouts — an in-progress session must never seed itself.
    static func snapshot(_ workouts: [Workout]) -> [HistoricalWorkout] {
        workouts.map { workout in
            HistoricalWorkout(
                date: workout.date,
                exercises: workout.exercises.compactMap { performed in
                    guard let exerciseID = performed.exercise?.id else { return nil }
                    return HistoricalExercise(
                        exerciseID: exerciseID,
                        sets: performed.sets.map { set in
                            HistoricalSet(
                                setNumber: set.setNumber,
                                reps: set.reps,
                                weight: set.weight,
                                completed: set.completed
                            )
                        }
                    )
                },
                routineID: workout.routineID
            )
        }
    }

    /// Start a workout: persist a fresh in-progress `Workout` (`finishedAt == nil`)
    /// seeded with empty `SetEntry` rows from `routine`. The set *count* per
    /// exercise carries forward from history (so mid-workout adds/deletes stick);
    /// the actual reps/weight are shown as on-the-fly ghosts by the editor, not
    /// stored — the rows start blank and are filled from the ghost on Finish.
    @MainActor
    static func startWorkout(for routine: Routine, context: ModelContext) -> Workout {
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.finishedAt != nil })
        let history = snapshot((try? context.fetch(descriptor)) ?? [])

        let workout = Workout(
            routineID: routine.id,
            routineName: routine.name,
            date: .now,
            startedAt: .now,
            finishedAt: nil
        )
        context.insert(workout)

        for (position, planned) in routine.orderedExercises.enumerated() {
            let remembered = planned.exercise.map {
                PrefillService.lastValues(
                    for: $0.id,
                    in: history,
                    preferringRoutine: routine.prefillFromRoutine ? routine.id : nil
                )
            } ?? []
            let count = SessionBuilder.setCount(
                targetSets: planned.targetSets,
                historyCount: remembered.count
            )

            let performed = WorkoutExercise(
                exercise: planned.exercise,
                exerciseName: planned.exercise?.name ?? "Exercise",
                position: position
            )
            context.insert(performed)
            performed.workout = workout

            for index in 0..<count {
                let entry = SetEntry(setNumber: index + 1)
                context.insert(entry)
                entry.workoutExercise = performed
            }
        }

        try? context.save()
        return workout
    }
}
