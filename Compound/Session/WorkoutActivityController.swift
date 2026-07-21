import ActivityKit
import Foundation

/// Owns the workout Live Activity. All ActivityKit contact is funnelled through
/// here so `ActiveWorkout` stays a plain session controller, and so a device with
/// Live Activities switched off just gets no-ops instead of scattered guards.
///
/// Every method is a no-op when activities are unavailable or none is running —
/// callers never have to check first.
final class WorkoutActivityController {

    private var activity: Activity<WorkoutActivityAttributes>?

    /// Live Activities are a system setting the user can switch off per app.
    private var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Request an activity for a session that just started (or was resumed after a
    /// crash). Any activity still around from a previous launch is ended first —
    /// there is only ever one workout.
    func start(workoutName: String, startedAt: Date, state: WorkoutActivityAttributes.ContentState) {
        endAll()
        guard isAvailable else { return }
        activity = try? Activity.request(
            attributes: WorkoutActivityAttributes(workoutName: workoutName, startedAt: startedAt),
            content: content(for: state, startedAt: startedAt),
            pushType: nil
        )
    }

    /// Push new content. Called only on real state changes — set completion, rest
    /// start/stop/adjust — never per keystroke.
    func update(_ state: WorkoutActivityAttributes.ContentState, startedAt: Date) {
        guard let activity else { return }
        let content = content(for: state, startedAt: startedAt)
        Task { await activity.update(content) }
    }

    /// End the running activity (Finish or Discard).
    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    /// End every workout activity the system still knows about, including ones
    /// orphaned by a crash or force-quit that this process never requested.
    func endAll() {
        activity = nil
        for stale in Activity<WorkoutActivityAttributes>.activities {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// `staleDate` tells the system when the content stops being trustworthy: just
    /// past the end of a rest, otherwise the 8h cap on a plausible session. The
    /// app can't tick timers while suspended, so this is what stops a forgotten
    /// activity from displaying stale numbers forever.
    private func content(
        for state: WorkoutActivityAttributes.ContentState,
        startedAt: Date
    ) -> ActivityContent<WorkoutActivityAttributes.ContentState> {
        let staleDate = state.restEndsAt.map { $0.addingTimeInterval(60) }
            ?? startedAt.addingTimeInterval(8 * 60 * 60)
        return ActivityContent(state: state, staleDate: staleDate)
    }
}
