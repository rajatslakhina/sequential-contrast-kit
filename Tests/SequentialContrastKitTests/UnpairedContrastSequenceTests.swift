import XCTest
@testable import SequentialContrastKit

final class UnpairedContrastSequenceTests: XCTestCase {
    private func sequence() throws -> UnpairedContrastSequence {
        try UnpairedContrastSequence(alpha: 0.05)
    }

    func testInitRejectsAnAlphaOutsideTheUnitInterval() {
        assertThrows(.alphaOutOfRange(0)) { try UnpairedContrastSequence(alpha: 0) }
        assertThrows(.alphaOutOfRange(1)) { try UnpairedContrastSequence(alpha: 1) }
    }

    func testBudgetIsSplitEvenlyBetweenTheTwoArms() throws {
        let sequence = try sequence()
        XCTAssertEqual(sequence.componentAlpha, 0.025, accuracy: 1e-15)
        XCTAssertEqual(sequence.armSequence.alpha, 0.025, accuracy: 1e-15)
    }

    func testUnequalArmsAreAllowed() throws {
        let interval = try sequence().interval(
            successesA: 30, trialsA: 40, successesB: 40, trialsB: 100
        )
        XCTAssertEqual(interval.trialsA, 40)
        XCTAssertEqual(interval.trialsB, 100)
        XCTAssertTrue(interval.contains(try XCTUnwrap(interval.observedDifference)))
    }

    func testTallyReadingDiscardsThePairing() throws {
        let sequence = try sequence()
        let tally = try oneSidedTally()
        let fromTally = try sequence.interval(for: tally)
        let fromMargins = try sequence.interval(
            successesA: tally.successesA, trialsA: tally.trials,
            successesB: tally.successesB, trialsB: tally.trials
        )
        XCTAssertEqual(fromTally, fromMargins)
    }

    func testOverlappingArmsCanNeverExcludeZero() throws {
        let sequence = try sequence()
        let interval = try sequence.interval(for: try oneSidedTally())
        XCTAssertFalse(interval.excludesZero)
        XCTAssertTrue(interval.contains(0))
    }

    func testSeparatedArmsDoExcludeZero() throws {
        let interval = try sequence().interval(
            successesA: 480, trialsA: 500, successesB: 100, trialsB: 500
        )
        XCTAssertTrue(interval.excludesZero)
        XCTAssertGreaterThan(interval.lowerBound, 0)
    }

    func testCombineIsTheMinkowskiDifferenceClampedToTheReachableRange() {
        let armA = RateBounds(lowerBound: 0.4, upperBound: 0.9, trials: 10, successes: 6)
        let armB = RateBounds(lowerBound: 0.1, upperBound: 0.6, trials: 10, successes: 3)
        let interval = UnpairedContrastSequence.combine(armA: armA, armB: armB)
        XCTAssertEqual(interval.lowerBound, -0.2, accuracy: 1e-12)
        XCTAssertEqual(interval.upperBound, 0.8, accuracy: 1e-12)

        let wide = UnpairedContrastSequence.combine(
            armA: RateBounds(lowerBound: 0, upperBound: 1, trials: 0, successes: 0),
            armB: RateBounds(lowerBound: 0, upperBound: 1, trials: 0, successes: 0)
        )
        XCTAssertEqual(wide.lowerBound, -1)
        XCTAssertEqual(wide.upperBound, 1)
    }

    func testExclusionRejectsADifferenceOffTheScale() throws {
        let sequence = try sequence()
        let tally = try oneSidedTally()
        XCTAssertFalse(try sequence.excludes(0, tally: tally))
        assertThrows(.differenceOutOfRange(2)) { try sequence.excludes(2, tally: tally) }
        assertThrows(.differenceOutOfRange(-2)) { try sequence.excludes(-2, tally: tally) }
    }
}
