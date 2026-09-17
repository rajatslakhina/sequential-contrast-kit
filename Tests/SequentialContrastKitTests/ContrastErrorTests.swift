import XCTest
@testable import SequentialContrastKit

final class ContrastErrorTests: XCTestCase {
    func testEveryCaseDescribesItself() {
        let cases: [ContrastError] = [
            .alphaOutOfRange(1.5),
            .priorParameterNotPositive(label: "priorSuccesses", value: -1),
            .rateOutOfRange(label: "rate", value: 2),
            .trialsNegative(-3),
            .successCountOutOfRange(successes: 5, trials: 2),
            .horizonBelowOne(0),
            .cellCountNegative(label: "onlyASucceeded", value: -2),
            .cellProbabilityNegative(label: "bothSucceed", value: -0.1),
            .cellProbabilitiesExceedOne(1.4),
            .differenceOutOfRange(-3)
        ]
        for error in cases {
            XCTAssertFalse(error.description.isEmpty)
        }
        XCTAssertEqual(ContrastError.alphaOutOfRange(1.5).description,
                       "alpha 1.5 lies outside the open interval (0, 1)")
        XCTAssertEqual(ContrastError.trialsNegative(-3).description,
                       "trial count -3 is negative")
        XCTAssertEqual(ContrastError.successCountOutOfRange(successes: 5, trials: 2).description,
                       "success count 5 is not within 0...2")
        XCTAssertEqual(ContrastError.horizonBelowOne(0).description,
                       "horizon 0 is below 1 trial")
        XCTAssertEqual(ContrastError.differenceOutOfRange(-3).description,
                       "difference -3.0 lies outside the closed interval [-1, 1]")
    }

    func testCasesCompareByPayload() {
        XCTAssertEqual(ContrastError.horizonBelowOne(0), .horizonBelowOne(0))
        XCTAssertNotEqual(ContrastError.horizonBelowOne(0), .horizonBelowOne(1))
    }
}
