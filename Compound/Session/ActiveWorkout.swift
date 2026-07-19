import Foundation
import Observation

/// Root-owned controller for the one in-progress workout. Owning it above the tab
/// bar is what lets the workout survive minimize and tab switches — the live
/// screen is presented from the root, not from a screen that can be popped.
@Observable
final class ActiveWorkout {
    /// The live workout, or `nil` when none is running.
    private(set) var workout: Workout?
    /// Collapsed to the mini-bar (still running) vs. shown full-screen.
    var isMinimized = false
    /// The rest timer lives here so it keeps counting while minimized.
    let rest = RestTimer()

    var isActive: Bool { workout != nil }

    /// Begin a freshly-started (already persisted) workout, shown full-screen.
    func start(_ workout: Workout) {
        self.workout = workout
        isMinimized = false
        rest.stop()
    }

    func minimize() { isMinimized = true }
    func maximize() { isMinimized = false }

    /// Clear the active workout (after Finish or Discard). Does not touch the
    /// store — the caller decides whether the `Workout` was saved or deleted.
    func end() {
        workout = nil
        isMinimized = false
        rest.stop()
    }
}
