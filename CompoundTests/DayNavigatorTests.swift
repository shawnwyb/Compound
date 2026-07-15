import XCTest
@testable import Compound

final class DayNavigatorTests: XCTestCase {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()
    private lazy var nav = DayNavigator(calendar: calendar)

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth, hour: hour))!
    }

    func testStartOfDayStripsTime() {
        XCTAssertEqual(nav.startOfDay(day(2026, 7, 15, 21)), day(2026, 7, 15, 0))
    }

    func testShiftBackwardGoesToPreviousDay() {
        XCTAssertEqual(
            nav.shifted(day(2026, 7, 15), by: -1, today: day(2026, 7, 15)),
            day(2026, 7, 14, 0)
        )
    }

    func testShiftForwardIsClampedAtToday() {
        // Can't step past today into the future.
        XCTAssertEqual(
            nav.shifted(day(2026, 7, 15), by: 1, today: day(2026, 7, 15)),
            day(2026, 7, 15, 0)
        )
    }

    func testShiftForwardWithinThePastIsAllowed() {
        XCTAssertEqual(
            nav.shifted(day(2026, 7, 10), by: 1, today: day(2026, 7, 15)),
            day(2026, 7, 11, 0)
        )
    }

    func testShiftForwardFromPastClampsAtToday() {
        XCTAssertEqual(
            nav.shifted(day(2026, 7, 14), by: 5, today: day(2026, 7, 15)),
            day(2026, 7, 15, 0)
        )
    }

    func testCanGoForwardOnlyBeforeToday() {
        XCTAssertTrue(nav.canGoForward(from: day(2026, 7, 14), today: day(2026, 7, 15)))
        XCTAssertFalse(nav.canGoForward(from: day(2026, 7, 15), today: day(2026, 7, 15)))
    }

    func testIsTodayIgnoresTimeOfDay() {
        XCTAssertTrue(nav.isToday(day(2026, 7, 15, 6), today: day(2026, 7, 15, 23)))
        XCTAssertFalse(nav.isToday(day(2026, 7, 14, 23), today: day(2026, 7, 15, 0)))
    }
}
