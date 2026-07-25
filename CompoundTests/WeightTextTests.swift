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
        XCTAssertEqual(formattedSetNumber(.infinity), "")
        XCTAssertEqual(formattedSetNumber(-.infinity), "")
        XCTAssertEqual(formattedSetNumber(.nan), "")
        XCTAssertEqual(ghostSetNumber(.infinity), "")
    }

    func testFiniteWeightsStillFormatAsBefore() {
        XCTAssertEqual(formattedSetNumber(135), "135")
        XCTAssertEqual(formattedSetNumber(137.5), "137.5")
        XCTAssertEqual(ghostSetNumber(0), "0")
        XCTAssertEqual(ghostSetNumber(135), "135")
    }
}
