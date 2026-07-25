import XCTest
@testable import Compound

/// The digit budgets every number field is typed through. `filtered` is applied
/// to the text on each change and written back, so what it returns is literally
/// what the user sees — a character it drops is a keystroke that does nothing.
final class NumberLimitTests: XCTestCase {

    // MARK: - What the fields accept

    func testWeightTakesFourDigitsAndOneDecimal() {
        XCTAssertEqual(NumberLimit.weight.filtered("225"), "225")
        XCTAssertEqual(NumberLimit.weight.filtered("1350.5"), "1350.5")
        XCTAssertEqual(NumberLimit.weight.filtered("9999.9"), "9999.9")
        // The fifth digit and the second decimal never land.
        XCTAssertEqual(NumberLimit.weight.filtered("99999"), "9999")
        XCTAssertEqual(NumberLimit.weight.filtered("180.45"), "180.4")
    }

    func testRepsCaloriesAndProteinTakeWholeNumbersOnly() {
        XCTAssertEqual(NumberLimit.reps.filtered("12"), "12")
        XCTAssertEqual(NumberLimit.reps.filtered("1000"), "100")
        XCTAssertEqual(NumberLimit.reps.filtered("8.5"), "85")
        XCTAssertEqual(NumberLimit.calories.filtered("12000"), "12000")
        XCTAssertEqual(NumberLimit.calories.filtered("123456"), "12345")
        XCTAssertEqual(NumberLimit.protein.filtered("180"), "180")
        XCTAssertEqual(NumberLimit.protein.filtered("18000"), "1800")
    }

    func testACommaWorksAsADecimalPoint() {
        XCTAssertEqual(NumberLimit.weight.filtered("82,5"), "82,5")
        XCTAssertEqual(WeightText.value(NumberLimit.weight.filtered("82,5")), 82.5)
    }

    func testPartialInputSurvivesMidTyping() {
        // Every prefix of a number the user is still typing must come back
        // unchanged, or the field fights them for the decimal point.
        for text in ["", "8", "82", "82.", "82.5", ".", ".5"] {
            XCTAssertEqual(NumberLimit.weight.filtered(text), text)
        }
    }

    func testEverythingThatIsNotADigitIsDropped() {
        XCTAssertEqual(NumberLimit.weight.filtered("180 lb"), "180")
        XCTAssertEqual(NumberLimit.weight.filtered("-5"), "5")
        XCTAssertEqual(NumberLimit.weight.filtered("1.2.3"), "1.2")
        XCTAssertEqual(NumberLimit.calories.filtered("about 2,000 kcal"), "2000")
    }

    func testLeadingZerosDoNotEatTheBudget() {
        XCTAssertEqual(NumberLimit.weight.filtered("00180"), "180")
        XCTAssertEqual(NumberLimit.weight.filtered("0"), "0")
        XCTAssertEqual(NumberLimit.weight.filtered("0.5"), "0.5")
    }

    /// The crash inputs from every round of this bug, now unrepresentable:
    /// there is no text the field will hold that parses to one of them.
    func testTheNumbersThatCrashedTheAppCannotBeTyped() {
        for text in ["inf", "infinity", "nan", "1e999", String(repeating: "9", count: 320)] {
            let typed = NumberLimit.weight.filtered(text)
            let value = WeightText.value(typed)
            XCTAssertTrue(value == nil || value!.isFinite, "\(text) -> \(typed)")
            XCTAssertLessThanOrEqual(value ?? 0, 9999.9, "\(text) -> \(typed)")
        }
    }

    // MARK: - Filling a field from stored data

    func testStoredValuesRoundToTheBudgetRatherThanShowTheirTail() {
        // What a lb -> kg switch leaves behind.
        XCTAssertEqual(NumberLimit.weight.text(for: 45.359237), "45.4")
        XCTAssertEqual(NumberLimit.weight.text(for: 135), "135")
        XCTAssertEqual(NumberLimit.weight.text(for: 0), "0")
        XCTAssertEqual(NumberLimit.reps.text(for: 12), "12")
    }

    func testStoredValuesTooBigForTheFieldShowAsBlank() {
        // Blank, not truncated: "1000" would be a number the user never logged.
        XCTAssertEqual(NumberLimit.weight.text(for: 1e30), "")
        XCTAssertEqual(NumberLimit.weight.text(for: .infinity), "")
        XCTAssertEqual(NumberLimit.weight.text(for: .nan), "")
        XCTAssertEqual(NumberLimit.calories.text(for: 999_999_999), "")
    }

    func testFieldTextAlwaysSurvivesBeingTypedBackIn() {
        for value in [0, 0.5, 45.359237, 135, 9999.9, 1e30, .infinity, .nan] as [Double] {
            let text = NumberLimit.weight.text(for: value)
            XCTAssertEqual(NumberLimit.weight.filtered(text), text, "\(value) -> \(text)")
        }
    }
}
