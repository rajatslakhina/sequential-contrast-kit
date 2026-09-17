import Foundation

/// Every reading one component sequence can produce up to a horizon, indexed
/// `[trials][successes]`.
///
/// The rows are ragged on purpose: a row for `n` trials holds exactly the
/// `n + 1` success counts that can occur, and nothing above the diagonal. A
/// square table would need something to put in the unreachable half, and
/// whatever went there would be a value no test could ever read back.
struct ComponentTable: Sendable {
    private let rows: [[RateBounds]]

    /// Computes the whole reachable lattice once.
    ///
    /// This is the expensive part of every exact calculation in this package —
    /// each entry is two bisections — and it is why the solver builds tables
    /// rather than calling the construction per lattice point. A paired
    /// reading depends on `(n, n10, n01)`, but the two component readings
    /// underneath it depend only on `(n, n10 + n01)` and `(n10 + n01, n10)`,
    /// so `O(horizon^3)` difference intervals cost `O(horizon^2)` root-findings.
    static func build(for sequence: MixtureRateSequence, horizon: Int) throws -> ComponentTable {
        var rows: [[RateBounds]] = []
        rows.reserveCapacity(horizon + 1)
        for trials in 0...horizon {
            var row: [RateBounds] = []
            row.reserveCapacity(trials + 1)
            for successes in 0...trials {
                row.append(try sequence.interval(successes: successes, trials: trials))
            }
            rows.append(row)
        }
        return ComponentTable(rows: rows)
    }

    subscript(trials: Int, successes: Int) -> RateBounds { rows[trials][successes] }
}

/// The paired construction's difference readings over a whole lattice.
///
/// One table serves both roles. The discordance component is read at
/// `(items, discordant items)` and the win component at
/// `(discordant items, items A won)` — two different count streams through the
/// same construction, not two different constructions.
struct PairedComponentTable: Sendable {
    private let table: ComponentTable

    static func build(
        for sequence: PairedContrastSequence,
        horizon: Int
    ) throws -> PairedComponentTable {
        PairedComponentTable(
            table: try ComponentTable.build(for: sequence.componentSequence, horizon: horizon)
        )
    }

    /// The difference interval at one lattice point, assembled by the same
    /// combiner the live construction uses.
    func interval(trials: Int, onlyA: Int, onlyB: Int) throws -> ContrastInterval {
        let discordant = onlyA + onlyB
        let tally = try ContrastTally(
            bothSucceeded: 0,
            onlyASucceeded: onlyA,
            onlyBSucceeded: onlyB,
            neitherSucceeded: trials - discordant
        )
        return PairedContrastSequence.combine(
            discordance: table[trials, discordant],
            win: table[discordant, onlyA],
            tally: tally
        )
    }
}

/// The unpaired construction's difference readings over a whole lattice.
struct UnpairedComponentTable: Sendable {
    private let table: ComponentTable

    static func build(
        for sequence: UnpairedContrastSequence,
        horizon: Int
    ) throws -> UnpairedComponentTable {
        UnpairedComponentTable(
            table: try ComponentTable.build(for: sequence.armSequence, horizon: horizon)
        )
    }

    /// The difference interval at one lattice point, assembled by the same
    /// combiner the live construction uses.
    func interval(trials: Int, successesA: Int, successesB: Int) -> ContrastInterval {
        UnpairedContrastSequence.combine(
            armA: table[trials, successesA],
            armB: table[trials, successesB]
        )
    }
}

/// Exact log-weights for the cell counts the solver averages over.
enum ContrastWeights {
    /// `(n10, n01, concordant)` under a trinomial, which is all the paired
    /// reading depends on.
    static func trinomial(
        trials: Int,
        onlyA: Int,
        onlyB: Int,
        joint: PairedJointDistribution
    ) -> Double {
        let concordant = trials - onlyA - onlyB
        return LogBeta.logFactorial(trials)
            - LogBeta.logFactorial(onlyA)
            - LogBeta.logFactorial(onlyB)
            - LogBeta.logFactorial(concordant)
            + LogBeta.logPower(joint.onlyASucceeds, onlyA)
            + LogBeta.logPower(joint.onlyBSucceeds, onlyB)
            + LogBeta.logPower(joint.agreementRate, concordant)
    }

    /// All four cells, which the unpaired reading needs because its arm counts
    /// `n11 + n10` and `n11 + n01` are dependent under a paired joint.
    static func multinomial(
        trials: Int,
        both: Int,
        onlyA: Int,
        onlyB: Int,
        joint: PairedJointDistribution
    ) -> Double {
        let neither = trials - both - onlyA - onlyB
        return LogBeta.logFactorial(trials)
            - LogBeta.logFactorial(both)
            - LogBeta.logFactorial(onlyA)
            - LogBeta.logFactorial(onlyB)
            - LogBeta.logFactorial(neither)
            + LogBeta.logPower(joint.bothSucceed, both)
            + LogBeta.logPower(joint.onlyASucceeds, onlyA)
            + LogBeta.logPower(joint.onlyBSucceeds, onlyB)
            + LogBeta.logPower(joint.neitherSucceeds, neither)
    }
}
