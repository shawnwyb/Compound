import XCTest
@testable import Compound

/// Every weight typed into the app goes through `WeightText.value`, so this is
/// where the non-finite numbers that crashed the Body tab are shut out — see
/// `testRejectsNonFiniteNumbers` for the list of what `Double.init` waves through.
final class WeightTextTests: XCTestCase {

    func testParsesEitherDecimalSeparator() {
        XCTAssertEqual(WeightText.value("180"), 180)
        XCTAssertEqual(WeightText.value("180.4"), 180.4)
        XCTAssertEqual(WeightText.value("180,4"), 180.4)
    }

    func testParsesPartialAndSignedInput() {
        XCTAssertEqual(WeightText.value("180."), 180)
        XCTAssertEqual(WeightText.value(".5"), 0.5)
        XCTAssertEqual(WeightText.value("0"), 0)
        XCTAssertEqual(WeightText.value("-5"), -5)
    }

    func testRejectsTextThatIsNotANumber() {
        XCTAssertNil(WeightText.value(""))
        XCTAssertNil(WeightText.value("180.4.2"))
        XCTAssertNil(WeightText.value("one eighty"))
        XCTAssertNil(WeightText.value("180 lb"))
    }

    /// `Double.init` parses all of these. Each one used to reach the charts as a
    /// NaN plot area and the readouts as a trapping `Int(_:)` conversion.
    func testRejectsNonFiniteNumbers() {
        XCTAssertNil(WeightText.value("inf"))
        XCTAssertNil(WeightText.value("infinity"))
        XCTAssertNil(WeightText.value("-inf"))
        XCTAssertNil(WeightText.value("nan"))
        XCTAssertNil(WeightText.value("1e999"))
        // A digit key held down long enough overflows a Double to infinity.
        XCTAssertNil(WeightText.value(String(repeating: "9", count: 320)))
    }

    // MARK: - Formatting the values back out

    func testNonFiniteWeightsNeverReachTheIntConversion() {
        // Would trap rather than return, so reaching the assert is the test.
        XCTAssertEqual(formatWeight(.infinity), "—")
        XCTAssertEqual(formatWeight(.nan), "—")
    }

    /// A weight past `Int.max` is finite, so the non-finite guard lets it by —
    /// twenty digits is all it takes, and `Int(_:)` traps on every one. The
    /// fields refuse those now, but stored ones still have to draw.
    func testWeightsTooLargeForAnIntStillFormat() {
        XCTAssertEqual(formatWeight(1e30), "1000000000000000019884624838656")
        XCTAssertEqual(formatWeight(Double(Int.max) * 2), "18446744073709551616")
    }

    func testFiniteWeightsStillFormatAsBefore() {
        XCTAssertEqual(formatWeight(180), "180")
        XCTAssertEqual(formatWeight(180.4), "180.4")
    }
}
