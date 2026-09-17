import Foundation

/// The distribution one paired eval item is drawn from: four cells that say
/// how often the two systems both succeed, each succeeds alone, and neither
/// does.
///
/// A pair of marginal rates is not enough to describe a paired comparison, and
/// that gap is the whole reason the paired construction can beat the unpaired
/// one. `rateA` and `rateB` can be held fixed while `agreementRate` sweeps from
/// near zero to near one, and the difference `p_A - p_B` stays exactly the same
/// while the amount of evidence available about it changes completely.
public struct PairedJointDistribution: Sendable, Hashable {
    /// Probability both systems succeed on an item.
    public let bothSucceed: Double
    /// Probability only system A succeeds.
    public let onlyASucceeds: Double
    /// Probability only system B succeeds.
    public let onlyBSucceeds: Double
    /// Probability neither succeeds, derived as the remaining mass.
    public let neitherSucceeds: Double

    /// Builds a distribution from three cells, deriving the fourth.
    public init(bothSucceed: Double, onlyASucceeds: Double, onlyBSucceeds: Double) throws {
        try Self.validate(label: "bothSucceed", value: bothSucceed)
        try Self.validate(label: "onlyASucceeds", value: onlyASucceeds)
        try Self.validate(label: "onlyBSucceeds", value: onlyBSucceeds)
        let named = bothSucceed + onlyASucceeds + onlyBSucceeds
        guard named <= 1 else {
            throw ContrastError.cellProbabilitiesExceedOne(named)
        }
        self.bothSucceed = bothSucceed
        self.onlyASucceeds = onlyASucceeds
        self.onlyBSucceeds = onlyBSucceeds
        self.neitherSucceeds = 1 - named
    }

    private static func validate(label: String, value: Double) throws {
        guard value >= 0 else {
            throw ContrastError.cellProbabilityNegative(label: label, value: value)
        }
    }

    /// `p_A`.
    public var rateA: Double { bothSucceed + onlyASucceeds }
    /// `p_B`.
    public var rateB: Double { bothSucceed + onlyBSucceeds }
    /// `p_A - p_B`, which is also `onlyASucceeds - onlyBSucceeds`.
    public var difference: Double { onlyASucceeds - onlyBSucceeds }
    /// Probability the two systems disagree on an item.
    public var discordanceRate: Double { onlyASucceeds + onlyBSucceeds }
    /// Probability they agree, either way.
    public var agreementRate: Double { bothSucceed + neitherSucceeds }

    /// Probability system A wins an item given the systems disagreed on it, or
    /// `nil` when they never disagree and the quantity is undefined.
    public var winRateGivenDiscordant: Double? {
        discordanceRate == 0 ? nil : onlyASucceeds / discordanceRate
    }

    /// The joint in which the two systems are independent at the same
    /// marginals, which is the distribution the unpaired construction
    /// implicitly assumes it is looking at.
    public static func independent(rateA: Double, rateB: Double) throws -> PairedJointDistribution {
        try PairedJointDistribution(
            bothSucceed: rateA * rateB,
            onlyASucceeds: rateA * (1 - rateB),
            onlyBSucceeds: (1 - rateA) * rateB
        )
    }
}

extension PairedJointDistribution: CustomStringConvertible {
    public var description: String {
        let cells = [bothSucceed, onlyASucceeds, onlyBSucceeds, neitherSucceeds]
            .map { String(format: "%.4f", $0) }
            .joined(separator: ", ")
        return "(\(cells))"
    }
}
