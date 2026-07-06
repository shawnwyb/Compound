import Foundation
import SwiftData

/// A *record* row inside a performed workout, with a snapshot of the exercise
/// name so history survives the exercise being renamed or deleted.
@Model
final class WorkoutExercise {
    var id: UUID
    var exerciseName: String
    var position: Int

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
    }
}
