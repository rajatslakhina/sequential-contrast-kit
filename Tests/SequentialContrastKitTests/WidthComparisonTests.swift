import XCTest
@testable import SequentialContrastKit

final class WidthComparisonTests: XCTestCase {
    func testGainIsTheRatioOfWidths() {
        let comparison = WidthComparison(trials: 80, pairedWidth: 0.25, unpairedWidth: 0.75)
        XCTAssertEqual(comparison.pairingGain, 3, accuracy: 1e-12)
        XCTAssertEqual(comparison.trials, 80)
    }

    func testDescriptionCarriesBothWidthsAndTheGain() {
        let comparison = WidthComparison(trials: 40, pairedWidth: 0.5, unpairedWidth: 0.6)
        XCTAssertEqual(
            comparison.description,
            "paired 0.500000, unpaired 0.600000, gain 1.2000x at 40 items"
        )
    }
}
