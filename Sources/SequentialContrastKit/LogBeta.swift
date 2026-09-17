import Foundation

/// Branch-free log-gamma and log-beta used by every evidence computation in
/// this package.
///
/// Both component martingales are ratios of beta functions whose arguments
/// grow with the trial count, and the solver weights whole multinomial cells,
/// so the only numerically safe place to do any of it is log space.
enum LogBeta {
    /// Lanczos `g = 7`, `n = 9` coefficients. Accurate to roughly 15 digits
    /// across the whole positive real line, which is the only region this
    /// package ever evaluates: every argument is a prior parameter (validated
    /// positive) plus a non-negative count.
    private static let lanczos: [Double] = [
        0.99999999999980993,
        676.5203681218851,
        -1259.1392167224028,
        771.32342877765313,
        -176.61502916214059,
        12.507343278686905,
        -0.13857109526572012,
        9.9843695780195716e-6,
        1.5056327351493116e-7
    ]

    /// `log(gamma(x))` for `x > 0`.
    ///
    /// Deliberately has no reflection branch for `x < 0.5`: nothing in this
    /// package can reach it, and a branch no test can take is a coverage hole
    /// dressed up as generality.
    static func logGamma(_ x: Double) -> Double {
        let z = x - 1
        var series = lanczos[0]
        for index in 1..<lanczos.count {
            series += lanczos[index] / (z + Double(index))
        }
        let t = z + 7.5
        return 0.5 * log(2 * Double.pi) + (z + 0.5) * log(t) - t + log(series)
    }

    /// `log(B(a, b))` for `a > 0` and `b > 0`.
    static func logBeta(_ a: Double, _ b: Double) -> Double {
        logGamma(a) + logGamma(b) - logGamma(a + b)
    }

    /// `log(n! / (k! * (n - k)!))` for `0 <= k <= n`.
    static func logBinomialCoefficient(_ n: Int, _ k: Int) -> Double {
        logFactorial(n) - logFactorial(k) - logFactorial(n - k)
    }

    /// `log(n!)` for `n >= 0`.
    static func logFactorial(_ n: Int) -> Double {
        logGamma(Double(n) + 1)
    }

    /// `log(base^exponent)` with the convention that anything to the power
    /// zero is one, including zero itself.
    ///
    /// The solver weights multinomial cells whose probabilities are routinely
    /// exactly zero — a joint distribution in which the two systems never
    /// disagree in one direction is a perfectly ordinary input — and
    /// `0 * log(0)` is `NaN` while `0^0` is `1`. The branch is the difference
    /// between a weight of one and a table full of `NaN`.
    static func logPower(_ base: Double, _ exponent: Int) -> Double {
        exponent == 0 ? 0 : Double(exponent) * log(base)
    }
}
