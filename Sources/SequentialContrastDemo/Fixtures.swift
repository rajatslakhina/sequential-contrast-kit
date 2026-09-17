import Foundation
import SequentialContrastKit

/// Deterministic paired eval streams, so every number this demo prints can be
/// reproduced by anyone who runs it.
enum Fixtures {
    /// A small linear congruential generator, fixed constants, fixed seed.
    /// Nothing here needs cryptographic quality; it needs to produce the same
    /// stream on every machine, which `SystemRandomNumberGenerator` explicitly
    /// does not.
    struct Stream {
        private var state: UInt64

        init(seed: UInt64) {
            self.state = seed
        }

        mutating func nextUnit() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(1 << 53)
        }
    }

    /// Draws `count` paired items from `joint`.
    static func draw(
        count: Int,
        from joint: PairedJointDistribution,
        seed: UInt64
    ) -> [PairedOutcome] {
        var stream = Stream(seed: seed)
        var outcomes: [PairedOutcome] = []
        outcomes.reserveCapacity(count)
        for _ in 0..<count {
            outcomes.append(classify(stream.nextUnit(), in: joint))
        }
        return outcomes
    }

    private static func classify(_ draw: Double, in joint: PairedJointDistribution) -> PairedOutcome {
        if draw < joint.bothSucceed {
            return PairedOutcome(systemA: true, systemB: true)
        }
        if draw < joint.bothSucceed + joint.onlyASucceeds {
            return PairedOutcome(systemA: true, systemB: false)
        }
        if draw < joint.bothSucceed + joint.onlyASucceeds + joint.onlyBSucceeds {
            return PairedOutcome(systemA: false, systemB: true)
        }
        return PairedOutcome(systemA: false, systemB: false)
    }

    /// Spreads exact cell counts evenly across a stream, so a scenario that
    /// needs a specific tally gets it without waiting for a sampler to happen
    /// to produce one.
    static func spread(
        bothSucceeded: Int,
        onlyASucceeded: Int,
        onlyBSucceeded: Int,
        neitherSucceeded: Int
    ) -> [PairedOutcome] {
        let cells: [(PairedOutcome, Int)] = [
            (PairedOutcome(systemA: true, systemB: true), bothSucceeded),
            (PairedOutcome(systemA: true, systemB: false), onlyASucceeded),
            (PairedOutcome(systemA: false, systemB: true), onlyBSucceeded),
            (PairedOutcome(systemA: false, systemB: false), neitherSucceeded)
        ]
        let total = cells.reduce(0) { $0 + $1.1 }
        var remaining = cells
        var outcomes: [PairedOutcome] = []
        outcomes.reserveCapacity(total)
        for _ in 0..<total {
            let index = pick(from: remaining)
            outcomes.append(remaining[index].0)
            remaining[index].1 -= 1
        }
        return outcomes
    }

    /// Picks the cell with the most items still owed, which interleaves the
    /// four cells as evenly as their counts allow rather than emitting them in
    /// four blocks. A stream in blocks would make the early readings of any
    /// sequential construction meaningless.
    private static func pick(from cells: [(PairedOutcome, Int)]) -> Int {
        var best = 0
        var bestRemaining = -1
        for index in cells.indices where cells[index].1 > bestRemaining {
            bestRemaining = cells[index].1
            best = index
        }
        return best
    }

    /// Folds a stream into a tally.
    static func tally(of stream: [PairedOutcome]) -> ContrastTally {
        stream.reduce(ContrastTally.empty) { $0.appending($1) }
    }
}
