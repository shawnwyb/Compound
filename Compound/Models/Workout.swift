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
    /// When the session was finished. `nil` means the workout is still in
    /// progress (live); set on Finish. In-progress workouts are excluded from Log
    /// history, Stats, export, and prefill (see `isInProgress`).
    var finishedAt: Date?
    /// Freeform notes for the session.
    var notes: String = ""
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
        finishedAt: Date? = nil,
        notes: String = "",
        editedAt: Date? = nil
    ) {
        self.id = id
        self.routineID = routineID
        self.routineName = routineName
        self.date = date
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.finishedAt = finishedAt
        self.notes = notes
        self.editedAt = editedAt
    }
}

extension Workout {
    /// A live, unfinished session. `nil` `finishedAt` is the in-progress sentinel;
    /// such workouts must stay invisible to analytics, Log history, and prefill.
    var isInProgress: Bool { finishedAt == nil }

    /// Exercises in the order they were performed / arranged.
    var orderedExercises: [WorkoutExercise] {
        exercises.sorted { $0.position < $1.position }
    }

    /// Completed sets across the whole session.
    var completedSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
    }
}
