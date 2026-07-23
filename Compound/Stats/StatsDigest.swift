import Foundation

/// Everything the Stats screen shows, derived in one pass over the store.
///
/// Each of these used to be a computed property on `StatsView`, so a single
/// `body` evaluation re-derived them roughly a dozen times — `snapshot` alone
/// was rebuilt for `tracked`, `totals`, `streak`, the resolved selection, and
/// each series, and every rebuild faulted every workout's exercises and sets
/// back in from SwiftData. Tapping a segmented control paid for all of it.
///
/// Nothing is cached across renders: the digest is rebuilt whenever `body`
/// runs, so the numbers stay exactly as fresh as before. Bridging SwiftData
/// models into plain values is the expensive half and has to stay on the main
/// actor (models are not `Sendable`); everything after it operates on value
/// types and is cheap.
struct StatsDigest {
    /// Finished sessions as plain values — the input to every calculation below.
    let snapshot: [StatsWorkout]
    let bodyData: [BodyPoint]
    let tracked: [TrackedExercise]
    let totals: StatsTotals
    let streak: StreakStats
    /// Body metrics with at least one logged value, so the Body section can be
    /// hidden without running each metric's series to find out.
    let bodyMetricsWithData: Set<BodyMetric>

    init(workouts: [Workout], entries: [DailyEntry], calendar: Calendar = .current) {
        // In-progress sessions (`isInProgress`) never contribute to totals,
        // streaks, PRs, or charts.
        snapshot = StatsSnapshot.from(workouts.filter { !$0.isInProgress })
        bodyData = entries.map {
            BodyPoint(date: $0.date, bodyWeight: $0.bodyWeight, calories: $0.calories, protein: $0.protein)
        }
        tracked = StatsCalculator.trackedExercises(in: snapshot)
        totals = StatsCalculator.totals(in: snapshot, calendar: calendar)
        streak = StatsCalculator.streak(in: snapshot, calendar: calendar)

        var logged: Set<BodyMetric> = []
        for point in bodyData {
            if point.bodyWeight != nil { logged.insert(.bodyWeight) }
            if point.calories != nil { logged.insert(.calories) }
            if point.protein != nil { logged.insert(.protein) }
        }
        bodyMetricsWithData = logged
    }

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

    func liftsPoints(exerciseID: UUID?, metric: ExerciseMetric, range: StatsRange) -> [SeriesPoint] {
        guard let exerciseID else { return [] }
        let all = StatsCalculator.exerciseSeries(exerciseID: exerciseID, metric: metric, in: snapshot)
        return StatsCalculator.filter(all, range: range)
    }

    func bodyPoints(metric: BodyMetric, range: StatsRange) -> [SeriesPoint] {
        StatsCalculator.filter(StatsCalculator.bodySeries(metric: metric, in: bodyData), range: range)
    }
}
