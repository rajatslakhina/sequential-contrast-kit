import XCTest
@testable import SequentialContrastKit

final class MixtureRateSequenceTests: XCTestCase {
    private func sequence(alpha: Double = 0.05) throws -> MixtureRateSequence {
        try MixtureRateSequence(alpha: alpha)
    }

    func testInitRejectsEveryMalformedConfiguration() {
        assertThrows(.alphaOutOfRange(0)) { try MixtureRateSequence(alpha: 0) }
        assertThrows(.alphaOutOfRange(1)) { try MixtureRateSequence(alpha: 1) }
        assertThrows(.priorParameterNotPositive(label: "priorSuccesses", value: 0)) {
            try MixtureRateSequence(alpha: 0.05, priorSuccesses: 0)
        }
        assertThrows(.priorParameterNotPositive(label: "priorFailures", value: -1)) {
            try MixtureRateSequence(alpha: 0.05, priorFailures: -1)
        }
    }

    func testThresholdIsLogOfOneOverAlpha() throws {
        XCTAssertEqual(try sequence(alpha: 0.05).logEvidenceThreshold, -log(0.05), accuracy: 1e-12)
    }

    func testEvidenceIsZeroBeforeAnyTrialAndRejectsBadArguments() throws {
        let sequence = try sequence()
        XCTAssertEqual(try sequence.logEvidence(against: 0.5, successes: 0, trials: 0), 0, accuracy: 1e-12)
        assertThrows(.rateOutOfRange(label: "rate", value: 0)) {
            try sequence.logEvidence(against: 0, successes: 1, trials: 2)
        }
        assertThrows(.rateOutOfRange(label: "rate", value: 1)) {
            try sequence.logEvidence(against: 1, successes: 1, trials: 2)
        }
        assertThrows(.trialsNegative(-1)) {
            try sequence.logEvidence(against: 0.5, successes: 0, trials: -1)
        }
        assertThrows(.successCountOutOfRange(successes: 3, trials: 2)) {
            try sequence.logEvidence(against: 0.5, successes: 3, trials: 2)
        }
        assertThrows(.successCountOutOfRange(successes: -1, trials: 2)) {
            try sequence.logEvidence(against: 0.5, successes: -1, trials: 2)
        }
    }

    func testEvidenceMatchesTheClosedFormItDocuments() throws {
        let sequence = try sequence()
        let successes = 7
        let trials = 10
        let rate = 0.4
        let expected = LogBeta.logBeta(1 + Double(successes), 1 + Double(trials - successes))
            - LogBeta.logBeta(1, 1)
            - (Double(successes) * log(rate) + Double(trials - successes) * log1p(-rate))
        XCTAssertEqual(
            try sequence.logEvidence(against: rate, successes: successes, trials: trials),
            expected,
            accuracy: 1e-12
        )
    }

    func testIntervalIsTheWholeUnitIntervalBeforeAnyTrial() throws {
        let bounds = try sequence().interval(successes: 0, trials: 0)
        XCTAssertEqual(bounds.lowerBound, 0)
        XCTAssertEqual(bounds.upperBound, 1)
        XCTAssertNil(bounds.observedRate)
    }

    func testIntervalSaturatesAtTheEndsWhenEveryTrialAgrees() throws {
        let sequence = try sequence()
        let allFailures = try sequence.interval(successes: 0, trials: 20)
        XCTAssertEqual(allFailures.lowerBound, 0)
        XCTAssertLessThan(allFailures.upperBound, 1)
        let allSuccesses = try sequence.interval(successes: 20, trials: 20)
        XCTAssertEqual(allSuccesses.upperBound, 1)
        XCTAssertGreaterThan(allSuccesses.lowerBound, 0)
    }

    func testIntervalBracketsTheObservedRateAndShrinksWithEvidence() throws {
        let sequence = try sequence()
        let short = try sequence.interval(successes: 15, trials: 30)
        let long = try sequence.interval(successes: 150, trials: 300)
        XCTAssertTrue(short.contains(0.5))
        XCTAssertTrue(long.contains(0.5))
        XCTAssertLessThan(long.width, short.width)
    }

    func testIntervalIsExactlyTheSetOfRatesNotExcluded() throws {
        let sequence = try sequence()
        let bounds = try sequence.interval(successes: 12, trials: 40)
        let inside = 0.5 * (bounds.lowerBound + bounds.upperBound)
        XCTAssertFalse(try sequence.excludes(inside, successes: 12, trials: 40))
        XCTAssertTrue(try sequence.excludes(bounds.lowerBound * 0.5, successes: 12, trials: 40))
        XCTAssertTrue(
            try sequence.excludes(bounds.upperBound + 0.5 * (1 - bounds.upperBound),
                                  successes: 12, trials: 40)
        )
    }

    func testIntervalRejectsImpossibleCounts() throws {
        let sequence = try sequence()
        assertThrows(.trialsNegative(-2)) { try sequence.interval(successes: 0, trials: -2) }
        assertThrows(.successCountOutOfRange(successes: 4, trials: 3)) {
            try sequence.interval(successes: 4, trials: 3)
        }
    }
}
