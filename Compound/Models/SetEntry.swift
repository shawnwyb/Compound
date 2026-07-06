import Foundation
import SwiftData

/// One set actually performed: reps, weight, and whether it was completed.
@Model
final class SetEntry {
    var id: UUID
    var setNumber: Int
    var reps: Int
    var weight: Double
    var completed: Bool
    /// Rest taken after this set, if tracked.
    var restSeconds: Int?

    var workoutExercise: WorkoutExercise?

    init(
        id: UUID = UUID(),
        setNumber: Int,
        reps: Int = 0,
        weight: Double = 0,
        completed: Bool = false,
        restSeconds: Int? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.completed = completed
        self.restSeconds = restSeconds
    }
}
