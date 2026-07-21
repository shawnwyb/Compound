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

    /// Set by Discard; the workout to delete once the live screen has fully
    /// dismissed. Deleting earlier faults SwiftData because the dismissing view
    /// is still rendering the workout's set rows.
    var pendingDeletion: Workout?

    var isActive: Bool { workout != nil }

    /// Begin a freshly-started (already persisted) workout, shown full-screen.
    func start(_ workout: Workout) {
        self.workout = workout
        isMinimized = false
        rest.stop()
    }

    func minimize() { isMinimized = true }
    func maximize() { isMinimized = false }

    /// Clear the active workout (after Finish). Does not touch the store — the
    /// `Workout` stays saved as a finished session.
    func end() {
        workout = nil
        isMinimized = false
        rest.stop()
    }

    /// Dismiss the live screen and mark its workout for deletion once the screen
    /// is gone (the root does the actual delete in the cover's `onDismiss`).
    func requestDiscard() {
        pendingDeletion = workout
        end()
    }
}
