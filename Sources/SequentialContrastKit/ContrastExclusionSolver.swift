import Foundation

/// Computes what these constructions actually do, by enumerating their entire
/// reachable state space rather than sampling from it.
///
/// Both promises here are upper bounds. A union bound over two Ville
/// inequalities says miscoverage is at most `alpha`; it does not say how much
/// of `alpha` is actually spent, and whatever is left unspent has been paid
/// for in interval width. Simulation would estimate that with its own error
/// bars stacked on top of the thing being measured.
///
/// The state spaces are small because both readings factor. A paired reading
/// after `n` items depends only on `(n, n10, n01)`, and within that, only on
/// two component readings indexed by `(n, n10 + n01)` and `(n10 + n01, n10)`.
/// So the component tables are `O(horizon^2)` and the walk over them is
/// `O(horizon^3)` table lookups rather than `O(horizon^3)` root-findings — the
/// difference between a solver that runs in milliseconds and one that does not
/// finish.
public struct ContrastExclusionSolver: Sendable {
    /// The construction that uses the pairing.
    public let paired: PairedContrastSequence
    /// The construction that discards it.
    public let unpaired: UnpairedContrastSequence

    public init(paired: PairedContrastSequence, unpaired: UnpairedContrastSequence) {
        self.paired = paired
        self.unpaired = unpaired
    }

    /// Builds both constructions at one shared `alpha`.
    public init(alpha: Double) throws {
        self.init(
            paired: try PairedContrastSequence(alpha: alpha),
            unpaired: try UnpairedContrastSequence(alpha: alpha)
        )
    }

    // MARK: - Exclusion profiles

    /// Exact probability that the paired construction excludes
    /// `referenceDifference` at some trial within `horizon`, when items are
    /// drawn from `joint`.
    public func pairedProfile(
        referenceDifference: Double,
        joint: PairedJointDistribution,
        horizon: Int
    ) throws -> ExactContrastProfile {
        try validate(difference: referenceDifference)
        try validate(horizon: horizon)
        let walk = try pairedWalk(
            referenceDifference: referenceDifference, joint: joint, horizon: horizon
        )
        return profile(
            reference: referenceDifference, joint: joint, horizon: horizon, walk: walk
        )
    }

    /// The same question asked of the construction that throws the pairing
    /// away, on identically distributed data.
    public func unpairedProfile(
        referenceDifference: Double,
        joint: PairedJointDistribution,
        horizon: Int
    ) throws -> ExactContrastProfile {
        try validate(difference: referenceDifference)
        try validate(horizon: horizon)
        let walk = try unpairedWalk(
            referenceDifference: referenceDifference, joint: joint, horizon: horizon
        )
        return profile(
            reference: referenceDifference, joint: joint, horizon: horizon, walk: walk
        )
    }

    private func profile(
        reference: Double,
        joint: PairedJointDistribution,
        horizon: Int,
        walk: Walk
    ) -> ExactContrastProfile {
        ExactContrastProfile(
            referenceDifference: reference,
            trueDifference: joint.difference,
            horizon: horizon,
            exclusionProbability: walk.excludedMass,
            expectedFirstExclusionTrial: walk.expectedTrial
        )
    }

    // MARK: - Expected widths

    /// Both expected widths on the same data, computed from one set of
    /// component readings.
    ///
    /// The three width questions share every component reading between them,
    /// and asking them one at a time rebuilds those readings from scratch each
    /// time. That is not a micro-optimisation worth skipping: a win table at
    /// 80 items is several thousand root-findings and it is essentially the
    /// entire cost of the call.
    public func widthComparison(
        trials: Int,
        joint: PairedJointDistribution
    ) throws -> WidthComparison {
        try validate(horizon: trials)
        return WidthComparison(
            trials: trials,
            pairedWidth: try pairedWidth(
                trials: trials,
                joint: joint,
                table: try PairedComponentTable.build(for: paired, horizon: trials)
            ),
            unpairedWidth: unpairedWidth(
                trials: trials,
                joint: joint,
                table: try UnpairedComponentTable.build(for: unpaired, horizon: trials)
            )
        )
    }

    /// Exact expected width of the paired interval after `trials` items drawn
    /// from `joint`, averaged over the trinomial distribution of
    /// `(n10, n01, concordant)`.
    public func expectedPairedWidth(trials: Int, joint: PairedJointDistribution) throws -> Double {
        try validate(horizon: trials)
        return try pairedWidth(
            trials: trials,
            joint: joint,
            table: try PairedComponentTable.build(for: paired, horizon: trials)
        )
    }

    /// Exact expected width of the unpaired interval on the same data.
    ///
    /// This one needs all four cells rather than three, because the arm counts
    /// `kA = n11 + n10` and `kB = n11 + n01` are dependent under a paired
    /// joint, and averaging them as if they were independent would quietly
    /// measure a different experiment.
    public func expectedUnpairedWidth(trials: Int, joint: PairedJointDistribution) throws -> Double {
        try validate(horizon: trials)
        return unpairedWidth(
            trials: trials,
            joint: joint,
            table: try UnpairedComponentTable.build(for: unpaired, horizon: trials)
        )
    }

