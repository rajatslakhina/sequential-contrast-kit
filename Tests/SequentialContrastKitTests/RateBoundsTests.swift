import XCTest
@testable import SequentialContrastKit

final class RateBoundsTests: XCTestCase {
    func testWidthAndContainment() {
        let bounds = RateBounds(lowerBound: 0.2, upperBound: 0.8, trials: 40, successes: 20)
        XCTAssertEqual(bounds.width, 0.6, accuracy: 1e-12)
        XCTAssertTrue(bounds.contains(0.2))
        XCTAssertTrue(bounds.contains(0.8))
        XCTAssertTrue(bounds.contains(0.5))
        XCTAssertFalse(bounds.contains(0.1))
        XCTAssertFalse(bounds.contains(0.9))
    }

    func testObservedRateIsNilBeforeAnyTrial() {
        let empty = RateBounds(lowerBound: 0, upperBound: 1, trials: 0, successes: 0)
        XCTAssertNil(empty.observedRate)
        let seen = RateBounds(lowerBound: 0.1, upperBound: 0.9, trials: 8, successes: 2)
        XCTAssertEqual(try XCTUnwrap(seen.observedRate), 0.25, accuracy: 1e-12)
    }

    func testDescriptionNamesTheCounts() {
        let bounds = RateBounds(lowerBound: 0.25, upperBound: 0.75, trials: 4, successes: 2)
        XCTAssertEqual(bounds.description, "[0.250000, 0.750000] after 2/4")
    }
}
