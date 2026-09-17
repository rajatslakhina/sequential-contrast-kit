import XCTest
@testable import SequentialContrastKit

final class ExactContrastProfileTests: XCTestCase {
    func testSurvivalIsTheComplementOfExclusion() {
        let profile = ExactContrastProfile(
            referenceDifference: 0.1,
            trueDifference: 0.1,
            horizon: 40,
            exclusionProbability: 0.03,
            expectedFirstExclusionTrial: 22.5
        )
        XCTAssertEqual(profile.survivalProbability, 0.97, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(profile.expectedFirstExclusionTrial), 22.5)
    }

    func testMiscoverageAndDetectionAreToldApartByTheReference() {
        let miscoverage = ExactContrastProfile(
            referenceDifference: 0.1, trueDifference: 0.1, horizon: 10,
            exclusionProbability: 0.01, expectedFirstExclusionTrial: 5
        )
        let detection = ExactContrastProfile(
            referenceDifference: 0, trueDifference: 0.1, horizon: 10,
            exclusionProbability: 0.4, expectedFirstExclusionTrial: nil
        )
        XCTAssertTrue(miscoverage.measuresMiscoverage)
        XCTAssertFalse(detection.measuresMiscoverage)
        XCTAssertEqual(miscoverage.description, "miscoverage 0.010000 over 10 trials")
        XCTAssertEqual(detection.description, "detection 0.400000 over 10 trials")
        XCTAssertNil(detection.expectedFirstExclusionTrial)
    }
}
