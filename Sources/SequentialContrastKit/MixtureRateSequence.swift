import Foundation

/// Robbins' beta-mixture confidence sequence for a single Bernoulli rate: the
/// component both contrast constructions are assembled from.
///
/// For a candidate rate `p`, every fixed alternative `q` gives a likelihood
/// ratio that is a non-negative martingale of mean one under `p`. Mixing those
/// ratios over a `Beta(a, b)` prior on `q` keeps the martingale property and
/// collapses the integral to a closed form:
///
/// ```
/// M_n(p) = B(a + k, b + n - k) / B(a, b) / (p^k * (1 - p)^(n - k))
/// ```
///
/// Ville's inequality bounds the probability that `M_n(p)` *ever* reaches
/// `1 / alpha` by `alpha`, for the whole sequence at once.
///
/// One property this package leans on harder than a single-rate package would:
/// the guarantee survives being read at a *subsequence*. `PairedContrastSequence`
/// advances one of its two components only on the items the systems disagreed
/// on, so that component is evaluated at a data-dependent, increasing index.
/// A martingale sampled along an increasing sequence of indices is still a
/// martingale, and "ever crosses at some discordant item" is a statement about
/// a subset of the indices "ever crosses at some item" already quantifies over.
public struct MixtureRateSequence: Sendable, Hashable {
    /// Miscoverage budget across all looks at this component.
    public let alpha: Double
    /// `a` of the `Beta(a, b)` mixing prior over the alternative rate.
    public let priorSuccesses: Double
    /// `b` of the `Beta(a, b)` mixing prior over the alternative rate.
    public let priorFailures: Double

    private static let searchFloor = 1e-300
    private static let searchCeiling = 1 - 1e-15
    private static let bisectionSteps = 100

    /// Builds a component sequence, rejecting any configuration whose
    /// martingale would not be well defined.
    ///
    /// The default `Beta(1, 1)` prior is uniform: it spreads the mixture evenly
    /// over every alternative rate, which is the honest choice when neither
    /// the discordance rate nor the win rate has a prior anchor.
    public init(alpha: Double, priorSuccesses: Double = 1, priorFailures: Double = 1) throws {
        guard alpha > 0, alpha < 1 else {
            throw ContrastError.alphaOutOfRange(alpha)
        }
        guard priorSuccesses > 0 else {
            throw ContrastError.priorParameterNotPositive(
                label: "priorSuccesses", value: priorSuccesses
            )
        }
        guard priorFailures > 0 else {
            throw ContrastError.priorParameterNotPositive(
                label: "priorFailures", value: priorFailures
            )
        }
        self.alpha = alpha
        self.priorSuccesses = priorSuccesses
        self.priorFailures = priorFailures
    }

    /// `log(1 / alpha)`, the level Ville's inequality bounds.
    public var logEvidenceThreshold: Double { -log(alpha) }

    /// Log of the mixture martingale evaluated against `rate`.
    ///
    /// Zero at `trials == 0` for every rate, by construction: no evidence has
    /// been gathered, so nothing is excluded.
    public func logEvidence(against rate: Double, successes: Int, trials: Int) throws -> Double {
        try validate(rate: rate, label: "rate")
        try validate(successes: successes, trials: trials)
        let failures = trials - successes
        let mixture = LogBeta.logBeta(priorSuccesses + Double(successes), priorFailures + Double(failures))
            - LogBeta.logBeta(priorSuccesses, priorFailures)
        let underRate = Double(successes) * log(rate) + Double(failures) * log1p(-rate)
        return mixture - underRate
    }

    /// Whether the evidence against `rate` has reached the Ville threshold.
    public func excludes(_ rate: Double, successes: Int, trials: Int) throws -> Bool {
        try logEvidence(against: rate, successes: successes, trials: trials) >= logEvidenceThreshold
    }

    /// The rates not yet excluded after `successes` of `trials`.
    ///
    /// The evidence curve is strictly convex in the candidate rate with its
    /// minimum at the observed rate, and that minimum is always below the
    /// threshold — the mixture averages likelihood ratios that are each at most
    /// one there — so the admissible set is always a single non-empty interval
    /// and never needs an empty-result case.
    ///
    /// At `trials == 0` the answer is the whole unit interval. That is not a
    /// defensive special case: it is the reading the paired construction takes
    /// on its win component for as long as the two systems have never
    /// disagreed, which on a well-matched pair of prompts can be a long time.
    public func interval(successes: Int, trials: Int) throws -> RateBounds {
        try validate(successes: successes, trials: trials)
        guard trials > 0 else {
            return RateBounds(lowerBound: 0, upperBound: 1, trials: 0, successes: 0)
        }
        let observed = Double(successes) / Double(trials)
        let lower = successes == 0
            ? 0
            : try lowerRoot(observed: observed, successes: successes, trials: trials)
        let upper = successes == trials
            ? 1
            : try upperRoot(observed: observed, successes: successes, trials: trials)
        return RateBounds(lowerBound: lower, upperBound: upper, trials: trials, successes: successes)
    }

    /// Bisects between an excluded floor and the admissible observed rate.
    private func lowerRoot(observed: Double, successes: Int, trials: Int) throws -> Double {
        var excludedEnd = Self.searchFloor
        var admissibleEnd = observed
        for _ in 0..<Self.bisectionSteps {
            let mid = 0.5 * (excludedEnd + admissibleEnd)
            if try excludes(mid, successes: successes, trials: trials) {
                excludedEnd = mid
            } else {
                admissibleEnd = mid
            }
        }
        return admissibleEnd
    }

    /// Bisects between the admissible observed rate and an excluded ceiling.
    private func upperRoot(observed: Double, successes: Int, trials: Int) throws -> Double {
        var admissibleEnd = observed
        var excludedEnd = Self.searchCeiling
        for _ in 0..<Self.bisectionSteps {
            let mid = 0.5 * (admissibleEnd + excludedEnd)
            if try excludes(mid, successes: successes, trials: trials) {
                excludedEnd = mid
            } else {
                admissibleEnd = mid
            }
        }
        return admissibleEnd
    }

    private func validate(rate: Double, label: String) throws {
        guard rate > 0, rate < 1 else {
            throw ContrastError.rateOutOfRange(label: label, value: rate)
        }
    }

    private func validate(successes: Int, trials: Int) throws {
        guard trials >= 0 else {
            throw ContrastError.trialsNegative(trials)
        }
        guard successes >= 0, successes <= trials else {
            throw ContrastError.successCountOutOfRange(successes: successes, trials: trials)
        }
    }
}
