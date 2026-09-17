import XCTest
@testable import SequentialContrastKit

final class ContrastMonitorTests: XCTestCase {
    private func oneSidedStream() -> [PairedOutcome] {
        var stream: [PairedOutcome] = []
        for index in 0..<120 {
            if index % 10 == 0 {
                stream.append(PairedOutcome(systemA: true, systemB: false))
            } else if index % 3 == 0 {
                stream.append(PairedOutcome(systemA: false, systemB: false))
            } else {
                stream.append(PairedOutcome(systemA: true, systemB: true))
            }
        }
        return stream
    }

    func testInitRejectsAReferenceOffTheScale() {
        assertThrows(.differenceOutOfRange(1.5)) {
            try ContrastMonitor(alpha: 0.05, referenceDifference: 1.5)
        }
        assertThrows(.differenceOutOfRange(-1.5)) {
            try ContrastMonitor(alpha: 0.05, referenceDifference: -1.5)
        }
        assertThrows(.alphaOutOfRange(0)) { try ContrastMonitor(alpha: 0) }
    }

    func testAMonitorWithNoReferenceWatchesNothing() async throws {
        let monitor = try ContrastMonitor(alpha: 0.05, referenceDifference: nil)
        try await monitor.observe(contentsOf: oneSidedStream())
        let reference = await monitor.referenceDifference
        let firstExclusion = await monitor.firstExclusionTrial
        let admissible = await monitor.referenceRemainsAdmissible()
        XCTAssertNil(reference)
        XCTAssertNil(firstExclusion)
        XCTAssertTrue(admissible)
    }

    func testObservingAnEmptyStreamLeavesTheMonitorUntouched() async throws {
        let monitor = try ContrastMonitor(alpha: 0.05)
        let interval = try await monitor.observe(contentsOf: [])
        let tally = await monitor.tally
        XCTAssertEqual(tally, .empty)
        XCTAssertEqual(interval.lowerBound, -1, accuracy: 1e-12)
        XCTAssertEqual(interval.upperBound, 1, accuracy: 1e-12)
    }

    func testTheFirstExclusionTrialIsRecordedOnceAndKept() async throws {
        let monitor = try ContrastMonitor(alpha: 0.05, referenceDifference: 0)
        try await monitor.observe(contentsOf: oneSidedStream())
        let recorded = await monitor.firstExclusionTrial
        let trial = try XCTUnwrap(recorded)
        let admissible = await monitor.referenceRemainsAdmissible()
        XCTAssertGreaterThan(trial, 0)
        XCTAssertLessThanOrEqual(trial, 120)
        XCTAssertFalse(admissible)

        // Feeding more of the same must not move the recorded trial.
        try await monitor.observe(PairedOutcome(systemA: true, systemB: false))
        let afterMore = await monitor.firstExclusionTrial
        XCTAssertEqual(afterMore, trial)
    }

    func testBothReadingsComeFromTheSameTallyAndThePairedOneIsNarrower() async throws {
        let monitor = try ContrastMonitor(alpha: 0.05)
        try await monitor.observe(contentsOf: oneSidedStream())
        let paired = try await monitor.pairedInterval()
        let unpaired = try await monitor.unpairedInterval()
        let gain = try await monitor.pairingGain()
        XCTAssertEqual(paired.trialsA, unpaired.trialsA)
        XCTAssertEqual(paired.successesA, unpaired.successesA)
        XCTAssertLessThan(paired.width, unpaired.width)
        XCTAssertEqual(gain, unpaired.width / paired.width, accuracy: 1e-12)
        XCTAssertGreaterThan(gain, 1)
    }

    func testObservingOneItemAtATimeMatchesObservingTheWholeStream() async throws {
        let stream = oneSidedStream()
        let byItem = try ContrastMonitor(alpha: 0.05)
        for outcome in stream {
            try await byItem.observe(outcome)
        }
        let wholesale = try ContrastMonitor(alpha: 0.05)
        try await wholesale.observe(contentsOf: stream)
        let byItemTally = await byItem.tally
        let wholesaleTally = await wholesale.tally
        XCTAssertEqual(byItemTally, wholesaleTally)
    }

    func testResetDropsObservationsButKeepsConfiguration() async throws {
        let monitor = try ContrastMonitor(alpha: 0.05, referenceDifference: 0)
        try await monitor.observe(contentsOf: oneSidedStream())
        await monitor.reset()
        let tally = await monitor.tally
        let firstExclusion = await monitor.firstExclusionTrial
        let admissible = await monitor.referenceRemainsAdmissible()
        let reference = await monitor.referenceDifference
        let pairedAlpha = await monitor.paired.alpha
        let unpairedAlpha = await monitor.unpaired.alpha
        XCTAssertEqual(tally, .empty)
        XCTAssertNil(firstExclusion)
        XCTAssertTrue(admissible)
        XCTAssertEqual(reference, 0)
        XCTAssertEqual(pairedAlpha, 0.05)
        XCTAssertEqual(unpairedAlpha, 0.05)
    }
}
