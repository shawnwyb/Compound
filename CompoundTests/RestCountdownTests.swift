import XCTest
@testable import Compound

final class RestCountdownTests: XCTestCase {

    func testRemainingRoundsUp() {
        let now = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 89.2)
        XCTAssertEqual(RestCountdown.remaining(endDate: end, now: now), 90)
    }

    func testExactlyZeroWhenPassed() {
        let now = Date(timeIntervalSince1970: 100)
        let end = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(RestCountdown.remaining(endDate: end, now: now), 0)
    }

    func testNegativeClampsToZero() {
        let now = Date(timeIntervalSince1970: 200)
        let end = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(RestCountdown.remaining(endDate: end, now: now), 0)
    }

    // MARK: - Completion cue

    func testAlertsRightWhenTheRestEnds() {
        let end = Date(timeIntervalSince1970: 100)
        XCTAssertTrue(RestCountdown.shouldAlert(endDate: end, now: end))
    }

    func testAlertsWithinTheGrace() {
        let end = Date(timeIntervalSince1970: 100)
        XCTAssertTrue(RestCountdown.shouldAlert(endDate: end, now: end.addingTimeInterval(2)))
    }

    func testStaysSilentLongAfterTheRestEnded() {
        // Expired while the app was suspended -> noticed minutes later, no cue.
        let end = Date(timeIntervalSince1970: 100)
        XCTAssertFalse(RestCountdown.shouldAlert(endDate: end, now: end.addingTimeInterval(240)))
    }

    func testStaysSilentBeforeTheRestEnds() {
        let end = Date(timeIntervalSince1970: 100)
        XCTAssertFalse(RestCountdown.shouldAlert(endDate: end, now: end.addingTimeInterval(-5)))
    }
}
