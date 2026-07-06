import Foundation
import SwiftData

/// One performed session — a permanent snapshot of what actually happened.
/// Directly editable by the user, but never mutated as a side effect of editing
/// a routine. `routineID` / `routineName` are snapshotted so the Log card still
/// reads correctly after a routine is renamed or deleted.
@Model
final class Workout {
    var id: UUID
    var routineID: UUID?
    var routineName: String
    var date: Date
    var startedAt: Date
    var durationSeconds: Int
    /// Set when the user manually edits a finished session; nil otherwise.
    var editedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise] = []

    init(
        id: UUID = UUID(),
        routineID: UUID? = nil,
        routineName: String,
        date: Date = .now,
        startedAt: Date = .now,
        durationSeconds: Int = 0,
        editedAt: Date? = nil
    ) {
        self.id = id
        self.routineID = routineID
        self.routineName = routineName
        self.date = date
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.editedAt = editedAt
    }
}
