import Foundation

/// What a workout needs to expose for launch recovery. Kept as a protocol so the
/// decision itself is testable without a `ModelContainer`.
protocol RecoverableWorkout {
    var id: UUID { get }
    var startedAt: Date { get }
    /// Whether the user put anything into this session — see `Workout.hasLoggedWork`.
    var hasLoggedWork: Bool { get }
}

extension Workout: RecoverableWorkout {}

/// Decides what happens to in-progress workouts found at launch — the app was
/// force-quit or crashed mid-session, so nothing is tracking them anymore.
///
/// A session ends when the user finishes or discards it, not because the app
/// died: whatever was running is resumed as it was, however old it is. The only
/// thing thrown away is a scaffold with nothing logged in it that wasn't the one
/// adopted — a session with logged sets is never deleted, so if several survived,
/// the ones not adopted stay in the store and resurface in the Log.
enum WorkoutRecovery {

    struct Plan<W> {
        /// The workout to adopt as the active session, if any.
        var resume: W?
        /// Workouts to delete outright.
        var discard: [W]
    }

    /// Only one workout can be active: real work wins over an empty scaffold, and
    /// the most recently started wins among equals.
    static func plan<W: RecoverableWorkout>(for orphans: [W]) -> Plan<W> {
        let resume = orphans.max { lhs, rhs in
            if lhs.hasLoggedWork != rhs.hasLoggedWork { return rhs.hasLoggedWork }
            return lhs.startedAt < rhs.startedAt
        }

        return Plan(
            resume: resume,
            // Only ever delete empties — anything logged is left alone.
            discard: orphans.filter { $0.id != resume?.id && !$0.hasLoggedWork }
        )
    }
}
