import Foundation
import SwiftData

/// Bridges SwiftData models and the pure session logic: builds a session from a
/// routine (with prefill) and persists a finished session back into the store.
enum WorkoutHistory {

    /// Reduce persisted workouts to the plain history structs prefill consumes.
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
                }
            )
        }
    }

    /// Build a fresh in-memory session for `routine`, seeding each set from the
    /// most recent completed history for that exercise.
    @MainActor
    static func makeSession(for routine: Routine, context: ModelContext) -> WorkoutSession {
        let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        let history = snapshot(workouts)

        let exercises = routine.orderedExercises.map { planned -> SessionExercise in
            let remembered = planned.exercise
                .map { PrefillService.lastValues(for: $0.id, in: history) } ?? []
            let seeds = SessionBuilder.seededSets(targetSets: planned.targetSets, lastValues: remembered)
            let sets = seeds.enumerated().map { index, seed in
                SessionSet(setNumber: index + 1, reps: seed.reps, weight: seed.weight)
            }
            return SessionExercise(
                exercise: planned.exercise,
                name: planned.exercise?.name ?? "Exercise",
                sets: sets
            )
        }

        return WorkoutSession(
            routineID: routine.id,
            routineName: routine.name,
            exercises: exercises
        )
    }

    /// Persist a finished session as a `Workout` snapshot (later editable from Log).
    @MainActor
    static func persist(_ session: WorkoutSession, finishedAt: Date = .now, context: ModelContext) {
        let workout = Workout(
            routineID: session.routineID,
            routineName: session.routineName,
            date: session.startedAt,
            startedAt: session.startedAt,
            durationSeconds: session.elapsedSeconds(at: finishedAt)
        )
        context.insert(workout)

        for (index, sessionExercise) in session.exercises.enumerated() {
            let performed = WorkoutExercise(
                exercise: sessionExercise.exercise,
                exerciseName: sessionExercise.name,
                position: index
            )
            context.insert(performed)
            performed.workout = workout

            for sessionSet in sessionExercise.sets {
                let entry = SetEntry(
                    setNumber: sessionSet.setNumber,
                    reps: sessionSet.reps,
                    weight: sessionSet.weight,
                    completed: sessionSet.completed
                )
                context.insert(entry)
                entry.workoutExercise = performed
            }
        }

        try? context.save()
    }
}
