import Foundation

/// What a workout needs to expose for launch recovery. Kept as a protocol so the
/// decision itself is testable without a `ModelContainer`.
protocol RecoverableWorkout {
    var id: UUID { get }
    var startedAt: Date { get }
    var completedSetCount: Int { get }
}

extension Workout: RecoverableWorkout {}

/// Decides what happens to in-progress workouts found at launch — the app was
/// force-quit or crashed mid-session, so nothing is tracking them anymore.
///
/// A workout with logged sets is real work and is resumed (adopted, minimized)
/// rather than deleted; one with nothing completed is just the routine's seeded
/// scaffold and is thrown away so it doesn't linger with a running timer.
enum WorkoutRecovery {

    struct Plan<W> {
        /// The workout to adopt as the active session, if any.
        var resume: W?
        /// Workouts to delete outright.
        var discard: [W]
    }

    /// Only one workout can be active, so if several survived, the most recently
    /// started one wins and the rest are discarded.
    static func plan<W: RecoverableWorkout>(for orphans: [W]) -> Plan<W> {
        let resume = orphans
            .filter { $0.completedSetCount > 0 }
            .max { $0.startedAt < $1.startedAt }

        return Plan(
            resume: resume,
            discard: orphans.filter { $0.id != resume?.id }
        )
    }
}
