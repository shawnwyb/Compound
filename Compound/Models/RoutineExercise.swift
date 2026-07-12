import Foundation
import SwiftData

/// A *plan* row inside a routine: which exercise, and how many sets to target.
/// Reps/weight are intentionally NOT stored here — "remembered" values come from
/// the most recent workout that has real data for the exercise (see PrefillService).
@Model
final class RoutineExercise {
    var id: UUID
    var targetSets: Int
    var position: Int

    var routine: Routine?

    /// Unidirectional to-one; nullified if the exercise is deleted.
    var exercise: Exercise?

    init(
        id: UUID = UUID(),
        exercise: Exercise? = nil,
        targetSets: Int = 3,
        position: Int = 0
    ) {
        self.id = id
        self.exercise = exercise
        self.targetSets = targetSets
        self.position = position
    }
}
