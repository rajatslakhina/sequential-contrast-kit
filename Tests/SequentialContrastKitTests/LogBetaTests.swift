import XCTest
@testable import SequentialContrastKit

final class LogBetaTests: XCTestCase {
    func testLogGammaMatchesKnownIntegerValues() {
        XCTAssertEqual(LogBeta.logGamma(1), 0, accuracy: 1e-12)
        XCTAssertEqual(LogBeta.logGamma(2), 0, accuracy: 1e-12)
        XCTAssertEqual(LogBeta.logGamma(5), log(24), accuracy: 1e-11)
        XCTAssertEqual(LogBeta.logGamma(0.5), 0.5 * log(Double.pi), accuracy: 1e-11)
    }

    func testLogBetaMatchesTheClosedFormForIntegers() {
        // B(a, b) = (a-1)!(b-1)!/(a+b-1)! for positive integers.
        XCTAssertEqual(LogBeta.logBeta(1, 1), 0, accuracy: 1e-12)
        XCTAssertEqual(LogBeta.logBeta(2, 3), log(1.0 / 12.0), accuracy: 1e-11)
        XCTAssertEqual(LogBeta.logBeta(4, 2), log(1.0 / 20.0), accuracy: 1e-11)
    }

    func testLogFactorialAndBinomialCoefficient() {
        XCTAssertEqual(LogBeta.logFactorial(0), 0, accuracy: 1e-12)
        XCTAssertEqual(LogBeta.logFactorial(6), log(720), accuracy: 1e-11)
        XCTAssertEqual(LogBeta.logBinomialCoefficient(6, 2), log(15), accuracy: 1e-11)
        XCTAssertEqual(LogBeta.logBinomialCoefficient(6, 0), 0, accuracy: 1e-11)
        XCTAssertEqual(LogBeta.logBinomialCoefficient(6, 6), 0, accuracy: 1e-11)
    }

    func testLogPowerTreatsTheZeroExponentAsOneEvenAtZeroBase() {
        XCTAssertEqual(LogBeta.logPower(0, 0), 0)
        XCTAssertEqual(LogBeta.logPower(0.25, 0), 0)
        XCTAssertEqual(LogBeta.logPower(0.5, 3), 3 * log(0.5), accuracy: 1e-12)
        XCTAssertEqual(exp(LogBeta.logPower(0, 4)), 0)
    }
}
