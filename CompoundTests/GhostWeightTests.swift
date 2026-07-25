import XCTest
@testable import Compound

/// Typing reps into a live set pulls last time's weight into the field, so a set
/// at an unchanged load costs one number instead of two. These pin when that
/// adoption happens — and, more importantly, when it must not.
final class GhostWeightTests: XCTestCase {

    func testTypingRepsAdoptsTheGhostWeight() {
        XCTAssertEqual(adoptedGhostWeight(reps: "5", weight: "", ghost: "135"), "135")
    }

    func testAWeightAlreadyEnteredIsNeverOverwritten() {
        XCTAssertNil(adoptedGhostWeight(reps: "5", weight: "140", ghost: "135"))
    }

    func testNothingIsAdoptedUntilRepsAreTyped() {
        XCTAssertNil(adoptedGhostWeight(reps: "", weight: "", ghost: "135"))
    }

    /// A ghost of "0" is the placeholder for "nothing to suggest" — adopting it
    /// would write a literal 0 into a bodyweight movement.
    func testAnEmptyGhostIsNotAdopted() {
        XCTAssertNil(adoptedGhostWeight(reps: "5", weight: "", ghost: "0"))
        XCTAssertNil(adoptedGhostWeight(reps: "5", weight: "", ghost: ""))
    }

    func testFractionalGhostsCarryThroughUnrounded() {
        XCTAssertEqual(adoptedGhostWeight(reps: "8", weight: "", ghost: "62.5"), "62.5")
    }
}
