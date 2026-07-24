import XCTest
@testable import Compound

/// Stand-in for a `Workout` so the recovery decision can be tested without a
/// `ModelContainer`.
private struct StubWorkout: RecoverableWorkout {
    let id = UUID()
    let startedAt: Date
    let hasLoggedWork: Bool

    init(startedAt: TimeInterval, hasLoggedWork: Bool) {
        self.startedAt = Date(timeIntervalSince1970: startedAt)
        self.hasLoggedWork = hasLoggedWork
    }
}

final class WorkoutRecoveryTests: XCTestCase {

    func testNoOrphansResumesNothing() {
        let plan = WorkoutRecovery.plan(for: [StubWorkout]())
        XCTAssertNil(plan.resume)
        XCTAssertTrue(plan.discard.isEmpty)
    }

    func testWorkoutWithLoggedSetsIsResumed() {
        let real = StubWorkout(startedAt: 100, hasLoggedWork: true)
        let plan = WorkoutRecovery.plan(for: [real])
        XCTAssertEqual(plan.resume?.id, real.id)
        XCTAssertTrue(plan.discard.isEmpty)
    }

    func testUntouchedWorkoutIsStillResumed() {
        // Nothing logged yet, but the session was interrupted, not abandoned.
        let scaffold = StubWorkout(startedAt: 100, hasLoggedWork: false)
        let plan = WorkoutRecovery.plan(for: [scaffold])
        XCTAssertEqual(plan.resume?.id, scaffold.id)
        XCTAssertTrue(plan.discard.isEmpty)
    }

    func testAgeAloneNeverCondemnsASession() {
        // However long it has been sitting, only Finish or Discard ends it.
        let ancient = StubWorkout(startedAt: 0, hasLoggedWork: false)
        let plan = WorkoutRecovery.plan(for: [ancient])
        XCTAssertEqual(plan.resume?.id, ancient.id)
        XCTAssertTrue(plan.discard.isEmpty)
    }

    func testMostRecentWins() {
        let older = StubWorkout(startedAt: 100, hasLoggedWork: true)
        let newer = StubWorkout(startedAt: 500, hasLoggedWork: true)
        let plan = WorkoutRecovery.plan(for: [older, newer])
        XCTAssertEqual(plan.resume?.id, newer.id)
        // The one not adopted still has work in it, so it is kept, not deleted.
        XCTAssertTrue(plan.discard.isEmpty)
    }

    func testLoggedWorkOutranksAMoreRecentScaffold() {
        let real = StubWorkout(startedAt: 100, hasLoggedWork: true)
        let scaffold = StubWorkout(startedAt: 900, hasLoggedWork: false)
        let plan = WorkoutRecovery.plan(for: [real, scaffold])
        XCTAssertEqual(plan.resume?.id, real.id)
        XCTAssertEqual(plan.discard.map(\.id), [scaffold.id])
    }
}
