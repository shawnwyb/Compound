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

    // MARK: - Per-group breakdown

    /// Volume and completed-set counts grouped by muscle group, highest volume first.
    static func groupBreakdown(in workouts: [StatsWorkout]) -> [GroupVolume] {
        struct Acc {
            var groupID: UUID?
            var groupName: String
            var volume: Double = 0
            var setCount: Int = 0
        }

        var byKey: [String: Acc] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                let key = exercise.groupID?.uuidString ?? "uncategorized:\(exercise.groupName)"
                var acc = byKey[key] ?? Acc(groupID: exercise.groupID, groupName: exercise.groupName)
                for set in exercise.sets where set.completed {
                    acc.volume += Double(set.reps) * set.weight
                    acc.setCount += 1
                }
                byKey[key] = acc
            }
        }

        return byKey.values
            .filter { $0.setCount > 0 || $0.volume > 0 }
            .map { GroupVolume(groupID: $0.groupID, groupName: $0.groupName, volume: $0.volume, setCount: $0.setCount) }
            .sorted {
                if $0.volume != $1.volume { return $0.volume > $1.volume }
                return $0.groupName.localizedCaseInsensitiveCompare($1.groupName) == .orderedAscending
            }
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

    /// Best completed weight and best estimated 1RM per exercise, sorted by 1RM desc.
    static func personalRecords(in workouts: [StatsWorkout]) -> [PersonalRecord] {
        struct Acc {
            var name: String
            var bestWeight: Double = 0
            var bestWeightDate: Date = .distantPast
            var bestE1RM: Double = 0
        }

        var byExercise: [UUID: Acc] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                var acc = byExercise[exercise.exerciseID] ?? Acc(name: exercise.exerciseName)
                for set in exercise.sets where set.completed && set.reps > 0 && set.weight > 0 {
                    acc.name = exercise.exerciseName
                    if set.weight > acc.bestWeight {
                        acc.bestWeight = set.weight
                        acc.bestWeightDate = workout.date
                    }
                    let e1rm = estimatedOneRepMax(weight: set.weight, reps: set.reps)
                    if e1rm > acc.bestE1RM {
                        acc.bestE1RM = e1rm
                    }
                }
                byExercise[exercise.exerciseID] = acc
            }
        }

        return byExercise.compactMap { id, acc in
            guard acc.bestWeight > 0 else { return nil }
            return PersonalRecord(
                exerciseID: id,
                exerciseName: acc.name,
                bestWeight: acc.bestWeight,
                estimatedOneRepMax: acc.bestE1RM,
                bestWeightDate: acc.bestWeightDate
            )
        }
        .sorted {
            if $0.estimatedOneRepMax != $1.estimatedOneRepMax {
                return $0.estimatedOneRepMax > $1.estimatedOneRepMax
            }
            return $0.exerciseName.localizedCaseInsensitiveCompare($1.exerciseName) == .orderedAscending
        }
    }

    // MARK: - Time series

    /// Session counts per calendar day, oldest → newest.
    static func workoutsPerDay(
        in workouts: [StatsWorkout],
        calendar: Calendar = .current
    ) -> [DailyWorkoutCount] {
        var counts: [Date: Int] = [:]
        for workout in workouts {
            let day = startOfDay(workout.date, calendar: calendar)
            counts[day, default: 0] += 1
        }
        return counts.keys.sorted().map { DailyWorkoutCount(day: $0, count: counts[$0]!) }
    }

    /// Completed-set volume per calendar day, oldest → newest.
    static func volumePerDay(
        in workouts: [StatsWorkout],
        calendar: Calendar = .current
    ) -> [DailyVolume] {
        var volumes: [Date: Double] = [:]
        for workout in workouts {
            let day = startOfDay(workout.date, calendar: calendar)
            volumes[day, default: 0] += volume(of: workout)
        }
        return volumes.keys.sorted().map { DailyVolume(day: $0, volume: volumes[$0]!) }
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
