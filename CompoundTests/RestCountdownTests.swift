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
}
