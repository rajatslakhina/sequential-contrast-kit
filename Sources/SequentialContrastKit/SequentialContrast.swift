import Foundation

/// A construction that turns paired or unpaired outcome counts into a
/// time-uniform interval for the difference between two rates.
///
/// Conformers promise the same thing Ville's inequality promises a single-rate
/// sequence, transported across a union bound: for any true difference, the
/// probability that *any* reading in the whole sequence excludes it is at most
/// `alpha`. Every construction here is built from two component sequences, so
/// `componentAlpha` is the budget each one is allowed to spend.
public protocol SequentialContrast: Sendable {
    /// Total miscoverage budget spent across all looks and both components.
    var alpha: Double { get }

    /// The budget allotted to each of the two component sequences.
    var componentAlpha: Double { get }

    /// The differences not yet excluded by `tally`.
    func interval(for tally: ContrastTally) throws -> ContrastInterval
}
