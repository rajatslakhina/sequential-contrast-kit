import Foundation

/// A time-uniform confidence sequence for `p_A - p_B` built from the two
/// margins alone.
///
/// One `MixtureRateSequence` per arm at `alpha / 2`, and the difference is the
/// Minkowski difference of the two readings:
///
/// ```
/// p_A - p_B  in  [ lowerA - upperB , upperA - lowerB ]
/// ```
///
/// This is the right construction when the two arms genuinely are separate
/// samples — different eval sets, different traffic, an online arm against an
/// offline one. It is also what a paired comparison degrades into when the
/// pairing is not recorded, and that is the more common situation in practice:
/// the data was paired all along and the analysis threw it away.
///
/// Because the bounds are a Minkowski difference of two intervals, this
/// construction can never exclude zero while the two arm intervals overlap.
/// That is not a conservative choice, it is an identity — and it is exactly the
/// ceiling `PairedContrastSequence` is built to get above.
public struct UnpairedContrastSequence: SequentialContrast, Sendable, Hashable {
    /// Total miscoverage budget across all looks and both arms.
    public let alpha: Double
    /// The per-arm component, shared by both arms because they are scored the
    /// same way.
    public let armSequence: MixtureRateSequence

    /// Builds the arm component, splitting `alpha` evenly between the two arms.
    public init(alpha: Double, priorSuccesses: Double = 1, priorFailures: Double = 1) throws {
        guard alpha > 0, alpha < 1 else {
            throw ContrastError.alphaOutOfRange(alpha)
        }
        self.alpha = alpha
        self.armSequence = try MixtureRateSequence(
            alpha: alpha / 2, priorSuccesses: priorSuccesses, priorFailures: priorFailures
        )
    }

    /// `alpha / 2`, the union-bound split.
    public var componentAlpha: Double { alpha / 2 }

    /// The differences not yet excluded, from two independently sized arms.
    public func interval(
        successesA: Int,
        trialsA: Int,
        successesB: Int,
        trialsB: Int
    ) throws -> ContrastInterval {
        let armA = try armSequence.interval(successes: successesA, trials: trialsA)
        let armB = try armSequence.interval(successes: successesB, trials: trialsB)
        return Self.combine(armA: armA, armB: armB)
    }

    /// The differences not yet excluded by `tally`, reading only its margins.
    ///
    /// The pairing in `tally` is discarded here on purpose. Handing the same
    /// tally to both constructions is what makes their comparison a statement
    /// about method rather than about data.
    public func interval(for tally: ContrastTally) throws -> ContrastInterval {
        try interval(
            successesA: tally.successesA,
            trialsA: tally.trials,
            successesB: tally.successesB,
            trialsB: tally.trials
        )
    }

    /// Combines two arm readings into a difference interval.
    ///
    /// Exposed, and `static`, for the same reason the paired construction's
    /// combiner is: the solver must drive the shipping combination rather than
    /// a copy of it.
    public static func combine(armA: RateBounds, armB: RateBounds) -> ContrastInterval {
        ContrastInterval(
            lowerBound: max(-1, armA.lowerBound - armB.upperBound),
            upperBound: min(1, armA.upperBound - armB.lowerBound),
            trialsA: armA.trials,
            successesA: armA.successes,
            trialsB: armB.trials,
            successesB: armB.successes
        )
    }

    /// Whether the evidence in `tally` has ruled `difference` out.
    public func excludes(_ difference: Double, tally: ContrastTally) throws -> Bool {
        guard difference >= -1, difference <= 1 else {
            throw ContrastError.differenceOutOfRange(difference)
        }
        return try interval(for: tally).excludes(difference)
    }
}
