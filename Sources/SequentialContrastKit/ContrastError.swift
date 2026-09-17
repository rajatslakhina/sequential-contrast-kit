import Foundation

/// Every way a request to this package can be rejected before any arithmetic
/// happens.
public enum ContrastError: Error, Equatable, Sendable {
    /// A miscoverage budget outside the open interval `(0, 1)`.
    case alphaOutOfRange(Double)
    /// A beta-prior parameter that was not strictly positive.
    case priorParameterNotPositive(label: String, value: Double)
    /// A rate argument outside the open interval `(0, 1)`.
    case rateOutOfRange(label: String, value: Double)
    /// A negative trial count.
    case trialsNegative(Int)
    /// A success count that was negative or exceeded the trial count.
    case successCountOutOfRange(successes: Int, trials: Int)
    /// A solver horizon below one trial.
    case horizonBelowOne(Int)
    /// A negative count in one of the four cells of a paired tally.
    case cellCountNegative(label: String, value: Int)
    /// A negative probability in one of the cells of a joint distribution.
    case cellProbabilityNegative(label: String, value: Double)
    /// Three cell probabilities that already sum past one, leaving no mass for
    /// the fourth.
    case cellProbabilitiesExceedOne(Double)
    /// A difference argument outside the closed interval `[-1, 1]`.
    case differenceOutOfRange(Double)
}

extension ContrastError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .alphaOutOfRange(alpha):
            return "alpha \(alpha) lies outside the open interval (0, 1)"
        case let .priorParameterNotPositive(label, value):
            return "prior parameter \(label) \(value) is not strictly positive"
        case let .rateOutOfRange(label, value):
            return "\(label) \(value) lies outside the open interval (0, 1)"
        case let .trialsNegative(trials):
            return "trial count \(trials) is negative"
        case let .successCountOutOfRange(successes, trials):
            return "success count \(successes) is not within 0...\(trials)"
        case let .horizonBelowOne(horizon):
            return "horizon \(horizon) is below 1 trial"
        case let .cellCountNegative(label, value):
            return "cell count \(label) \(value) is negative"
        case let .cellProbabilityNegative(label, value):
            return "cell probability \(label) \(value) is negative"
        case let .cellProbabilitiesExceedOne(total):
            return "cell probabilities sum to \(total), leaving no mass for the fourth cell"
        case let .differenceOutOfRange(difference):
            return "difference \(difference) lies outside the closed interval [-1, 1]"
        }
    }
}
