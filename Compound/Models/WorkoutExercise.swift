import Foundation
import SwiftData

/// A *record* row inside a performed workout, with snapshots of the exercise
/// name and library id so history survives the exercise being renamed or deleted.
@Model
final class WorkoutExercise {
    var id: UUID
    var exerciseName: String
    var position: Int
    /// Library identity, snapshotted so stats and prefill still group this
    /// performance after the exercise is deleted. Distinct from `id`, which
    /// identifies this row.
    var exerciseID: UUID?

    var workout: Workout?

    /// Unidirectional to-one; nullified if the exercise is deleted.
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.workoutExercise)
    var sets: [SetEntry] = []

    init(
        id: UUID = UUID(),
        exercise: Exercise? = nil,
        exerciseName: String,
        position: Int = 0
    ) {
        self.id = id
        self.exercise = exercise
        self.exerciseName = exerciseName
        self.position = position
        self.exerciseID = exercise?.id
    }
}

extension WorkoutExercise {
    /// Sets in set-number order.
    var orderedSets: [SetEntry] {
        sets.sorted { $0.setNumber < $1.setNumber }
    }

    /// Library identity for stats and prefill: the snapshot, then the live
    /// relationship, so grouping survives deletion of the library entry.
    var resolvedExerciseID: UUID? { exerciseID ?? exercise?.id }
}
