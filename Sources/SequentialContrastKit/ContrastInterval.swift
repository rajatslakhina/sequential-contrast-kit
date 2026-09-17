import Foundation

/// One reading of a contrast sequence: the differences `p_A - p_B` the
/// evidence has not yet ruled out.
///
/// The bounds are *anytime-valid*. Looking after every eval run costs nothing,
/// because the budget was spent once over the whole sequence rather than once
/// per look.
///
/// `excludesZero` is the question most callers actually have, and it is not
/// the same question as "do the two single-rate intervals overlap". Two
/// heavily overlapping marginal intervals are entirely compatible with a
/// difference interval that has ruled zero out, whenever the two systems are
/// scored on the same items and one of them keeps winning the items they
/// disagree on. Reading overlap as "no difference" is the error this type
/// exists to make hard.
public struct ContrastInterval: Sendable, Hashable {
    /// Smallest difference the evidence has not excluded.
    public let lowerBound: Double
    /// Largest difference the evidence has not excluded.
    public let upperBound: Double
    /// Trials observed on arm A.
    public let trialsA: Int
    /// Successes among them.
    public let successesA: Int
    /// Trials observed on arm B.
    public let trialsB: Int
    /// Successes among them.
    public let successesB: Int

    public init(
        lowerBound: Double,
        upperBound: Double,
        trialsA: Int,
        successesA: Int,
        trialsB: Int,
        successesB: Int
    ) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.trialsA = trialsA
        self.successesA = successesA
        self.trialsB = trialsB
        self.successesB = successesB
    }

    /// `upperBound - lowerBound`.
    public var width: Double { upperBound - lowerBound }

    /// The observed difference in rates, or `nil` while either arm is empty.
    public var observedDifference: Double? {
        guard trialsA > 0, trialsB > 0 else { return nil }
        return Double(successesA) / Double(trialsA) - Double(successesB) / Double(trialsB)
    }

    /// Whether `difference` is still admissible under the evidence so far.
    public func contains(_ difference: Double) -> Bool {
        difference >= lowerBound && difference <= upperBound
    }

    /// Whether the evidence has ruled `difference` out.
    public func excludes(_ difference: Double) -> Bool {
        !contains(difference)
    }

    /// Whether the evidence has ruled out "the two systems are the same".
    public var excludesZero: Bool { excludes(0) }
}

extension ContrastInterval: CustomStringConvertible {
    public var description: String {
        let lower = String(format: "%+.6f", lowerBound)
        let upper = String(format: "%+.6f", upperBound)
        return "[\(lower), \(upper)] after A \(successesA)/\(trialsA), B \(successesB)/\(trialsB)"
    }
}
