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
    /// Mirrors the session onto the Lock Screen / Dynamic Island.
    private let activity = WorkoutActivityController()

    /// Set by Discard; the workout to delete once the live screen has fully
    /// dismissed. Deleting earlier faults SwiftData because the dismissing view
    /// is still rendering the workout's set rows.
    var pendingDeletion: Workout?

    var isActive: Bool { workout != nil }

    init() {
        // Rest changes are one of the two things the Live Activity cares about
        // (the other is set completion, pushed by the editor).
        rest.onChange = { [weak self] in self?.refreshActivity() }
    }

    /// Begin a freshly-started (already persisted) workout, shown full-screen.
    func start(_ workout: Workout) {
        self.workout = workout
        isMinimized = false
        rest.stop()
        startActivity()
    }

    /// Adopt an already-running workout that the app lost track of (crash or
    /// force-quit). Comes back collapsed to the mini-bar rather than full-screen,
    /// so relaunching doesn't drop the user into an editor they didn't ask for.
    func resume(_ workout: Workout) {
        self.workout = workout
        isMinimized = true
        rest.stop()
        startActivity()
    }

    /// No session survived the last launch — clear any activity the system is
    /// still showing from it.
    func discardStaleActivities() {
        activity.endAll()
    }

    func minimize() { isMinimized = true }
    func maximize() { isMinimized = false }

    /// Clear the active workout (after Finish). Does not touch the store — the
    /// `Workout` stays saved as a finished session.
    func end() {
        workout = nil
        isMinimized = false
        rest.stop()
        activity.end()
    }

    // MARK: - Live Activity

    /// Push the current position and rest state. Called on set completion (by the
    /// editor) and on every rest change (via `rest.onChange`) — never per
    /// keystroke, which would blow the update budget for no visible gain.
    func refreshActivity() {
        guard let workout, let state = currentActivityState() else { return }
        activity.update(state, startedAt: workout.startedAt)
    }

    private func startActivity() {
        guard let workout, let state = currentActivityState() else { return }
        activity.start(
            workoutName: workout.routineName.isEmpty ? "Workout" : workout.routineName,
            startedAt: workout.startedAt,
            state: state
        )
    }

    private func currentActivityState() -> WorkoutActivityAttributes.ContentState? {
        guard let workout, let position = workout.progressPosition else { return nil }
        return WorkoutActivityAttributes.ContentState(
            exerciseName: position.exerciseName,
            setIndex: position.setIndex,
            setCount: position.setCount,
            restEndsAt: rest.endDate
        )
    }

    /// Dismiss the live screen and mark its workout for deletion once the screen
    /// is gone (the root does the actual delete in the cover's `onDismiss`).
    func requestDiscard() {
        pendingDeletion = workout
        end()
    }
}
