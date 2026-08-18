import Foundation
import SwiftData

/// Bridges SwiftData workouts into the plain structs `StatsCalculator` consumes.
enum StatsSnapshot {

    static func from(_ workouts: [Workout]) -> [StatsWorkout] {
        workouts.map { workout in
            StatsWorkout(
                id: workout.id,
                date: workout.date,
                exercises: workout.orderedExercises.map { performed in
                    StatsExercise(
                        exerciseID: performed.resolvedExerciseID ?? performed.id,
                        exerciseName: performed.exerciseName,
                        groupID: performed.exercise?.group?.id,
                        groupName: performed.exercise?.group?.name ?? "Uncategorized",
                        sets: performed.orderedSets.map { set in
                            StatsSet(reps: set.reps, weight: set.weight, completed: set.completed)
                        }
                    )
                }
            )
        }
    }
}
