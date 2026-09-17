import Foundation

/// A time-uniform confidence sequence for `p_A - p_B` that uses the pairing.
///
/// The decomposition is the old McNemar observation, run forwards into an
/// interval instead of a test. Write `d` for the probability the two systems
/// disagree on an item and `theta` for the probability A is the one that wins
/// given they disagreed. Then
///
/// ```
/// p_A - p_B = p10 - p01 = d * theta - d * (1 - theta) = d * (2 * theta - 1)
/// ```
///
/// and the items both systems got, or both missed, contribute nothing to the
/// difference at all. They are not noise to be averaged down; they are
/// genuinely uninformative about `p_A - p_B`, and a construction that spends
/// interval width on them is paying for information it did not receive.
///
/// So this ships two component sequences rather than one:
///
/// - a `MixtureRateSequence` for `d`, advancing on every item,
/// - a `MixtureRateSequence` for `theta`, advancing only on discordant items,
///
/// each at `alpha / 2`, combined by interval arithmetic on the product. On the
/// event that both components cover — probability at least `1 - alpha` by a
/// union bound — the product contains the true difference at every look
/// simultaneously.
///
/// The win component is read at a data-dependent index, which is the one point
/// in the argument worth stating rather than assuming. It is sound: a
/// non-negative martingale sampled along an increasing sequence of indices is
/// still one, so Ville's bound on "ever crosses" already quantifies over the
/// discordant subsequence.
public struct PairedContrastSequence: SequentialContrast, Sendable, Hashable {
    /// Total miscoverage budget across all looks and both components.
    public let alpha: Double
    /// The component construction, at `alpha / 2`, read over two different
    /// count streams: every item for the discordance rate, discordant items
    /// only for the win rate. One construction in two roles, not two
    /// constructions — which is also why the solver needs one table and not
    /// two.
    public let componentSequence: MixtureRateSequence

    /// Builds the pair of component sequences, splitting `alpha` evenly
    /// between them.
    public init(alpha: Double, priorSuccesses: Double = 1, priorFailures: Double = 1) throws {
        guard alpha > 0, alpha < 1 else {
            throw ContrastError.alphaOutOfRange(alpha)
        }
        self.alpha = alpha
        self.componentSequence = try MixtureRateSequence(
            alpha: alpha / 2, priorSuccesses: priorSuccesses, priorFailures: priorFailures
        )
    }

    /// `alpha / 2`, the union-bound split.
    public var componentAlpha: Double { alpha / 2 }

    /// The discordance-rate reading implied by `tally`.
    public func discordanceBounds(for tally: ContrastTally) throws -> RateBounds {
        try componentSequence.interval(successes: tally.discordantTrials, trials: tally.trials)
    }

    /// The win-rate reading implied by `tally`, taken over discordant items
    /// only.
    public func winBounds(for tally: ContrastTally) throws -> RateBounds {
        try componentSequence.interval(successes: tally.onlyASucceeded, trials: tally.discordantTrials)
    }

    /// The differences not yet excluded by `tally`.
    public func interval(for tally: ContrastTally) throws -> ContrastInterval {
        let discordance = try discordanceBounds(for: tally)
        let win = try winBounds(for: tally)
        return Self.combine(discordance: discordance, win: win, tally: tally)
    }

    /// Combines component readings into a difference interval.
    ///
    /// Exposed, and `static`, so `ContrastExclusionSolver` can drive the exact
    /// combination the live construction performs rather than reimplementing
    /// it against a cached component table. A solver that measures a slightly
    /// different construction than the one that ships is worse than no solver.
    ///
    /// `d` is non-negative and `2 * theta - 1` straddles zero, so the extremes
    /// of the product are not at fixed corners — they move with the sign of the
    /// win bounds. Taking the min and max over all four corners is correct in
    /// every case and needs no sign analysis to read.
    public static func combine(
        discordance: RateBounds,
        win: RateBounds,
        tally: ContrastTally
    ) -> ContrastInterval {
        let lowShift = 2 * win.lowerBound - 1
        let highShift = 2 * win.upperBound - 1
        let corners = (
            lowLow: discordance.lowerBound * lowShift,
            lowHigh: discordance.lowerBound * highShift,
            highLow: discordance.upperBound * lowShift,
            highHigh: discordance.upperBound * highShift
        )
        let lower = min(min(corners.lowLow, corners.lowHigh), min(corners.highLow, corners.highHigh))
        let upper = max(max(corners.lowLow, corners.lowHigh), max(corners.highLow, corners.highHigh))
        return ContrastInterval(
            lowerBound: max(-1, lower),
            upperBound: min(1, upper),
            trialsA: tally.trials,
            successesA: tally.successesA,
            trialsB: tally.trials,
            successesB: tally.successesB
        )
    }

    /// Whether the evidence in `tally` has ruled `difference` out.
    public func excludes(_ difference: Double, tally: ContrastTally) throws -> Bool {
        try validate(difference: difference)
        return try interval(for: tally).excludes(difference)
    }

    private func validate(difference: Double) throws {
        guard difference >= -1, difference <= 1 else {
            throw ContrastError.differenceOutOfRange(difference)
        }
    }
}
