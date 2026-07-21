import XCTest
@testable import Compound

private struct StubSet: ProgressSet {
    let completed: Bool
}

private struct StubExercise: ProgressExercise {
    let exerciseName: String
    let progressSets: [StubSet]

    /// `done` sets completed, the rest incomplete.
    init(_ name: String, sets: Int, done: Int) {
        exerciseName = name
        progressSets = (0..<sets).map { StubSet(completed: $0 < done) }
    }
}

final class WorkoutProgressTests: XCTestCase {

    func testEmptyWorkoutHasNoPosition() {
        XCTAssertNil(WorkoutProgress.current(in: [StubExercise]()))
    }

    func testExercisesWithoutSetsHaveNoPosition() {
        let empty = [StubExercise("Bench Press", sets: 0, done: 0)]
        XCTAssertNil(WorkoutProgress.current(in: empty))
    }

    func testNothingCompletedStartsAtFirstSet() {
        let position = WorkoutProgress.current(in: [
            StubExercise("Bench Press", sets: 3, done: 0),
            StubExercise("Back Squat", sets: 3, done: 0),
        ])
        XCTAssertEqual(position, .init(exerciseName: "Bench Press", setIndex: 1, setCount: 3, isComplete: false))
    }

    func testMidExercisePointsAtTheNextIncompleteSet() {
        let position = WorkoutProgress.current(in: [
            StubExercise("Bench Press", sets: 3, done: 2),
        ])
        XCTAssertEqual(position, .init(exerciseName: "Bench Press", setIndex: 3, setCount: 3, isComplete: false))
    }

    func testFinishedExerciseRollsOnToTheNext() {
        let position = WorkoutProgress.current(in: [
            StubExercise("Bench Press", sets: 3, done: 3),
            StubExercise("Back Squat", sets: 4, done: 1),
        ])
        XCTAssertEqual(position, .init(exerciseName: "Back Squat", setIndex: 2, setCount: 4, isComplete: false))
    }

    func testSkipsEmptyExercisesWhenRollingOn() {
        let position = WorkoutProgress.current(in: [
            StubExercise("Bench Press", sets: 2, done: 2),
            StubExercise("Placeholder", sets: 0, done: 0),
            StubExercise("Back Squat", sets: 2, done: 0),
        ])
        XCTAssertEqual(position, .init(exerciseName: "Back Squat", setIndex: 1, setCount: 2, isComplete: false))
    }

    func testAnEarlierSkippedSetWinsOverLaterProgress() {
        // Set 1 left unticked while sets 2-3 were done -> the gap is still current.
        let withGap = StubExerciseFixed(name: "Bench Press", completed: [false, true, true])
        XCTAssertEqual(
            WorkoutProgress.current(in: [withGap]),
            .init(exerciseName: "Bench Press", setIndex: 1, setCount: 3, isComplete: false)
        )
    }

    func testEverythingCompleteReportsTheLastSet() {
        let position = WorkoutProgress.current(in: [
            StubExercise("Bench Press", sets: 3, done: 3),
            StubExercise("Back Squat", sets: 2, done: 2),
        ])
        XCTAssertEqual(position, .init(exerciseName: "Back Squat", setIndex: 2, setCount: 2, isComplete: true))
    }

    func testCompleteIgnoresTrailingEmptyExercise() {
        let position = WorkoutProgress.current(in: [
            StubExercise("Bench Press", sets: 2, done: 2),
            StubExercise("Placeholder", sets: 0, done: 0),
        ])
        XCTAssertEqual(position, .init(exerciseName: "Bench Press", setIndex: 2, setCount: 2, isComplete: true))
    }
}

/// Explicit per-set completion, for gap cases the `done:` count can't express.
private struct StubExerciseFixed: ProgressExercise {
    let name: String
    let completed: [Bool]

    var exerciseName: String { name }
    var progressSets: [StubSet] { completed.map { StubSet(completed: $0) } }
}
