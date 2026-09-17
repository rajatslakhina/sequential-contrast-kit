import XCTest
@testable import SequentialContrastKit

final class PairedContrastSequenceTests: XCTestCase {
    private func sequence() throws -> PairedContrastSequence {
        try PairedContrastSequence(alpha: 0.05)
    }

    func testInitRejectsAnAlphaOutsideTheUnitInterval() {
        assertThrows(.alphaOutOfRange(0)) { try PairedContrastSequence(alpha: 0) }
        assertThrows(.alphaOutOfRange(1)) { try PairedContrastSequence(alpha: 1) }
    }

    func testBudgetIsSplitEvenlyBetweenTheTwoComponents() throws {
        let sequence = try sequence()
        XCTAssertEqual(sequence.componentAlpha, 0.025, accuracy: 1e-15)
        XCTAssertEqual(sequence.componentSequence.alpha, 0.025, accuracy: 1e-15)
    }

    func testComponentsReadTheCellsTheyAreSupposedTo() throws {
        let sequence = try sequence()
        let tally = try oneSidedTally()
        let discordance = try sequence.discordanceBounds(for: tally)
        XCTAssertEqual(discordance.trials, 120)
        XCTAssertEqual(discordance.successes, 12)
        let win = try sequence.winBounds(for: tally)
        XCTAssertEqual(win.trials, 12)
        XCTAssertEqual(win.successes, 12)
    }

    func testOneSidedDisagreementExcludesZeroWhileTheMarginalsOverlap() throws {
        let sequence = try sequence()
        let tally = try oneSidedTally()
        let interval = try sequence.interval(for: tally)
        XCTAssertTrue(interval.excludesZero)
        XCTAssertGreaterThan(interval.lowerBound, 0)
        XCTAssertTrue(interval.contains(try XCTUnwrap(tally.observedDifference)))

        let unpaired = try UnpairedContrastSequence(alpha: 0.05)
        let armA = try unpaired.armSequence.interval(successes: 78, trials: 120)
        let armB = try unpaired.armSequence.interval(successes: 66, trials: 120)
        XCTAssertLessThanOrEqual(armB.lowerBound, armA.upperBound)
        XCTAssertLessThanOrEqual(armA.lowerBound, armB.upperBound)
    }

    func testEmptyTallyAdmitsEveryDifference() throws {
        let interval = try sequence().interval(for: .empty)
        XCTAssertEqual(interval.lowerBound, -1, accuracy: 1e-12)
        XCTAssertEqual(interval.upperBound, 1, accuracy: 1e-12)
        XCTAssertNil(interval.observedDifference)
    }

    func testCombineTakesTheExtremesOverAllFourCorners() throws {
        let tally = try ContrastTally(
            bothSucceeded: 0, onlyASucceeded: 3, onlyBSucceeded: 3, neitherSucceeded: 4
        )
        // A win range straddling one half makes the product's extremes fall on
        // opposite discordance corners, which is the case a sign analysis gets
        // wrong and a four-corner scan does not.
        let discordance = RateBounds(lowerBound: 0.2, upperBound: 0.8, trials: 10, successes: 6)
        let win = RateBounds(lowerBound: 0.25, upperBound: 0.75, trials: 6, successes: 3)
        let interval = PairedContrastSequence.combine(
            discordance: discordance, win: win, tally: tally
        )
        XCTAssertEqual(interval.lowerBound, -0.4, accuracy: 1e-12)
        XCTAssertEqual(interval.upperBound, 0.4, accuracy: 1e-12)
        XCTAssertEqual(interval.trialsA, 10)
        XCTAssertEqual(interval.successesA, 3)
        XCTAssertEqual(interval.trialsB, 10)
        XCTAssertEqual(interval.successesB, 3)
    }

    func testCombineClampsToTheReachableRange() throws {
        let tally = try ContrastTally(
            bothSucceeded: 0, onlyASucceeded: 1, onlyBSucceeded: 0, neitherSucceeded: 0
        )
        let discordance = RateBounds(lowerBound: 0, upperBound: 4, trials: 1, successes: 1)
        let win = RateBounds(lowerBound: 0, upperBound: 1, trials: 1, successes: 1)
        let interval = PairedContrastSequence.combine(
            discordance: discordance, win: win, tally: tally
        )
        XCTAssertEqual(interval.lowerBound, -1)
        XCTAssertEqual(interval.upperBound, 1)
    }

    func testExclusionRejectsADifferenceOffTheScale() throws {
        let sequence = try sequence()
        let tally = try oneSidedTally()
        XCTAssertTrue(try sequence.excludes(0, tally: tally))
        XCTAssertFalse(try sequence.excludes(0.1, tally: tally))
        assertThrows(.differenceOutOfRange(1.5)) { try sequence.excludes(1.5, tally: tally) }
        assertThrows(.differenceOutOfRange(-1.5)) { try sequence.excludes(-1.5, tally: tally) }
    }
}
