import Foundation

/// Pure stats calculations over plain `StatsWorkout` values.
enum StatsCalculator {

    // MARK: - Volume

    /// Σ (reps × weight) over completed sets across all workouts.
    static func totalVolume(in workouts: [StatsWorkout]) -> Double {
        workouts.reduce(0) { $0 + volume(of: $1) }
    }

    /// Σ (reps × weight) over completed sets in one workout.
    static func volume(of workout: StatsWorkout) -> Double {
        workout.exercises.reduce(0) { partial, exercise in
            partial + exercise.sets
                .filter(\.completed)
                .reduce(0) { $0 + Double($1.reps) * $1.weight }
        }
    }

    // MARK: - Totals

    static func totals(
        in workouts: [StatsWorkout],
        calendar: Calendar = .current
    ) -> StatsTotals {
        let completedSets = workouts.reduce(0) { count, workout in
            count + workout.exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        }
        return StatsTotals(
            workoutCount: workouts.count,
            totalVolume: totalVolume(in: workouts),
            completedSetCount: completedSets,
            trainingDayCount: uniqueDays(in: workouts, calendar: calendar).count
        )
    }

    // MARK: - Streaks / frequency

    /// Current and longest consecutive training-day streaks, plus recent day counts.
    ///
    /// Current streak counts backward from today if trained today; otherwise from
    /// yesterday if trained yesterday (so a rest day today does not zero a streak).
    /// Otherwise current is 0.
    static func streak(
        in workouts: [StatsWorkout],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> StreakStats {
        let days = Set(uniqueDays(in: workouts, calendar: calendar))
        let today = startOfDay(now, calendar: calendar)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let current: Int
        if days.contains(today) {
            current = consecutiveCount(endingAt: today, in: days, calendar: calendar)
        } else if days.contains(yesterday) {
            current = consecutiveCount(endingAt: yesterday, in: days, calendar: calendar)
        } else {
            current = 0
        }

        let longest = longestStreak(in: days, calendar: calendar)
        let daysLast7 = daysInWindow(days, endingAt: today, length: 7, calendar: calendar)
        let daysLast30 = daysInWindow(days, endingAt: today, length: 30, calendar: calendar)

        return StreakStats(
            current: current,
            longest: longest,
            daysLast7: daysLast7,
            daysLast30: daysLast30
        )
    }

    // MARK: - Personal records / est. 1RM

    /// Epley estimated 1RM: `weight × (1 + reps/30)`. For `reps <= 1`, returns `weight`.
    /// Non-positive weight or reps yield 0.
    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30)
    }

    // MARK: - Progression series

    /// Exercises with at least one completed, weighted set — most recently
    /// performed first (ties broken by name). Drives the metric picker.
    static func trackedExercises(in workouts: [StatsWorkout]) -> [TrackedExercise] {
        struct Acc {
            var name: String
            var lastPerformed: Date
        }

        var byID: [UUID: Acc] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                let hasWork = exercise.sets.contains { $0.completed && $0.weight > 0 && $0.reps > 0 }
                guard hasWork else { continue }
                if var acc = byID[exercise.exerciseID] {
                    // The name comes from the most recent performance, not from
                    // whichever workout this loop happens to see last.
                    // `exerciseName` is a per-workout snapshot, so taking the
                    // last one made the answer depend on the order the caller
                    // passed its workouts in — an order decided by a `@Query`
                    // sort in another file, with nothing here to notice if it
                    // changed. Compared before `lastPerformed` moves.
                    if workout.date > acc.lastPerformed { acc.name = exercise.exerciseName }
                    acc.lastPerformed = max(acc.lastPerformed, workout.date)
                    byID[exercise.exerciseID] = acc
                } else {
                    byID[exercise.exerciseID] = Acc(name: exercise.exerciseName, lastPerformed: workout.date)
                }
            }
        }

        return byID.map { TrackedExercise(id: $0.key, name: $0.value.name, lastPerformed: $0.value.lastPerformed) }
            .sorted {
                if $0.lastPerformed != $1.lastPerformed { return $0.lastPerformed > $1.lastPerformed }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    /// One point per training day for a single exercise's chosen metric,
    /// oldest → newest. Only completed, weighted sets contribute. When an
    /// exercise is performed more than once in a day, weight/1RM metrics keep the
    /// best value and volume sums.
    static func exerciseSeries(
        exerciseID: UUID,
        metric: ExerciseMetric,
        in workouts: [StatsWorkout],
        calendar: Calendar = .current
    ) -> [SeriesPoint] {
        var byDay: [Date: Double] = [:]
        for workout in workouts {
            let day = startOfDay(workout.date, calendar: calendar)
            for exercise in workout.exercises where exercise.exerciseID == exerciseID {
                let sets = exercise.sets.filter { $0.completed && $0.weight > 0 && $0.reps > 0 }
                guard !sets.isEmpty else { continue }
                switch metric {
                case .topSetWeight:
                    let best = sets.map(\.weight).max() ?? 0
                    byDay[day] = max(byDay[day] ?? 0, best)
                case .estimatedOneRepMax:
                    let best = sets.map { estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
                    byDay[day] = max(byDay[day] ?? 0, best)
                case .volume:
                    let total = sets.reduce(0) { $0 + Double($1.reps) * $1.weight }
                    byDay[day, default: 0] += total
                }
            }
        }
        return byDay.keys.sorted().map { SeriesPoint(date: $0, value: byDay[$0]!) }
    }

    /// One point per logged day for a body metric, oldest → newest. Days missing
    /// the metric are skipped; a day logged more than once keeps the last value.
    static func bodySeries(
        metric: BodyMetric,
        in entries: [BodyPoint],
        calendar: Calendar = .current
    ) -> [SeriesPoint] {
        var byDay: [Date: Double] = [:]
        for entry in entries {
            let value: Double?
            switch metric {
            case .bodyWeight: value = entry.bodyWeight
            case .calories: value = entry.calories.map(Double.init)
            case .protein: value = entry.protein.map(Double.init)
            }
            if let value {
                byDay[startOfDay(entry.date, calendar: calendar)] = value
            }
        }
        return byDay.keys.sorted().map { SeriesPoint(date: $0, value: byDay[$0]!) }
    }

    /// Trailing-window filter: keeps points on/after `now − range.days` (inclusive
    /// of both ends). Assumes `points` is sorted ascending.
    static func filter(
        _ points: [SeriesPoint],
        range: StatsRange,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [SeriesPoint] {
        guard let days = range.days else { return points }
        let today = startOfDay(now, calendar: calendar)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return points }
        return points.filter { $0.date >= start }
    }

    /// Latest value, best value, and net change across a series.
    static func summary(of points: [SeriesPoint]) -> SeriesSummary {
        guard let first = points.first, let last = points.last else {
            return SeriesSummary(latest: nil, best: nil, change: nil, pointCount: 0)
        }
        return SeriesSummary(
            latest: last.value,
            best: points.map(\.value).max(),
            change: last.value - first.value,
            pointCount: points.count
        )
    }

    // MARK: - Helpers

    static func uniqueDays(in workouts: [StatsWorkout], calendar: Calendar) -> [Date] {
        let days = Set(workouts.map { startOfDay($0.date, calendar: calendar) })
        return days.sorted()
    }

    static func startOfDay(_ date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }

    private static func consecutiveCount(endingAt end: Date, in days: Set<Date>, calendar: Calendar) -> Int {
        var count = 0
        var cursor = end
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private static func longestStreak(in days: Set<Date>, calendar: Calendar) -> Int {
        let sorted = days.sorted()
        guard let first = sorted.first else { return 0 }
        var best = 1
        var run = 1
        var previous = first
        for day in sorted.dropFirst() {
            let expected = calendar.date(byAdding: .day, value: 1, to: previous)
            if expected == day {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
            previous = day
        }
        return best
    }

    private static func daysInWindow(
        _ days: Set<Date>,
        endingAt end: Date,
        length: Int,
        calendar: Calendar
    ) -> Int {
        guard length > 0 else { return 0 }
        guard let start = calendar.date(byAdding: .day, value: -(length - 1), to: end) else { return 0 }
        return days.filter { $0 >= start && $0 <= end }.count
    }
}
