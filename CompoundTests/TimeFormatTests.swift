import XCTest
@testable import Compound

final class TimeFormatTests: XCTestCase {

    func testFormatsUnderAMinute() {
        XCTAssertEqual(TimeFormat.clock(0), "0:00")
        XCTAssertEqual(TimeFormat.clock(5), "0:05")
        XCTAssertEqual(TimeFormat.clock(59), "0:59")
    }

    func testFormatsMinutes() {
        XCTAssertEqual(TimeFormat.clock(65), "1:05")
        XCTAssertEqual(TimeFormat.clock(600), "10:00")
    }

    func testFormatsHours() {
        XCTAssertEqual(TimeFormat.clock(3600), "1:00:00")
        XCTAssertEqual(TimeFormat.clock(3661), "1:01:01")
    }

    func testNegativeClampsToZero() {
        XCTAssertEqual(TimeFormat.clock(-30), "0:00")
    }
}