    /// How many times wider the unpaired interval is than the paired one, in
    /// expectation, on the same data. The number that says what recording the
    /// pairing was worth.
    public func pairingGain(trials: Int, joint: PairedJointDistribution) throws -> Double {
        try widthComparison(trials: trials, joint: joint).pairingGain
    }

    private func pairedWidth(
        trials: Int,
        joint: PairedJointDistribution,
        table: PairedComponentTable
    ) throws -> Double {
        var total = 0.0
        for onlyA in 0...trials {
            for onlyB in 0...(trials - onlyA) {
                let weight = exp(ContrastWeights.trinomial(
                    trials: trials, onlyA: onlyA, onlyB: onlyB, joint: joint
                ))
                let width = try table.interval(trials: trials, onlyA: onlyA, onlyB: onlyB).width
                total += weight * width
            }
        }
        return total
    }

    private func unpairedWidth(
        trials: Int,
        joint: PairedJointDistribution,
        table: UnpairedComponentTable
    ) -> Double {
        var total = 0.0
        for both in 0...trials {
            for onlyA in 0...(trials - both) {
                for onlyB in 0...(trials - both - onlyA) {
                    let weight = exp(ContrastWeights.multinomial(
                        trials: trials, both: both, onlyA: onlyA, onlyB: onlyB, joint: joint
                    ))
                    let width = table.interval(
                        trials: trials, successesA: both + onlyA, successesB: both + onlyB
                    ).width
                    total += weight * width
                }
            }
        }
        return total
    }

    // MARK: - Walks

    private struct Walk {
        var excludedMass = 0.0
        var trialWeightedMass = 0.0

        var expectedTrial: Double? {
            excludedMass > 0 ? trialWeightedMass / excludedMass : nil
        }

        mutating func retire(mass: Double, atTrial trial: Int) {
            excludedMass += mass
            trialWeightedMass += Double(trial) * mass
        }
    }

    private func pairedWalk(
        referenceDifference: Double,
        joint: PairedJointDistribution,
        horizon: Int
    ) throws -> Walk {
        let table = try PairedComponentTable.build(for: paired, horizon: horizon)
        let concordant = 1 - joint.discordanceRate
        var alive = Self.lattice(horizon)
        alive[0][0] = 1
        var walk = Walk()
        for trial in 1...horizon {
            var next = Self.lattice(horizon)
            for onlyA in 0..<trial {
                for onlyB in 0..<(trial - onlyA) {
                    let mass = alive[onlyA][onlyB]
                    next[onlyA + 1][onlyB] += mass * joint.onlyASucceeds
                    next[onlyA][onlyB + 1] += mass * joint.onlyBSucceeds
                    next[onlyA][onlyB] += mass * concordant
                }
            }
            for onlyA in 0...trial {
                for onlyB in 0...(trial - onlyA) where try table.interval(
                    trials: trial, onlyA: onlyA, onlyB: onlyB
                ).excludes(referenceDifference) {
                    walk.retire(mass: next[onlyA][onlyB], atTrial: trial)
                    next[onlyA][onlyB] = 0
                }
            }
            alive = next
        }
        return walk
    }

    private func unpairedWalk(
        referenceDifference: Double,
        joint: PairedJointDistribution,
        horizon: Int
    ) throws -> Walk {
        let table = try UnpairedComponentTable.build(for: unpaired, horizon: horizon)
        var alive = Self.lattice(horizon)
        alive[0][0] = 1
        var walk = Walk()
        for trial in 1...horizon {
            var next = Self.lattice(horizon)
            for successesA in 0..<trial {
                for successesB in 0..<trial {
                    let mass = alive[successesA][successesB]
                    next[successesA + 1][successesB + 1] += mass * joint.bothSucceed
                    next[successesA + 1][successesB] += mass * joint.onlyASucceeds
                    next[successesA][successesB + 1] += mass * joint.onlyBSucceeds
                    next[successesA][successesB] += mass * joint.neitherSucceeds
                }
            }
            for successesA in 0...trial {
                for successesB in 0...trial where table.interval(
                    trials: trial, successesA: successesA, successesB: successesB
                ).excludes(referenceDifference) {
                    walk.retire(mass: next[successesA][successesB], atTrial: trial)
                    next[successesA][successesB] = 0
                }
            }
            alive = next
        }
        return walk
    }

    private static func lattice(_ horizon: Int) -> [[Double]] {
        Array(repeating: [Double](repeating: 0, count: horizon + 2), count: horizon + 2)
    }

    private func validate(difference: Double) throws {
        guard difference >= -1, difference <= 1 else {
            throw ContrastError.differenceOutOfRange(difference)
        }
    }

    private func validate(horizon: Int) throws {
        guard horizon >= 1 else {
            throw ContrastError.horizonBelowOne(horizon)
        }
    }
}
