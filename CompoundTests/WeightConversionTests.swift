import XCTest
@testable import Compound

final class WeightConversionTests: XCTestCase {

    func testSameUnitIsNoOp() {
        XCTAssertEqual(WeightConversion.convert(135, from: .pounds, to: .pounds), 135)
        XCTAssertEqual(WeightConversion.convert(60, from: .kilograms, to: .kilograms), 60)
    }

    func testPoundsToKilograms() {
        let kg = WeightConversion.convert(220.46226218, from: .pounds, to: .kilograms)
        XCTAssertEqual(kg, 100, accuracy: 0.0001)
    }

    func testKilogramsToPounds() {
        let lb = WeightConversion.convert(100, from: .kilograms, to: .pounds)
        XCTAssertEqual(lb, 220.46226218, accuracy: 0.0001)
    }

    func testRoundTrip() {
        let original = 135.0
        let kg = WeightConversion.convert(original, from: .pounds, to: .kilograms)
        let back = WeightConversion.convert(kg, from: .kilograms, to: .pounds)
        XCTAssertEqual(back, original, accuracy: 0.0000001)
    }

    func testZeroAndNegative() {
        XCTAssertEqual(WeightConversion.convert(0, from: .pounds, to: .kilograms), 0)
        let neg = WeightConversion.convert(-10, from: .pounds, to: .kilograms)
        XCTAssertEqual(neg, -10 / WeightConversion.poundsPerKilogram, accuracy: 0.0001)
    }
}
