import XCTest
@testable import Compound

final class PrefillServiceTests: XCTestCase {

    private let exercise = UUID()
    private let other = UUID()

    private func set(_ n: Int, _ reps: Int, _ weight: Double, completed: Bool = true) -> HistoricalSet {
        HistoricalSet(setNumber: n, reps: reps, weight: weight, completed: completed)
    }

    func testFirstRunReturnsEmpty() {
        XCTAssertEqual(PrefillService.lastValues(for: exercise, in: []), [])
    }

    func testReturnsCompletedSetsSortedBySetNumber() {
        let workout = HistoricalWorkout(date: .now, exercises: [
            HistoricalExercise(exerciseID: exercise, sets: [
                set(2, 8, 135), set(1, 10, 135), set(3, 6, 145),
            ])
        ])
        XCTAssertEqual(
            PrefillService.lastValues(for: exercise, in: [workout]),
            [PrefilledSet(reps: 10, weight: 135),
             PrefilledSet(reps: 8, weight: 135),
             PrefilledSet(reps: 6, weight: 145)]
        )
    }

    func testPicksMostRecentWorkout() {
        let old = HistoricalWorkout(date: Date(timeIntervalSince1970: 1000), exercises: [
            HistoricalExercise(exerciseID: exercise, sets: [set(1, 5, 100)])
        ])
        let recent = HistoricalWorkout(date: Date(timeIntervalSince1970: 2000), exercises: [
            HistoricalExercise(exerciseID: exercise, sets: [set(1, 8, 120)])
        ])
        // Order shuffled to prove it sorts by date, not array order.
        XCTAssertEqual(
            PrefillService.lastValues(for: exercise, in: [old, recent]),
            [PrefilledSet(reps: 8, weight: 120)]
        )
    }

    func testSkipsBlankPerformanceInFavorOfRealData() {
        let realData = HistoricalWorkout(date: Date(timeIntervalSince1970: 1000), exercises: [
            HistoricalExercise(exerciseID: exercise, sets: [set(1, 8, 120)])
        ])
        let blank = HistoricalWorkout(date: Date(timeIntervalSince1970: 2000), exercises: [
            HistoricalExercise(exerciseID: exercise, sets: [
                set(1, 0, 0, completed: false), set(2, 0, 0, completed: false),
            ])
        ])
        // Most recent performance has no data at all -> fall back to older, real one.
        XCTAssertEqual(
            PrefillService.lastValues(for: exercise, in: [realData, blank]),
            [PrefilledSet(reps: 8, weight: 120)]
        )
    }

    func testRemembersEditsEvenWhenNotMarkedCompleted() {
        // The key regression: values were entered but the completion toggle was
        // never tapped. They must still be remembered.
        let workout = HistoricalWorkout(date: .now, exercises: [
            HistoricalExercise(exerciseID: exercise, sets: [
                set(1, 8, 135, completed: false), set(2, 6, 145, completed: false),
            ])
        ])
        XCTAssertEqual(
            PrefillService.lastValues(for: exercise, in: [workout]),
            [PrefilledSet(reps: 8, weight: 135), PrefilledSet(reps: 6, weight: 145)]
        )
    }

    func testKeepsAllLoggedSetsRegardlessOfCompletion() {
        // A completed first set and an entered-but-unticked second set: both kept,
        // so an added/edited set carries forward.
        let workout = HistoricalWorkout(date: .now, exercises: [
            HistoricalExercise(exerciseID: exercise, sets: [
                set(1, 8, 135), set(2, 0, 135, completed: false),
            ])
        ])
        XCTAssertEqual(
            PrefillService.lastValues(for: exercise, in: [workout]),
            [PrefilledSet(reps: 8, weight: 135), PrefilledSet(reps: 0, weight: 135)]
        )
    }

    func testIgnoresOtherExercises() {
        let workout = HistoricalWorkout(date: .now, exercises: [
            HistoricalExercise(exerciseID: other, sets: [set(1, 12, 200)])
        ])
        XCTAssertEqual(PrefillService.lastValues(for: exercise, in: [workout]), [])
    }
}
