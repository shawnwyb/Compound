import Foundation

/// Everything the Stats screen shows, derived in one pass over the store.
///
/// Each of these used to be a computed property on `StatsView`, so a single
/// `body` evaluation re-derived them roughly a dozen times — `snapshot` alone
/// was rebuilt for `tracked`, `totals`, `streak`, the resolved selection, and
/// each series, and every rebuild faulted every workout's exercises and sets
/// back in from SwiftData. Tapping a segmented control paid for all of it.
///
/// Build this *outside* `body` and hold it in `@State`. Bridging SwiftData
/// models into plain values reads `reps`/`weight`/`completed` on every set in
/// the store, and any such read performed during a `body` evaluation makes the
/// view a dependent of every one of those objects — after which each keystroke
/// in a live workout invalidates the Stats screen and rebuilds all of this.
/// Measured on a 400-session store: ~95ms a rebuild, two to three rebuilds per
/// typed character, on the main actor, with the tab off screen.
///
/// It still has to be built on the main actor (models are not `Sendable`);
/// everything after the bridge operates on value types and is cheap.
struct StatsDigest {
    /// Finished sessions as plain values — the input to every calculation below.
    let snapshot: [StatsWorkout]
    let bodyData: [BodyPoint]
    let tracked: [TrackedExercise]
    /// The one total the Overview shows. The rest of `StatsCalculator.totals` —
    /// volume, completed sets, training days — was computed on every render and
    /// never displayed; two of those are full walks of every set.
    let workoutCount: Int
    let streak: StreakStats
    /// Body metrics with at least one logged value, so the Body section can be
    /// hidden without running each metric's series to find out.
    let bodyMetricsWithData: Set<BodyMetric>
    /// The one "now" the whole screen is measured from. The streak's idea of
    /// today and the charts' trailing windows have to be the same day, and they
    /// aren't if each reads the clock when it happens to run. It's also what
    /// tells the view its numbers have outlived the day they were built on.
    let builtAt: Date
    /// Held so the trailing-window filters below measure from the same calendar
    /// as the streak did.
    private let calendar: Calendar

    init(
        workouts: [Workout],
        entries: [DailyEntry],
        calendar: Calendar = .current,
        now: Date = .now
    ) {
        builtAt = now
        // In-progress sessions (`isInProgress`) never contribute to totals,
        // streaks, PRs, or charts.
        snapshot = StatsSnapshot.from(workouts.filter { !$0.isInProgress })
        bodyData = entries.map {
            BodyPoint(date: $0.date, bodyWeight: $0.bodyWeight, calories: $0.calories, protein: $0.protein)
        }
        tracked = StatsCalculator.trackedExercises(in: snapshot)
        workoutCount = snapshot.count
        streak = StatsCalculator.streak(in: snapshot, calendar: calendar, now: now)
        self.calendar = calendar

        var logged: Set<BodyMetric> = []
        for point in bodyData {
            if point.bodyWeight != nil { logged.insert(.bodyWeight) }
            if point.calories != nil { logged.insert(.calories) }
            if point.protein != nil { logged.insert(.protein) }
        }
        bodyMetricsWithData = logged
    }

    /// What the screen shows before its first build — a blank frame, not the
    /// "No Stats Yet" empty state, which would flash on the way in.
    static let empty = StatsDigest(workouts: [], entries: [])

    var hasFinishedWorkouts: Bool { !snapshot.isEmpty }
    var hasAnyExercise: Bool { !tracked.isEmpty }
    var hasAnyBody: Bool { !bodyMetricsWithData.isEmpty }
    var hasAnyData: Bool { hasAnyExercise || hasAnyBody }

    /// The chosen exercise, defaulting to the most recent and healing if a
    /// previously chosen exercise no longer exists.
    func resolvedExerciseID(selection: UUID?) -> UUID? {
        if let selection, tracked.contains(where: { $0.id == selection }) { return selection }
        return tracked.first?.id
    }

    /// The chosen body metric, defaulting to the first one that has data.
    func resolvedBodyMetric(selection: BodyMetric?) -> BodyMetric {
        if let selection { return selection }
        return BodyMetric.allCases.first { bodyMetricsWithData.contains($0) } ?? .bodyWeight
    }

    /// These run per render, so they take their "now" from the digest rather
    /// than the clock — otherwise the window the chart draws and the streak
    /// beside it can end up on different days.
    func liftsPoints(exerciseID: UUID?, metric: ExerciseMetric, range: StatsRange) -> [SeriesPoint] {
        guard let exerciseID else { return [] }
        let all = StatsCalculator.exerciseSeries(
            exerciseID: exerciseID, metric: metric, in: snapshot, calendar: calendar
        )
        return StatsCalculator.filter(all, range: range, now: builtAt, calendar: calendar)
    }

    func bodyPoints(metric: BodyMetric, range: StatsRange) -> [SeriesPoint] {
        let all = StatsCalculator.bodySeries(metric: metric, in: bodyData, calendar: calendar)
        return StatsCalculator.filter(all, range: range, now: builtAt, calendar: calendar)
    }
}
