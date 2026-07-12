import XCTest
@testable import Compound

final class LogGroupingTests: XCTestCase {

    private struct Entry: Equatable {
        let id: Int
        let date: Date
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testEmptyInput() {
        let sections: [MonthSection<Entry>] = LogGrouping.sections(
            from: [],
            date: \.date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )
        XCTAssertTrue(sections.isEmpty)
    }

    func testGroupsByMonthNewestFirst() {
        let july = Entry(id: 1, date: date(2026, 7, 8))
        let june = Entry(id: 2, date: date(2026, 6, 20))
        let may = Entry(id: 3, date: date(2026, 5, 1))

        let sections = LogGrouping.sections(
            from: [june, july, may],
            date: \.date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(sections.map(\.title), ["July 2026", "June 2026", "May 2026"])
        XCTAssertEqual(sections.map(\.count), [1, 1, 1])
        XCTAssertEqual(sections[0].items.map(\.id), [1])
        XCTAssertEqual(sections[1].items.map(\.id), [2])
        XCTAssertEqual(sections[2].items.map(\.id), [3])
    }

    func testSameDaySessionsRemainSeparateCards() {
        let morning = Entry(id: 1, date: date(2026, 7, 8, hour: 9))
        let evening = Entry(id: 2, date: date(2026, 7, 8, hour: 18))
        let other = Entry(id: 3, date: date(2026, 7, 9, hour: 10))

        let sections = LogGrouping.sections(
            from: [morning, evening, other],
            date: \.date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].count, 3)
        // Newest first within the month.
        XCTAssertEqual(sections[0].items.map(\.id), [3, 2, 1])
    }

    func testHeaderCountMatchesItems() {
        let a = Entry(id: 1, date: date(2026, 3, 1))
        let b = Entry(id: 2, date: date(2026, 3, 15))
        let c = Entry(id: 3, date: date(2026, 3, 28))

        let sections = LogGrouping.sections(
            from: [a, b, c],
            date: \.date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].title, "March 2026")
        XCTAssertEqual(sections[0].count, 3)
    }

    func testCrossYearBoundary() {
        let dec = Entry(id: 1, date: date(2025, 12, 31))
        let jan = Entry(id: 2, date: date(2026, 1, 1))

        let sections = LogGrouping.sections(
            from: [dec, jan],
            date: \.date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(sections.map(\.title), ["January 2026", "December 2025"])
    }
}
