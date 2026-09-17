import XCTest
@testable import SequentialContrastKit

final class ContrastExclusionSolverTests: XCTestCase {
    private func solver() throws -> ContrastExclusionSolver {
        try ContrastExclusionSolver(alpha: 0.05)
    }

    private func joint() throws -> PairedJointDistribution {
        try PairedJointDistribution(bothSucceed: 0.5, onlyASucceeds: 0.2, onlyBSucceeds: 0.1)
    }

    func testBothInitialisersAgree() throws {
        let assembled = ContrastExclusionSolver(
            paired: try PairedContrastSequence(alpha: 0.05),
            unpaired: try UnpairedContrastSequence(alpha: 0.05)
        )
        let direct = try solver()
        XCTAssertEqual(assembled.paired, direct.paired)
        XCTAssertEqual(assembled.unpaired, direct.unpaired)
        assertThrows(.alphaOutOfRange(0)) { try ContrastExclusionSolver(alpha: 0) }
    }

    func testProfilesRejectImpossibleArguments() throws {
        let solver = try solver()
        let joint = try joint()
        assertThrows(.differenceOutOfRange(2)) {
            try solver.pairedProfile(referenceDifference: 2, joint: joint, horizon: 4)
        }
        assertThrows(.horizonBelowOne(0)) {
            try solver.pairedProfile(referenceDifference: 0, joint: joint, horizon: 0)
        }
        assertThrows(.differenceOutOfRange(-2)) {
            try solver.unpairedProfile(referenceDifference: -2, joint: joint, horizon: 4)
        }
        assertThrows(.horizonBelowOne(-1)) {
            try solver.unpairedProfile(referenceDifference: 0, joint: joint, horizon: -1)
        }
    }

    func testMiscoverageStaysUnderTheNominalBudget() throws {
        let solver = try solver()
        let joint = try joint()
        let paired = try solver.pairedProfile(
            referenceDifference: joint.difference, joint: joint, horizon: 12
        )
        let unpaired = try solver.unpairedProfile(
            referenceDifference: joint.difference, joint: joint, horizon: 12
        )
        XCTAssertTrue(paired.measuresMiscoverage)
        XCTAssertTrue(unpaired.measuresMiscoverage)
        XCTAssertLessThanOrEqual(paired.exclusionProbability, 0.05)
        XCTAssertLessThanOrEqual(unpaired.exclusionProbability, 0.05)
        XCTAssertGreaterThanOrEqual(paired.exclusionProbability, 0)
        XCTAssertEqual(paired.horizon, 12)
        XCTAssertEqual(paired.trueDifference, joint.difference, accuracy: 1e-12)
    }

    func testProbabilityMassIsConservedByTheWalk() throws {
        let solver = try solver()
        let joint = try joint()
        let profile = try solver.pairedProfile(
            referenceDifference: 0, joint: joint, horizon: 10
        )
        XCTAssertEqual(
            profile.exclusionProbability + profile.survivalProbability, 1, accuracy: 1e-12
        )
        XCTAssertFalse(profile.measuresMiscoverage)
    }

    func testAJointThatNeverDisagreesNeverExcludesZero() throws {
        let solver = try solver()
        let joint = try neverDisagree()
        let profile = try solver.pairedProfile(
            referenceDifference: 0, joint: joint, horizon: 10
        )
        XCTAssertEqual(profile.exclusionProbability, 0, accuracy: 1e-15)
        XCTAssertNil(profile.expectedFirstExclusionTrial)
        XCTAssertTrue(profile.measuresMiscoverage)
    }

    func testAnObviousDifferenceIsDetectedAndTimed() throws {
        let solver = try solver()
        let joint = try PairedJointDistribution(
            bothSucceed: 0.0, onlyASucceeds: 0.98, onlyBSucceeds: 0.0
        )
        let profile = try solver.pairedProfile(
            referenceDifference: 0, joint: joint, horizon: 12
        )
        XCTAssertGreaterThan(profile.exclusionProbability, 0.5)
        let trial = try XCTUnwrap(profile.expectedFirstExclusionTrial)
        XCTAssertGreaterThan(trial, 0)
        XCTAssertLessThanOrEqual(trial, 12)
    }

