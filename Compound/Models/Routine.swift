import Foundation
import SwiftData

/// A workout *template*: a named, ordered collection of planned exercises.
/// Editing a routine never rewrites past `Workout` history.
@Model
final class Routine {
    var id: UUID
    var name: String
    var createdAt: Date
    var sortOrder: Int
    /// When true, new sessions of this routine prefill from the last time *this
    /// routine* was run, falling back to each exercise's last performance
    /// anywhere until the routine has been run at least once.
    var prefillFromRoutine: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var exercises: [RoutineExercise] = []

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        sortOrder: Int = 0,
        prefillFromRoutine: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.prefillFromRoutine = prefillFromRoutine
    }
}

extension Routine {
    /// Planned exercises in their user-defined order.
    var orderedExercises: [RoutineExercise] {
        exercises.sorted { $0.position < $1.position }
    }
}
