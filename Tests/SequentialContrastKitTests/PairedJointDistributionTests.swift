import XCTest
@testable import SequentialContrastKit

final class PairedJointDistributionTests: XCTestCase {
    func testInitRejectsNegativeCellsAndOverfullMass() {
        assertThrows(.cellProbabilityNegative(label: "bothSucceed", value: -0.1)) {
            try PairedJointDistribution(bothSucceed: -0.1, onlyASucceeds: 0.2, onlyBSucceeds: 0.1)
        }
        assertThrows(.cellProbabilityNegative(label: "onlyASucceeds", value: -0.2)) {
            try PairedJointDistribution(bothSucceed: 0.1, onlyASucceeds: -0.2, onlyBSucceeds: 0.1)
        }
        assertThrows(.cellProbabilityNegative(label: "onlyBSucceeds", value: -0.3)) {
            try PairedJointDistribution(bothSucceed: 0.1, onlyASucceeds: 0.2, onlyBSucceeds: -0.3)
        }
        assertThrows(.cellProbabilitiesExceedOne(1.2)) {
            try PairedJointDistribution(bothSucceed: 0.6, onlyASucceeds: 0.4, onlyBSucceeds: 0.2)
        }
    }

    func testMarginalsAndDifferenceAgree() throws {
        let joint = try PairedJointDistribution(
            bothSucceed: 0.58, onlyASucceeds: 0.14, onlyBSucceeds: 0.04
        )
        XCTAssertEqual(joint.neitherSucceeds, 0.24, accuracy: 1e-12)
        XCTAssertEqual(joint.rateA, 0.72, accuracy: 1e-12)
        XCTAssertEqual(joint.rateB, 0.62, accuracy: 1e-12)
        XCTAssertEqual(joint.difference, joint.rateA - joint.rateB, accuracy: 1e-12)
        XCTAssertEqual(joint.discordanceRate, 0.18, accuracy: 1e-12)
        XCTAssertEqual(joint.agreementRate, 0.82, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(joint.winRateGivenDiscordant), 0.14 / 0.18, accuracy: 1e-12)
    }

    func testWinRateIsUndefinedWhenTheSystemsNeverDisagree() throws {
        let joint = try neverDisagree()
        XCTAssertEqual(joint.discordanceRate, 0)
        XCTAssertNil(joint.winRateGivenDiscordant)
        XCTAssertEqual(joint.difference, 0)
    }

    func testIndependentJointFactorises() throws {
        let joint = try PairedJointDistribution.independent(rateA: 0.7, rateB: 0.4)
        XCTAssertEqual(joint.rateA, 0.7, accuracy: 1e-12)
        XCTAssertEqual(joint.rateB, 0.4, accuracy: 1e-12)
        XCTAssertEqual(joint.bothSucceed, 0.28, accuracy: 1e-12)
        XCTAssertEqual(joint.neitherSucceeds, 0.18, accuracy: 1e-12)
    }

    func testDescriptionListsFourCells() throws {
        XCTAssertEqual(
            try PairedJointDistribution(bothSucceed: 0.5, onlyASucceeds: 0.25, onlyBSucceeds: 0.125)
                .description,
            "(0.5000, 0.2500, 0.1250, 0.1250)"
        )
    }
}
