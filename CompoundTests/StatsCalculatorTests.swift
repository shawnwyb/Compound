import XCTest
@testable import Compound

final class StatsCalculatorTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private let chest = UUID()
    private let back = UUID()
    private let bench = UUID()
    private let row = UUID()

    private func set(_ reps: Int, _ weight: Double, completed: Bool = true) -> StatsSet {
        StatsSet(reps: reps, weight: weight, completed: completed)
    }

    private func workout(
        id: UUID = UUID(),
        on date: Date,
        exercises: [StatsExercise]
    ) -> StatsWorkout {
        StatsWorkout(id: id, date: date, exercises: exercises)
    }

    private func exercise(
        id: UUID,
        name: String,
        groupID: UUID?,
        group: String,
        sets: [StatsSet]
    ) -> StatsExercise {
        StatsExercise(
            exerciseID: id,
            exerciseName: name,
            groupID: groupID,
            groupName: group,
            sets: sets
        )
    }

    // MARK: - Volume

    func testTotalVolumeEmpty() {
        XCTAssertEqual(StatsCalculator.totalVolume(in: []), 0)
    }

    func testVolumeUsesOnlyCompletedSets() {
        let w = workout(on: day(2026, 7, 1), exercises: [
            exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [
                set(10, 100),           // 1000
                set(8, 100, completed: false), // ignored
                set(5, 120),            // 600
            ])
        ])
        XCTAssertEqual(StatsCalculator.volume(of: w), 1600)
        XCTAssertEqual(StatsCalculator.totalVolume(in: [w]), 1600)
    }

    func testTotalsAggregateWorkoutsSetsAndDays() {
        let a = workout(on: day(2026, 7, 1, hour: 9), exercises: [
            exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [set(5, 100)])
        ])
        let b = workout(on: day(2026, 7, 1, hour: 18), exercises: [
            exercise(id: row, name: "Row", groupID: back, group: "Back", sets: [
                set(10, 50),
                set(10, 50, completed: false),
            ])
        ])
        let c = workout(on: day(2026, 7, 2), exercises: [
            exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [set(3, 100)])
        ])

        let totals = StatsCalculator.totals(in: [a, b, c], calendar: calendar)
        XCTAssertEqual(totals.workoutCount, 3)
        XCTAssertEqual(totals.completedSetCount, 3)
        XCTAssertEqual(totals.trainingDayCount, 2)
        XCTAssertEqual(totals.totalVolume, 500 + 500 + 300)
    }

    // MARK: - Est. 1RM

    func testEstimatedOneRepMaxEpley() {
        XCTAssertEqual(StatsCalculator.estimatedOneRepMax(weight: 100, reps: 1), 100)
        XCTAssertEqual(StatsCalculator.estimatedOneRepMax(weight: 100, reps: 10), 100 * (1 + 10.0 / 30), accuracy: 0.0001)
        XCTAssertEqual(StatsCalculator.estimatedOneRepMax(weight: 0, reps: 10), 0)
        XCTAssertEqual(StatsCalculator.estimatedOneRepMax(weight: 100, reps: 0), 0)
    }

    // MARK: - Streaks

    func testStreakEmpty() {
        let streak = StatsCalculator.streak(in: [], calendar: calendar, now: day(2026, 7, 10))
        XCTAssertEqual(streak.current, 0)
        XCTAssertEqual(streak.longest, 0)
        XCTAssertEqual(streak.daysLast7, 0)
        XCTAssertEqual(streak.daysLast30, 0)
    }

    func testCurrentStreakFromToday() {
        let workouts = [
            workout(on: day(2026, 7, 8), exercises: []),
            workout(on: day(2026, 7, 9), exercises: []),
            workout(on: day(2026, 7, 10), exercises: []),
        ]
        let streak = StatsCalculator.streak(in: workouts, calendar: calendar, now: day(2026, 7, 10))
        XCTAssertEqual(streak.current, 3)
        XCTAssertEqual(streak.longest, 3)
    }

    func testCurrentStreakAllowsRestTodayIfYesterdayTrained() {
        let workouts = [
            workout(on: day(2026, 7, 8), exercises: []),
            workout(on: day(2026, 7, 9), exercises: []),
        ]
        let streak = StatsCalculator.streak(in: workouts, calendar: calendar, now: day(2026, 7, 10))
        XCTAssertEqual(streak.current, 2)
    }

    func testCurrentStreakZeroWhenGapBeforeYesterday() {
        let workouts = [
            workout(on: day(2026, 7, 7), exercises: []),
        ]
        let streak = StatsCalculator.streak(in: workouts, calendar: calendar, now: day(2026, 7, 10))
        XCTAssertEqual(streak.current, 0)
        XCTAssertEqual(streak.longest, 1)
    }

    func testLongestStreakAcrossGaps() {
        let workouts = [
            workout(on: day(2026, 7, 1), exercises: []),
            workout(on: day(2026, 7, 2), exercises: []),
            workout(on: day(2026, 7, 3), exercises: []),
            // gap
            workout(on: day(2026, 7, 5), exercises: []),
            workout(on: day(2026, 7, 6), exercises: []),
        ]
        let streak = StatsCalculator.streak(in: workouts, calendar: calendar, now: day(2026, 7, 10))
        XCTAssertEqual(streak.longest, 3)
        XCTAssertEqual(streak.current, 0)
    }

    func testMultipleWorkoutsSameDayCountOnceForStreak() {
        let workouts = [
            workout(on: day(2026, 7, 9, hour: 9), exercises: []),
            workout(on: day(2026, 7, 9, hour: 18), exercises: []),
            workout(on: day(2026, 7, 10, hour: 9), exercises: []),
        ]
        let streak = StatsCalculator.streak(in: workouts, calendar: calendar, now: day(2026, 7, 10))
        XCTAssertEqual(streak.current, 2)
        XCTAssertEqual(streak.longest, 2)
    }

    func testFrequencyWindows() {
        // today = Jul 10; last 7 = Jul 4...10; last 30 = Jun 11...Jul 10
        let workouts = [
            workout(on: day(2026, 6, 1), exercises: []),   // outside 30
            workout(on: day(2026, 6, 20), exercises: []),  // in 30
            workout(on: day(2026, 7, 5), exercises: []),   // in 7 and 30
            workout(on: day(2026, 7, 9), exercises: []),   // in 7 and 30
            workout(on: day(2026, 7, 10), exercises: []),  // in 7 and 30
        ]
        let streak = StatsCalculator.streak(in: workouts, calendar: calendar, now: day(2026, 7, 10))
        XCTAssertEqual(streak.daysLast7, 3)
        XCTAssertEqual(streak.daysLast30, 4)
    }

    // MARK: - Tracked exercises

    func testTrackedExercisesMostRecentFirst() {
        let workouts = [
            workout(on: day(2026, 7, 1), exercises: [
                exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [set(5, 100)])
            ]),
            workout(on: day(2026, 7, 5), exercises: [
                exercise(id: row, name: "Row", groupID: back, group: "Back", sets: [set(5, 60)])
            ]),
        ]
        let tracked = StatsCalculator.trackedExercises(in: workouts)
        XCTAssertEqual(tracked.map(\.id), [row, bench]) // Row performed more recently
        XCTAssertEqual(tracked.first?.lastPerformed, day(2026, 7, 5))
    }

    /// `exerciseName` is snapshotted per performance, so an exercise renamed
    /// between sessions has two names in history. The picker shows the newest —
    /// and says so no matter which order the workouts arrive in, since that
    /// order is set by a `@Query` sort this calculation can't see.
    func testTrackedExerciseTakesItsNameFromTheMostRecentPerformance() {
        let old = workout(on: day(2026, 7, 1), exercises: [
            exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [set(5, 100)])
        ])
        let recent = workout(on: day(2026, 7, 5), exercises: [
            exercise(id: bench, name: "Barbell Bench Press", groupID: chest, group: "Chest", sets: [set(5, 105)])
        ])
        for workouts in [[recent, old], [old, recent]] {
            let tracked = StatsCalculator.trackedExercises(in: workouts)
            XCTAssertEqual(tracked.map(\.name), ["Barbell Bench Press"])
            XCTAssertEqual(tracked.first?.lastPerformed, day(2026, 7, 5))
        }
    }

    func testTrackedExercisesSkipsExercisesWithoutCompletedWeight() {
        let workouts = [
            workout(on: day(2026, 7, 1), exercises: [
                exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [
                    set(5, 100, completed: false), set(0, 0),
                ])
            ]),
        ]
        XCTAssertTrue(StatsCalculator.trackedExercises(in: workouts).isEmpty)
    }

    // MARK: - Exercise series

    func testExerciseSeriesTopSetWeight() {
        let workouts = [
            workout(on: day(2026, 7, 3), exercises: [
                exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [
                    set(8, 135), set(5, 145), set(3, 155),
                ])
            ]),
            workout(on: day(2026, 7, 1), exercises: [
                exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [
                    set(8, 130), set(5, 140),
                ])
            ]),
        ]
        let series = StatsCalculator.exerciseSeries(
            exerciseID: bench, metric: .topSetWeight, in: workouts, calendar: calendar
        )
        // Sorted oldest → newest; each day is the heaviest completed set.
        XCTAssertEqual(series.map(\.value), [140, 155])
        XCTAssertEqual(series[0].date, calendar.startOfDay(for: day(2026, 7, 1)))
        XCTAssertEqual(series[1].date, calendar.startOfDay(for: day(2026, 7, 3)))
    }

    func testExerciseSeriesEstimatedOneRepMaxUsesBestSet() {
        let w = workout(on: day(2026, 7, 1), exercises: [
            exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [
                set(10, 100), // e1rm ≈ 133.33
                set(1, 130),  // e1rm = 130
            ])
        ])
        let series = StatsCalculator.exerciseSeries(
            exerciseID: bench, metric: .estimatedOneRepMax, in: [w], calendar: calendar
        )
        XCTAssertEqual(series.count, 1)
        XCTAssertEqual(series[0].value, 100 * (1 + 10.0 / 30), accuracy: 0.0001)
    }

    func testExerciseSeriesVolumeSumsCompletedAndIgnoresOthers() {
        let w = workout(on: day(2026, 7, 1), exercises: [
            exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [
                set(10, 100),               // 1000
                set(5, 120),                // 600
                set(5, 200, completed: false), // ignored
            ])
        ])
        let series = StatsCalculator.exerciseSeries(
            exerciseID: bench, metric: .volume, in: [w], calendar: calendar
        )
        XCTAssertEqual(series.map(\.value), [1600])
    }

    func testExerciseSeriesSameDayWeightKeepsBestVolumeSums() {
        let workouts = [
            workout(on: day(2026, 7, 1, hour: 9), exercises: [
                exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [set(5, 140)])
            ]),
            workout(on: day(2026, 7, 1, hour: 18), exercises: [
                exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [set(5, 150)])
            ]),
        ]
        let topSet = StatsCalculator.exerciseSeries(
            exerciseID: bench, metric: .topSetWeight, in: workouts, calendar: calendar
        )
        XCTAssertEqual(topSet.map(\.value), [150]) // best of the day

        let volume = StatsCalculator.exerciseSeries(
            exerciseID: bench, metric: .volume, in: workouts, calendar: calendar
        )
        XCTAssertEqual(volume.map(\.value), [1450]) // 5×140 + 5×150, summed
    }

    func testExerciseSeriesFiltersToRequestedExercise() {
        let w = workout(on: day(2026, 7, 1), exercises: [
            exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [set(5, 100)]),
            exercise(id: row, name: "Row", groupID: back, group: "Back", sets: [set(5, 200)]),
        ])
        let series = StatsCalculator.exerciseSeries(
            exerciseID: bench, metric: .topSetWeight, in: [w], calendar: calendar
        )
        XCTAssertEqual(series.map(\.value), [100])
    }

    // MARK: - Body series

    func testBodySeriesSkipsMissingValuesAndSorts() {
        let entries = [
            BodyPoint(date: day(2026, 7, 3), bodyWeight: 184, calories: nil, protein: 160),
            BodyPoint(date: day(2026, 7, 1), bodyWeight: 185, calories: 2000, protein: nil),
            BodyPoint(date: day(2026, 7, 2), bodyWeight: nil, calories: 2100, protein: 150),
        ]
        let weight = StatsCalculator.bodySeries(metric: .bodyWeight, in: entries, calendar: calendar)
        XCTAssertEqual(weight.map(\.value), [185, 184]) // Jul 2 skipped, sorted

        let calories = StatsCalculator.bodySeries(metric: .calories, in: entries, calendar: calendar)
        XCTAssertEqual(calories.map(\.value), [2000, 2100]) // Jul 3 skipped
    }

    // MARK: - Range filter

    func testFilterTrailingWindowInclusive() {
        let points = [
            SeriesPoint(date: day(2026, 6, 1), value: 1),
            SeriesPoint(date: day(2026, 6, 11), value: 2), // exactly 30 days before Jul 10
            SeriesPoint(date: day(2026, 7, 5), value: 3),
            SeriesPoint(date: day(2026, 7, 10), value: 4),
        ]
        let filtered = StatsCalculator.filter(
            points, range: .month1, now: day(2026, 7, 10), calendar: calendar
        )
        XCTAssertEqual(filtered.map(\.value), [2, 3, 4]) // Jun 1 dropped, Jun 11 kept
    }

    func testFilterAllKeepsEverything() {
        let points = [
            SeriesPoint(date: day(2020, 1, 1), value: 1),
            SeriesPoint(date: day(2026, 7, 10), value: 2),
        ]
        let filtered = StatsCalculator.filter(
            points, range: .all, now: day(2026, 7, 10), calendar: calendar
        )
        XCTAssertEqual(filtered.count, 2)
    }

    // MARK: - Summary

    func testSummaryEmpty() {
        let summary = StatsCalculator.summary(of: [])
        XCTAssertNil(summary.latest)
        XCTAssertNil(summary.best)
        XCTAssertNil(summary.change)
        XCTAssertEqual(summary.pointCount, 0)
    }

    func testSummaryLatestBestAndChange() {
        let points = [
            SeriesPoint(date: day(2026, 7, 1), value: 135),
            SeriesPoint(date: day(2026, 7, 3), value: 155),
            SeriesPoint(date: day(2026, 7, 5), value: 150),
        ]
        let summary = StatsCalculator.summary(of: points)
        XCTAssertEqual(summary.latest, 150)
        XCTAssertEqual(summary.best, 155)
        XCTAssertEqual(summary.change, 15) // 150 − 135
        XCTAssertEqual(summary.pointCount, 3)
    }
}
