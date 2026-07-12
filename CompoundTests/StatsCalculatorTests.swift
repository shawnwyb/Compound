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

    // MARK: - Group breakdown

    func testGroupBreakdownSumsVolumeAndSets() {
        let w = workout(on: day(2026, 7, 1), exercises: [
            exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [
                set(10, 100), set(5, 100, completed: false),
            ]),
            exercise(id: row, name: "Row", groupID: back, group: "Back", sets: [
                set(8, 50), set(8, 50),
            ]),
        ])

        let groups = StatsCalculator.groupBreakdown(in: [w])
        XCTAssertEqual(groups.map(\.groupName), ["Chest", "Back"]) // Chest 1000 > Back 800
        XCTAssertEqual(groups[0].volume, 1000)
        XCTAssertEqual(groups[0].setCount, 1)
        XCTAssertEqual(groups[1].volume, 800)
        XCTAssertEqual(groups[1].setCount, 2)
    }

    func testGroupBreakdownIgnoresGroupsWithNoCompletedWork() {
        let w = workout(on: day(2026, 7, 1), exercises: [
            exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [
                set(10, 100, completed: false),
            ])
        ])
        XCTAssertTrue(StatsCalculator.groupBreakdown(in: [w]).isEmpty)
    }

    func testUncategorizedGroupsTogether() {
        let w = workout(on: day(2026, 7, 1), exercises: [
            exercise(id: bench, name: "Bench", groupID: nil, group: "Uncategorized", sets: [set(5, 100)]),
            exercise(id: row, name: "Row", groupID: nil, group: "Uncategorized", sets: [set(5, 50)]),
        ])
        let groups = StatsCalculator.groupBreakdown(in: [w])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].groupName, "Uncategorized")
        XCTAssertEqual(groups[0].volume, 750)
        XCTAssertEqual(groups[0].setCount, 2)
    }

    // MARK: - Est. 1RM

    func testEstimatedOneRepMaxEpley() {
        XCTAssertEqual(StatsCalculator.estimatedOneRepMax(weight: 100, reps: 1), 100)
        XCTAssertEqual(StatsCalculator.estimatedOneRepMax(weight: 100, reps: 10), 100 * (1 + 10.0 / 30), accuracy: 0.0001)
        XCTAssertEqual(StatsCalculator.estimatedOneRepMax(weight: 0, reps: 10), 0)
        XCTAssertEqual(StatsCalculator.estimatedOneRepMax(weight: 100, reps: 0), 0)
    }

    // MARK: - Personal records

    func testPersonalRecordsPickBestWeightAndBestE1RM() {
        let lightForReps = workout(on: day(2026, 7, 1), exercises: [
            exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [
                set(10, 100), // e1rm ≈ 133.33
            ])
        ])
        let heavySingle = workout(on: day(2026, 7, 2), exercises: [
            exercise(id: bench, name: "Bench Press", groupID: chest, group: "Chest", sets: [
                set(1, 130), // weight wins; e1rm = 130
            ])
        ])
        let incomplete = workout(on: day(2026, 7, 3), exercises: [
            exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [
                set(1, 200, completed: false),
            ])
        ])

        let prs = StatsCalculator.personalRecords(in: [lightForReps, heavySingle, incomplete])
        XCTAssertEqual(prs.count, 1)
        XCTAssertEqual(prs[0].exerciseName, "Bench Press")
        XCTAssertEqual(prs[0].bestWeight, 130)
        XCTAssertEqual(prs[0].bestWeightDate, day(2026, 7, 2))
        XCTAssertEqual(prs[0].estimatedOneRepMax, 100 * (1 + 10.0 / 30), accuracy: 0.0001)
    }

    func testPersonalRecordsSortedByE1RM() {
        let w = workout(on: day(2026, 7, 1), exercises: [
            exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [set(1, 100)]),
            exercise(id: row, name: "Row", groupID: back, group: "Back", sets: [set(1, 150)]),
        ])
        let prs = StatsCalculator.personalRecords(in: [w])
        XCTAssertEqual(prs.map(\.exerciseName), ["Row", "Bench"])
    }

    func testPersonalRecordsSkipExercisesWithNoCompletedWeight() {
        let w = workout(on: day(2026, 7, 1), exercises: [
            exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [
                set(0, 0), set(5, 0), set(0, 100, completed: false),
            ])
        ])
        XCTAssertTrue(StatsCalculator.personalRecords(in: [w]).isEmpty)
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

    // MARK: - Time series

    func testWorkoutsPerDayCountsSessionsAndSorts() {
        let workouts = [
            workout(on: day(2026, 7, 2, hour: 18), exercises: []),
            workout(on: day(2026, 7, 1), exercises: []),
            workout(on: day(2026, 7, 2, hour: 9), exercises: []),
        ]
        let points = StatsCalculator.workoutsPerDay(in: workouts, calendar: calendar)
        XCTAssertEqual(points.map(\.count), [1, 2])
        XCTAssertEqual(points[0].day, calendar.startOfDay(for: day(2026, 7, 1)))
        XCTAssertEqual(points[1].day, calendar.startOfDay(for: day(2026, 7, 2)))
    }

    func testVolumePerDaySumsCompletedVolume() {
        let workouts = [
            workout(on: day(2026, 7, 1, hour: 9), exercises: [
                exercise(id: bench, name: "Bench", groupID: chest, group: "Chest", sets: [set(5, 100)])
            ]),
            workout(on: day(2026, 7, 1, hour: 18), exercises: [
                exercise(id: row, name: "Row", groupID: back, group: "Back", sets: [
                    set(10, 50),
                    set(10, 50, completed: false),
                ])
            ]),
        ]
        let points = StatsCalculator.volumePerDay(in: workouts, calendar: calendar)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].volume, 1000)
    }
}
