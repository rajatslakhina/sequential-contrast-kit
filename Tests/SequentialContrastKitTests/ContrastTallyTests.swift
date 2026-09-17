import XCTest
@testable import SequentialContrastKit

final class ContrastTallyTests: XCTestCase {
    func testPairedOutcomeKnowsWhenTheSystemsDisagreed() {
        XCTAssertTrue(PairedOutcome(systemA: true, systemB: false).isDiscordant)
        XCTAssertTrue(PairedOutcome(systemA: false, systemB: true).isDiscordant)
        XCTAssertFalse(PairedOutcome(systemA: true, systemB: true).isDiscordant)
        XCTAssertFalse(PairedOutcome(systemA: false, systemB: false).isDiscordant)
    }

    func testInitRejectsEveryNegativeCell() {
        assertThrows(.cellCountNegative(label: "bothSucceeded", value: -1)) {
            try ContrastTally(bothSucceeded: -1, onlyASucceeded: 0, onlyBSucceeded: 0, neitherSucceeded: 0)
        }
        assertThrows(.cellCountNegative(label: "onlyASucceeded", value: -1)) {
            try ContrastTally(bothSucceeded: 0, onlyASucceeded: -1, onlyBSucceeded: 0, neitherSucceeded: 0)
        }
        assertThrows(.cellCountNegative(label: "onlyBSucceeded", value: -1)) {
            try ContrastTally(bothSucceeded: 0, onlyASucceeded: 0, onlyBSucceeded: -1, neitherSucceeded: 0)
        }
        assertThrows(.cellCountNegative(label: "neitherSucceeded", value: -1)) {
            try ContrastTally(bothSucceeded: 0, onlyASucceeded: 0, onlyBSucceeded: 0, neitherSucceeded: -1)
        }
    }

    func testDerivedCountsAddUp() throws {
        let tally = try oneSidedTally()
        XCTAssertEqual(tally.trials, 120)
        XCTAssertEqual(tally.discordantTrials, 12)
        XCTAssertEqual(tally.concordantTrials, 108)
        XCTAssertEqual(tally.successesA, 78)
        XCTAssertEqual(tally.successesB, 66)
        XCTAssertEqual(try XCTUnwrap(tally.observedDifference), 0.1, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(tally.agreementRate), 0.9, accuracy: 1e-12)
    }

    func testEmptyTallyHasNoObservedQuantities() {
        let empty = ContrastTally.empty
        XCTAssertEqual(empty.trials, 0)
        XCTAssertNil(empty.observedDifference)
        XCTAssertNil(empty.agreementRate)
    }

    func testAppendingRoutesEachOutcomeToItsOwnCell() {
        var tally = ContrastTally.empty
        tally = tally.appending(PairedOutcome(systemA: true, systemB: true))
        tally = tally.appending(PairedOutcome(systemA: true, systemB: false))
        tally = tally.appending(PairedOutcome(systemA: false, systemB: true))
        tally = tally.appending(PairedOutcome(systemA: false, systemB: false))
        XCTAssertEqual(tally.bothSucceeded, 1)
        XCTAssertEqual(tally.onlyASucceeded, 1)
        XCTAssertEqual(tally.onlyBSucceeded, 1)
        XCTAssertEqual(tally.neitherSucceeded, 1)
        XCTAssertEqual(tally.trials, 4)
    }

    func testDescriptionNamesAllFourCells() throws {
        XCTAssertEqual(
            try oneSidedTally().description,
            "both 66, A only 12, B only 0, neither 42"
        )
    }
}
