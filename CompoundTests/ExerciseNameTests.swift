import XCTest
@testable import Compound

/// Naming rules for exercises added to the library. The library is a list a
/// human scans for the movement they just did, so the tests below are mostly
/// about not letting two rows look the same.
final class ExerciseNameTests: XCTestCase {

    // MARK: - normalizedName

    func testOuterWhitespaceIsTrimmed() {
        XCTAssertEqual(Exercise.normalizedName("  Hip Thrust  "), "Hip Thrust")
        XCTAssertEqual(Exercise.normalizedName("\n Hip Thrust\t"), "Hip Thrust")
    }

    func testInnerWhitespaceRunsCollapse() {
        XCTAssertEqual(Exercise.normalizedName("Hip    Thrust"), "Hip Thrust")
        XCTAssertEqual(Exercise.normalizedName("Bench\tPress"), "Bench Press")
    }

    func testAWhitespaceOnlyNameNormalizesToNothing() {
        XCTAssertEqual(Exercise.normalizedName("   \n\t "), "")
    }

    // MARK: - nameProblem

    func testAFreshNameIsAccepted() {
        XCTAssertNil(Exercise.nameProblem("Hip Thrust", existing: ["Bench Press", "Back Squat"]))
    }

    func testAnEmptyNameIsRefused() {
        XCTAssertEqual(Exercise.nameProblem("", existing: []), .empty)
        XCTAssertEqual(Exercise.nameProblem("   ", existing: []), .empty)
    }

    func testAnExactDuplicateIsRefused() {
        XCTAssertEqual(
            Exercise.nameProblem("Bench Press", existing: ["Bench Press"]),
            .duplicate("Bench Press")
        )
    }

    /// Two rows differing only in case, spacing, or accents are a mistake every
    /// time — nobody means to keep both.
    func testDuplicatesAreCaughtRegardlessOfCaseSpacingOrAccents() {
        let library = ["Bench Press"]
        for typed in ["bench press", "BENCH PRESS", "  Bench   Press ", "Bénch Press"] {
            XCTAssertEqual(
                Exercise.nameProblem(typed, existing: library),
                .duplicate("Bench Press"),
                "expected \(typed) to be refused"
            )
        }
    }

    /// The message names the entry as it's stored, not as it was typed, so it
    /// points at the row the user should go and find.
    func testTheProblemCarriesTheExistingSpelling() {
        XCTAssertEqual(
            Exercise.nameProblem("romanian deadlift", existing: ["Romanian Deadlift"]),
            .duplicate("Romanian Deadlift")
        )
    }

    func testNamesThatMerelyOverlapAreNotDuplicates() {
        XCTAssertNil(Exercise.nameProblem("Incline Bench Press", existing: ["Bench Press"]))
        XCTAssertNil(Exercise.nameProblem("Bench", existing: ["Bench Press"]))
    }
}