    func testWidthComparisonAgreesWithTheIndividualWidths() throws {
        let solver = try solver()
        let joint = try joint()
        let comparison = try solver.widthComparison(trials: 8, joint: joint)
        XCTAssertEqual(
            comparison.pairedWidth,
            try solver.expectedPairedWidth(trials: 8, joint: joint),
            accuracy: 1e-12
        )
        XCTAssertEqual(
            comparison.unpairedWidth,
            try solver.expectedUnpairedWidth(trials: 8, joint: joint),
            accuracy: 1e-12
        )
        XCTAssertEqual(
            comparison.pairingGain,
            try solver.pairingGain(trials: 8, joint: joint),
            accuracy: 1e-12
        )
        XCTAssertEqual(comparison.trials, 8)
    }

    func testWidthsRejectAnEmptyHorizon() throws {
        let solver = try solver()
        let joint = try joint()
        assertThrows(.horizonBelowOne(0)) { try solver.widthComparison(trials: 0, joint: joint) }
        assertThrows(.horizonBelowOne(0)) { try solver.expectedPairedWidth(trials: 0, joint: joint) }
        assertThrows(.horizonBelowOne(0)) { try solver.expectedUnpairedWidth(trials: 0, joint: joint) }
    }

    func testPairingIsWorthMoreTheMoreTheSystemsAgree() throws {
        let solver = try solver()
        let agreeOften = try PairedJointDistribution(
            bothSucceed: 0.58, onlyASucceeds: 0.12, onlyBSucceeds: 0.0
        )
        let agreeRarely = try PairedJointDistribution(
            bothSucceed: 0.36, onlyASucceeds: 0.34, onlyBSucceeds: 0.22
        )
        let high = try solver.pairingGain(trials: 10, joint: agreeOften)
        let low = try solver.pairingGain(trials: 10, joint: agreeRarely)
        XCTAssertGreaterThan(high, low)
        XCTAssertGreaterThan(high, 1)
    }

    func testWidthsHandleCellsOfExactlyZeroProbability() throws {
        let solver = try solver()
        let joint = try neverDisagree()
        let comparison = try solver.widthComparison(trials: 6, joint: joint)
        XCTAssertFalse(comparison.pairedWidth.isNaN)
        XCTAssertFalse(comparison.unpairedWidth.isNaN)
        XCTAssertGreaterThan(comparison.pairedWidth, 0)
        XCTAssertGreaterThan(comparison.unpairedWidth, 0)
    }

    func testTheSolverTablesReproduceTheLiveConstructionExactly() throws {
        let solver = try solver()
        let pairedTable = try PairedComponentTable.build(for: solver.paired, horizon: 9)
        let unpairedTable = try UnpairedComponentTable.build(for: solver.unpaired, horizon: 9)
        for trials in 0...9 {
            for onlyA in 0...trials {
                for onlyB in 0...(trials - onlyA) {
                    let tally = try ContrastTally(
                        bothSucceeded: 0,
                        onlyASucceeded: onlyA,
                        onlyBSucceeded: onlyB,
                        neitherSucceeded: trials - onlyA - onlyB
                    )
                    XCTAssertEqual(
                        try pairedTable.interval(trials: trials, onlyA: onlyA, onlyB: onlyB),
                        try solver.paired.interval(for: tally)
                    )
                    XCTAssertEqual(
                        unpairedTable.interval(
                            trials: trials, successesA: onlyA, successesB: onlyB
                        ),
                        try solver.unpaired.interval(
                            successesA: onlyA, trialsA: trials,
                            successesB: onlyB, trialsB: trials
                        )
                    )
                }
            }
        }
    }

    func testExpectedWidthsAreAProperAverageOverTheReachableStates() throws {
        let solver = try solver()
        let joint = try joint()
        let width = try solver.expectedPairedWidth(trials: 5, joint: joint)
        var minimum = Double.infinity
        var maximum = -Double.infinity
        for onlyA in 0...5 {
            for onlyB in 0...(5 - onlyA) {
                let tally = try ContrastTally(
                    bothSucceeded: 0,
                    onlyASucceeded: onlyA,
                    onlyBSucceeded: onlyB,
                    neitherSucceeded: 5 - onlyA - onlyB
                )
                let candidate = try solver.paired.interval(for: tally).width
                minimum = min(minimum, candidate)
                maximum = max(maximum, candidate)
            }
        }
        XCTAssertGreaterThanOrEqual(width, minimum - 1e-12)
        XCTAssertLessThanOrEqual(width, maximum + 1e-12)
    }
}
