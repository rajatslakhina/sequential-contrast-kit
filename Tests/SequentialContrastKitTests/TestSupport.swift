import XCTest
@testable import SequentialContrastKit

/// Asserts that `expression` throws exactly `expected`.
func assertThrows<T>(
    _ expected: ContrastError,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ expression: () throws -> T
) {
    XCTAssertThrowsError(try expression(), file: file, line: line) { error in
        XCTAssertEqual(error as? ContrastError, expected, file: file, line: line)
    }
}

/// A joint in which the two systems never disagree, so every discordance-
/// conditional quantity takes its empty-evidence branch.
func neverDisagree() throws -> PairedJointDistribution {
    try PairedJointDistribution(bothSucceed: 0.5, onlyASucceeds: 0, onlyBSucceeds: 0)
}

/// A tally in which system A won every item the two systems disagreed on.
func oneSidedTally() throws -> ContrastTally {
    try ContrastTally(
        bothSucceeded: 66, onlyASucceeded: 12, onlyBSucceeded: 0, neitherSucceeded: 42
    )
}
