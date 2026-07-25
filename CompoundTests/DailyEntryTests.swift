import XCTest
@testable import Compound

/// Pure tests for `DailyEntry`. The `entry(on:in:)` fetch-or-create is thin
/// SwiftData plumbing verified by running the app (per the project's testing
/// philosophy); its meaningful logic — which calendar day a timestamp belongs
/// to — lives in `dayBounds(for:)` and `hasData`, which are exercised here.
final class DailyEntryTests: XCTestCase {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    private func date(_ year: Int, _ month: Int, _ dayOfMonth: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth, hour: hour, minute: minute))!
    }

    // MARK: - appendingFood

    func testPasteIntoAnEmptyLogAddsNoLeadingBlankLine() {
        XCTAssertEqual(DailyEntry.appendingFood("oats", to: ""), "oats")
        XCTAssertEqual(DailyEntry.appendingFood("oats", to: "  \n "), "oats")
    }

    func testPasteAlwaysLandsOnItsOwnLine() {
        XCTAssertEqual(DailyEntry.appendingFood("oats", to: "eggs"), "eggs\noats")
    }

    func testPasteAfterATrailingNewlineDoesNotLeaveABlankLine() {
        XCTAssertEqual(DailyEntry.appendingFood("oats", to: "eggs\n"), "eggs\noats")
        XCTAssertEqual(DailyEntry.appendingFood("oats", to: "eggs\n\n  "), "eggs\noats")
    }

    func testPastedTextIsTrimmedButInnerLineBreaksAreKept() {
        XCTAssertEqual(DailyEntry.appendingFood("\n oats\nrice \n", to: "eggs"), "eggs\noats\nrice")
    }

    func testPastingNothingLeavesTheLogUntouched() {
        XCTAssertEqual(DailyEntry.appendingFood("   ", to: "eggs\n"), "eggs\n")
    }

    // MARK: - hasData

    func testEmptyEntryHasNoData() {
        XCTAssertFalse(DailyEntry().hasData)
    }

    func testWhitespaceOnlyFoodIsNotData() {
        XCTAssertFalse(DailyEntry(foodText: "   \n\t").hasData)
    }

    func testAnySingleFieldCountsAsData() {
        XCTAssertTrue(DailyEntry(bodyWeight: 180).hasData)
        XCTAssertTrue(DailyEntry(foodText: "eggs").hasData)
        XCTAssertTrue(DailyEntry(calories: 2000).hasData)
        XCTAssertTrue(DailyEntry(protein: 150).hasData)
    }

    // MARK: - date normalization

    func testInitNormalizesToStartOfDay() {
        let entry = DailyEntry(date: date(2026, 7, 15, 21), calendar: calendar)
        XCTAssertEqual(entry.date, calendar.startOfDay(for: date(2026, 7, 15)))
    }

    // MARK: - dayBounds (drives fetch-or-create dedupe + day boundaries)

    func testDayBoundsSpanExactlyOneDay() {
        let bounds = DailyEntry.dayBounds(for: date(2026, 7, 15, 12), calendar: calendar)
        XCTAssertEqual(bounds.start, date(2026, 7, 15, 0))
        XCTAssertEqual(bounds.end, date(2026, 7, 16, 0))
    }

    func testAnyTimeOnTheDayFallsInsideItsBounds() {
        let bounds = DailyEntry.dayBounds(for: date(2026, 7, 15, 12), calendar: calendar)
        for hour in [0, 8, 15, 23] {
            let t = date(2026, 7, 15, hour, 59)
            XCTAssertTrue(t >= bounds.start && t < bounds.end, "expected \(t) within day bounds")
        }
    }

    func testAdjacentDaysDoNotOverlap() {
        // The half-open range excludes the next midnight, so 23:59 on the 15th
        // and 00:00 on the 16th resolve to different days (no double-counting).
        let d15 = DailyEntry.dayBounds(for: date(2026, 7, 15, 23, 59), calendar: calendar)
        let startOf16 = date(2026, 7, 16, 0)
        XCTAssertEqual(d15.end, startOf16)
        XCTAssertFalse(startOf16 < d15.end) // the 16th's first instant is outside the 15th
        XCTAssertEqual(DailyEntry.dayBounds(for: startOf16, calendar: calendar).start, startOf16)
    }
}
