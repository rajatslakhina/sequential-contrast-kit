import Foundation

/// The exact behaviour of a contrast sequence against one reference
/// difference, computed by enumeration rather than simulated.
///
/// When `referenceDifference == trueDifference`, `exclusionProbability` *is*
/// the construction's realised miscoverage over the horizon — the quantity the
/// union bound over two Ville inequalities caps at `alpha`. When they differ,
/// the same number is the probability of detecting within the horizon that the
/// claimed difference is wrong.
///
/// `measuresMiscoverage` is what tells the two apart, and reading it off the
/// profile rather than off what the call site intended is the habit worth
/// keeping: a profile that has been passed around has lost the context that
/// said which question it answered.
public struct ExactContrastProfile: Sendable, Hashable {
    /// The difference whose exclusion was tracked.
    public let referenceDifference: Double
    /// The difference outcomes were actually generated at.
    public let trueDifference: Double
    /// Trials enumerated.
    public let horizon: Int
    /// Probability the reference left the interval at some trial within the
    /// horizon.
    public let exclusionProbability: Double
    /// Probability it never did.
    public let survivalProbability: Double
    /// Expected trial of first exclusion, conditional on excluding at all;
    /// `nil` when no path within the horizon excludes.
    public let expectedFirstExclusionTrial: Double?

    public init(
        referenceDifference: Double,
        trueDifference: Double,
        horizon: Int,
        exclusionProbability: Double,
        expectedFirstExclusionTrial: Double?
    ) {
        self.referenceDifference = referenceDifference
        self.trueDifference = trueDifference
        self.horizon = horizon
        self.exclusionProbability = exclusionProbability
        self.survivalProbability = 1 - exclusionProbability
        self.expectedFirstExclusionTrial = expectedFirstExclusionTrial
    }

    /// Whether the reference and true differences are the same, so
    /// `exclusionProbability` should be read as miscoverage rather than as
    /// detection power.
    public var measuresMiscoverage: Bool { referenceDifference == trueDifference }
}

extension ExactContrastProfile: CustomStringConvertible {
    public var description: String {
        let probability = String(format: "%.6f", exclusionProbability)
        let label = measuresMiscoverage ? "miscoverage" : "detection"
        return "\(label) \(probability) over \(horizon) trials"
    }
}
