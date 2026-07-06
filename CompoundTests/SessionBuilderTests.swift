import XCTest
@testable import Compound

final class SessionBuilderTests: XCTestCase {

    func testZeroTargetProducesNoSets() {
        XCTAssertEqual(SessionBuilder.seededSets(targetSets: 0, lastValues: []), [])
    }

    func testNoHistoryZeroesEverySet() {
        XCTAssertEqual(
            SessionBuilder.seededSets(targetSets: 3, lastValues: []),
            [SeededSet(reps: 0, weight: 0),
             SeededSet(reps: 0, weight: 0),
             SeededSet(reps: 0, weight: 0)]
        )
    }

    func testHistoryCopiedWhenCountsMatch() {
        let last = [PrefilledSet(reps: 8, weight: 135), PrefilledSet(reps: 6, weight: 145)]
        XCTAssertEqual(
            SessionBuilder.seededSets(targetSets: 2, lastValues: last),
            [SeededSet(reps: 8, weight: 135), SeededSet(reps: 6, weight: 145)]
        )
    }

    func testHistoryCountWinsWhenFewerThanTarget() {
        // Last time only 1 set was done -> next session starts with 1, not 3.
        let last = [PrefilledSet(reps: 8, weight: 135)]
        XCTAssertEqual(
            SessionBuilder.seededSets(targetSets: 3, lastValues: last),
            [SeededSet(reps: 8, weight: 135)]
        )
    }

    func testHistoryCountWinsWhenMoreThanTarget() {
        // Last time 3 sets were done (an added set) -> keep all 3, ignore target 2.
        let last = [PrefilledSet(reps: 8, weight: 135),
                    PrefilledSet(reps: 6, weight: 145),
                    PrefilledSet(reps: 4, weight: 155)]
        XCTAssertEqual(
            SessionBuilder.seededSets(targetSets: 2, lastValues: last),
            [SeededSet(reps: 8, weight: 135),
             SeededSet(reps: 6, weight: 145),
             SeededSet(reps: 4, weight: 155)]
        )
    }

    func testSetCountUsesTargetOnlyWithoutHistory() {
        XCTAssertEqual(SessionBuilder.setCount(targetSets: 3, historyCount: 0), 3)
        XCTAssertEqual(SessionBuilder.setCount(targetSets: 3, historyCount: 4), 4)
        XCTAssertEqual(SessionBuilder.setCount(targetSets: 0, historyCount: 0), 0)
    }
}
