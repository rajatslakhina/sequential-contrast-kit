import XCTest
@testable import SequentialContrastKit

final class ContrastIntervalTests: XCTestCase {
    private func interval(
        _ lower: Double,
        _ upper: Double,
        trialsA: Int = 10,
        successesA: Int = 7,
        trialsB: Int = 10,
        successesB: Int = 4
    ) -> ContrastInterval {
        ContrastInterval(
            lowerBound: lower,
            upperBound: upper,
            trialsA: trialsA,
            successesA: successesA,
            trialsB: trialsB,
            successesB: successesB
        )
    }

    func testWidthContainmentAndExclusion() {
        let reading = interval(-0.1, 0.4)
        XCTAssertEqual(reading.width, 0.5, accuracy: 1e-12)
        XCTAssertTrue(reading.contains(0))
        XCTAssertTrue(reading.contains(-0.1))
        XCTAssertTrue(reading.contains(0.4))
        XCTAssertFalse(reading.contains(0.5))
        XCTAssertTrue(reading.excludes(-0.2))
        XCTAssertFalse(reading.excludesZero)
    }

    func testExcludesZeroWhenTheWholeIntervalIsOneSided() {
        XCTAssertTrue(interval(0.05, 0.3).excludesZero)
        XCTAssertTrue(interval(-0.4, -0.02).excludesZero)
    }

    func testObservedDifferenceIsNilWhileEitherArmIsEmpty() {
        XCTAssertNil(interval(-1, 1, trialsA: 0, successesA: 0).observedDifference)
        XCTAssertNil(interval(-1, 1, trialsB: 0, successesB: 0).observedDifference)
        let seen = interval(-0.1, 0.4)
        XCTAssertEqual(try XCTUnwrap(seen.observedDifference), 0.3, accuracy: 1e-12)
    }

    func testDescriptionCarriesTheSignAndBothArms() {
        XCTAssertEqual(
            interval(-0.125, 0.5).description,
            "[-0.125000, +0.500000] after A 7/10, B 4/10"
        )
    }
}
