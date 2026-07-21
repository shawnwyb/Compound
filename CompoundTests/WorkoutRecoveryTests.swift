import XCTest
@testable import Compound

/// Stand-in for a `Workout` so the recovery decision can be tested without a
/// `ModelContainer`.
private struct StubWorkout: RecoverableWorkout {
    let id = UUID()
    let startedAt: Date
    let completedSetCount: Int

    init(startedAt: TimeInterval, completedSetCount: Int) {
        self.startedAt = Date(timeIntervalSince1970: startedAt)
        self.completedSetCount = completedSetCount
    }
}

final class WorkoutRecoveryTests: XCTestCase {

    func testNoOrphansResumesNothing() {
        let plan = WorkoutRecovery.plan(for: [StubWorkout]())
        XCTAssertNil(plan.resume)
        XCTAssertTrue(plan.discard.isEmpty)
    }

    func testUntouchedWorkoutIsDiscarded() {
        // Started from a routine but nothing logged -> just seeded scaffolding.
        let scaffold = StubWorkout(startedAt: 100, completedSetCount: 0)
        let plan = WorkoutRecovery.plan(for: [scaffold])
        XCTAssertNil(plan.resume)
        XCTAssertEqual(plan.discard.map(\.id), [scaffold.id])
    }

    func testWorkoutWithLoggedSetsIsResumed() {
        let real = StubWorkout(startedAt: 100, completedSetCount: 3)
        let plan = WorkoutRecovery.plan(for: [real])
        XCTAssertEqual(plan.resume?.id, real.id)
        XCTAssertTrue(plan.discard.isEmpty)
    }

    func testMostRecentSurvivesAndTheRestAreDiscarded() {
        let older = StubWorkout(startedAt: 100, completedSetCount: 2)
        let newer = StubWorkout(startedAt: 500, completedSetCount: 1)
        let empty = StubWorkout(startedAt: 900, completedSetCount: 0)
        let plan = WorkoutRecovery.plan(for: [older, newer, empty])
        XCTAssertEqual(plan.resume?.id, newer.id)
        XCTAssertEqual(Set(plan.discard.map(\.id)), [older.id, empty.id])
    }
}
