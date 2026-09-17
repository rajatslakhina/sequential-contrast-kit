import Foundation

/// One item scored by both systems.
public struct PairedOutcome: Sendable, Hashable {
    /// Whether system A succeeded on this item.
    public let systemA: Bool
    /// Whether system B succeeded on this item.
    public let systemB: Bool

    public init(systemA: Bool, systemB: Bool) {
        self.systemA = systemA
        self.systemB = systemB
    }

    /// Whether the two systems disagreed on this item.
    public var isDiscordant: Bool { systemA != systemB }
}

/// The four-cell summary of a paired eval stream: how many items both systems
/// got, how many each got alone, and how many neither got.
///
/// This is the currency both constructions in this package accept, and that is
/// deliberate. `PairedContrastSequence` uses all four cells;
/// `UnpairedContrastSequence` reads only the two margins and throws the pairing
/// away. Feeding both the same tally is what makes the comparison between them
/// a statement about the *method* rather than about two different datasets.
public struct ContrastTally: Sendable, Hashable {
    /// Items both systems succeeded on.
    public let bothSucceeded: Int
    /// Items only system A succeeded on.
    public let onlyASucceeded: Int
    /// Items only system B succeeded on.
    public let onlyBSucceeded: Int
    /// Items neither system succeeded on.
    public let neitherSucceeded: Int

    /// Builds a tally, rejecting any negative cell.
    public init(
        bothSucceeded: Int,
        onlyASucceeded: Int,
        onlyBSucceeded: Int,
        neitherSucceeded: Int
    ) throws {
        try Self.validate(label: "bothSucceeded", value: bothSucceeded)
        try Self.validate(label: "onlyASucceeded", value: onlyASucceeded)
        try Self.validate(label: "onlyBSucceeded", value: onlyBSucceeded)
        try Self.validate(label: "neitherSucceeded", value: neitherSucceeded)
        self.bothSucceeded = bothSucceeded
        self.onlyASucceeded = onlyASucceeded
        self.onlyBSucceeded = onlyBSucceeded
        self.neitherSucceeded = neitherSucceeded
    }

    private static func validate(label: String, value: Int) throws {
        guard value >= 0 else {
            throw ContrastError.cellCountNegative(label: label, value: value)
        }
    }

    /// A tally of nothing.
    public static let empty = ContrastTally(unchecked: 0, 0, 0, 0)

    /// Non-throwing initialiser for counts already known to be non-negative,
    /// used by `appending` and by `empty`.
    private init(unchecked bothSucceeded: Int, _ onlyA: Int, _ onlyB: Int, _ neither: Int) {
        self.bothSucceeded = bothSucceeded
        self.onlyASucceeded = onlyA
        self.onlyBSucceeded = onlyB
        self.neitherSucceeded = neither
    }

    /// Items scored.
    public var trials: Int {
        bothSucceeded + onlyASucceeded + onlyBSucceeded + neitherSucceeded
    }

    /// Items the two systems disagreed on.
    public var discordantTrials: Int { onlyASucceeded + onlyBSucceeded }

    /// Items the two systems agreed on, either way.
    public var concordantTrials: Int { bothSucceeded + neitherSucceeded }

    /// Successes on arm A.
    public var successesA: Int { bothSucceeded + onlyASucceeded }

    /// Successes on arm B.
    public var successesB: Int { bothSucceeded + onlyBSucceeded }

    /// `successesA / trials - successesB / trials`, or `nil` before any item.
    public var observedDifference: Double? {
        trials == 0 ? nil : Double(onlyASucceeded - onlyBSucceeded) / Double(trials)
    }

    /// The fraction of items the two systems agreed on, or `nil` before any
    /// item. This is the number that decides how much the pairing is worth.
    public var agreementRate: Double? {
        trials == 0 ? nil : Double(concordantTrials) / Double(trials)
    }

    /// The tally with one more scored item folded in.
    public func appending(_ outcome: PairedOutcome) -> ContrastTally {
        switch (outcome.systemA, outcome.systemB) {
        case (true, true):
            return ContrastTally(
                unchecked: bothSucceeded + 1, onlyASucceeded, onlyBSucceeded, neitherSucceeded
            )
        case (true, false):
            return ContrastTally(
                unchecked: bothSucceeded, onlyASucceeded + 1, onlyBSucceeded, neitherSucceeded
            )
        case (false, true):
            return ContrastTally(
                unchecked: bothSucceeded, onlyASucceeded, onlyBSucceeded + 1, neitherSucceeded
            )
        case (false, false):
            return ContrastTally(
                unchecked: bothSucceeded, onlyASucceeded, onlyBSucceeded, neitherSucceeded + 1
            )
        }
    }
}

extension ContrastTally: CustomStringConvertible {
    public var description: String {
        "both \(bothSucceeded), A only \(onlyASucceeded), "
            + "B only \(onlyBSucceeded), neither \(neitherSucceeded)"
    }
}
