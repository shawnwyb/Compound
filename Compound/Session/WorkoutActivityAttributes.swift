import ActivityKit
import Foundation

/// The contract between the app and the Live Activity widget. Shared by both
/// targets, so it stays plain values — **never import SwiftData here**: the
/// widget extension must not link the model layer, and `ContentState` has to be
/// `Codable` to cross the process boundary.
///
/// Both timers are carried as `Date`s rather than counts so the widget can render
/// them with `Text(timerInterval:)` and let iOS tick them while the app is
/// suspended (see §10 decisions 1 and 3 of the transition plan).
struct WorkoutActivityAttributes: ActivityAttributes {

    /// Fixed for the life of the session.
    let workoutName: String
    /// Start of the session — drives the elapsed-time display.
    let startedAt: Date

    /// Pushed on set / rest / exercise changes only, never per keystroke.
    struct ContentState: Codable, Hashable {
        /// Exercise currently being worked.
        var exerciseName: String
        /// 1-based position of the current set within `setCount`.
        var setIndex: Int
        /// Sets in the current exercise.
        var setCount: Int
        /// When the running rest timer ends, or `nil` when no rest is running.
        var restEndsAt: Date?

        var isResting: Bool { restEndsAt != nil }
    }
}
