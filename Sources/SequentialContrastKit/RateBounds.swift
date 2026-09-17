import Foundation

/// One reading of a single-rate confidence sequence: the rates the evidence
/// has not yet ruled out, with the counts they came from.
///
/// Two of these are what every construction in this package combines into a
/// statement about a difference. They are exposed rather than hidden because
/// the components are where the width actually goes, and a caller comparing
/// constructions needs to see which half is paying.
public struct RateBounds: Sendable, Hashable {
    /// Smallest rate the evidence has not excluded.
    public let lowerBound: Double
    /// Largest rate the evidence has not excluded.
    public let upperBound: Double
    /// Trials the reading was computed from.
    public let trials: Int
    /// Successes among those trials.
    public let successes: Int

    public init(lowerBound: Double, upperBound: Double, trials: Int, successes: Int) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.trials = trials
        self.successes = successes
    }

    /// `upperBound - lowerBound`.
    public var width: Double { upperBound - lowerBound }

    /// The observed rate, or `nil` before any trial has been observed.
    public var observedRate: Double? {
        trials == 0 ? nil : Double(successes) / Double(trials)
    }

    /// Whether `rate` is still admissible under the evidence seen so far.
    public func contains(_ rate: Double) -> Bool {
        rate >= lowerBound && rate <= upperBound
    }
}

extension RateBounds: CustomStringConvertible {
    public var description: String {
        let lower = String(format: "%.6f", lowerBound)
        let upper = String(format: "%.6f", upperBound)
        return "[\(lower), \(upper)] after \(successes)/\(trials)"
    }
}
