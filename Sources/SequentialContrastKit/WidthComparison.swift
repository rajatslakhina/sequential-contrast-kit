import Foundation

/// Both constructions' expected interval widths on the same data, at the same
/// number of items.
///
/// The pair is reported together because the ratio is the only part that means
/// anything on its own. An expected width of 0.31 is neither good nor bad
/// until it is set against what the same data would have bought without the
/// pairing.
public struct WidthComparison: Sendable, Hashable {
    /// Items the widths were computed at.
    public let trials: Int
    /// Expected width of the paired interval.
    public let pairedWidth: Double
    /// Expected width of the unpaired interval on identical data.
    public let unpairedWidth: Double

    public init(trials: Int, pairedWidth: Double, unpairedWidth: Double) {
        self.trials = trials
        self.pairedWidth = pairedWidth
        self.unpairedWidth = unpairedWidth
    }

    /// How many times wider the unpaired interval is. Above one means the
    /// pairing bought something; at or below one it did not.
    public var pairingGain: Double { unpairedWidth / pairedWidth }
}

extension WidthComparison: CustomStringConvertible {
    public var description: String {
        let paired = String(format: "%.6f", pairedWidth)
        let unpaired = String(format: "%.6f", unpairedWidth)
        let gain = String(format: "%.4f", pairingGain)
        return "paired \(paired), unpaired \(unpaired), gain \(gain)x at \(trials) items"
    }
}
