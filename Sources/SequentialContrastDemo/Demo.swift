import Foundation
import SequentialContrastKit

/// Six scenarios that exercise every public surface of `SequentialContrastKit`
/// end to end and print what it actually computed.
@main
struct Demo {
    static let alpha = 0.05

    static func main() async throws {
        header("SequentialContrastKit — a time-uniform interval for p_A - p_B")
        try await overlapTrap()
        try await narrowing()
        try miscoverageAudit()
        try detectionPower()
        try pairingGainTable()
        try await liveMonitor()
        print("")
    }

    // MARK: - 1

    /// Two marginal intervals that overlap for the whole run, and a difference
    /// interval that rules out zero anyway.
    static func overlapTrap() async throws {
        header("1. Overlapping marginals, and a difference that still excludes zero")
        let stream = Fixtures.spread(
            bothSucceeded: 66, onlyASucceeded: 12, onlyBSucceeded: 0, neitherSucceeded: 42
        )
        let tally = Fixtures.tally(of: stream)
        let paired = try PairedContrastSequence(alpha: alpha)
        let unpaired = try UnpairedContrastSequence(alpha: alpha)

        print("tally                 \(tally)")
        print("observed difference   \(number(tally.observedDifference))")
        print("agreement rate        \(number(tally.agreementRate))")

        let armA = try unpaired.armSequence.interval(successes: tally.successesA, trials: tally.trials)
        let armB = try unpaired.armSequence.interval(successes: tally.successesB, trials: tally.trials)
        print("arm A                 \(armA)")
        print("arm B                 \(armB)")
        print("marginals overlap     \(armA.lowerBound <= armB.upperBound && armB.lowerBound <= armA.upperBound)")

        let unpairedInterval = try unpaired.interval(for: tally)
        let pairedInterval = try paired.interval(for: tally)
        print("unpaired difference   \(unpairedInterval)")
        print("  excludes zero       \(unpairedInterval.excludesZero)")
        print("paired difference     \(pairedInterval)")
        print("  excludes zero       \(pairedInterval.excludesZero)")
        print("  discordance         \(try paired.discordanceBounds(for: tally))")
        print("  win given discord   \(try paired.winBounds(for: tally))")

        let monitor = try ContrastMonitor(alpha: alpha, referenceDifference: 0)
        try await monitor.observe(contentsOf: stream)
        print("first exclusion trial \(await monitor.firstExclusionTrial.map(String.init) ?? "never")")
        print("reference admissible  \(await monitor.referenceRemainsAdmissible())")
    }

    // MARK: - 2

    /// What both constructions are worth at each look, on the same stream.
    static func narrowing() async throws {
        header("2. Width by look, same data, both constructions")
        let joint = try PairedJointDistribution(
            bothSucceed: 0.58, onlyASucceeds: 0.14, onlyBSucceeds: 0.04
        )
        let stream = Fixtures.draw(count: 120, from: joint, seed: 20_260_917)
        let paired = try PairedContrastSequence(alpha: alpha)
        let unpaired = try UnpairedContrastSequence(alpha: alpha)
        print("joint  \(joint)   true difference \(number(joint.difference))")
        print("")
        print("  look   paired interval          width   unpaired interval        width    ratio")
        var tally = ContrastTally.empty
        for (index, outcome) in stream.enumerated() {
            tally = tally.appending(outcome)
            let look = index + 1
            guard look % 20 == 0 else { continue }
            let pairedInterval = try paired.interval(for: tally)
            let unpairedInterval = try unpaired.interval(for: tally)
            let ratio = unpairedInterval.width / pairedInterval.width
            print("  \(pad(look, 4))   \(bounds(pairedInterval))  \(number(pairedInterval.width, 6))"
                + "   \(bounds(unpairedInterval))  \(number(unpairedInterval.width, 6))"
                + "   \(number(ratio, 4))x")
        }
    }

    // MARK: - 3

    /// Miscoverage measured by enumeration, not by simulation.
    static func miscoverageAudit() throws {
        header("3. Exact miscoverage at horizon 60, nominal alpha = 0.05")
        let solver = try ContrastExclusionSolver(alpha: alpha)
        let joints = try [
            ("agree 0.88", PairedJointDistribution(bothSucceed: 0.60, onlyASucceeds: 0.10, onlyBSucceeds: 0.02)),
            ("agree 0.70", PairedJointDistribution(bothSucceed: 0.50, onlyASucceeds: 0.20, onlyBSucceeds: 0.10)),
            ("agree 0.50", PairedJointDistribution(bothSucceed: 0.35, onlyASucceeds: 0.30, onlyBSucceeds: 0.20))
        ]
        print("  joint         true delta   paired miscoverage   unpaired miscoverage   budget spent")
        for (label, joint) in joints {
            let delta = joint.difference
            let pairedProfile = try solver.pairedProfile(
                referenceDifference: delta, joint: joint, horizon: 60
            )
            let unpairedProfile = try solver.unpairedProfile(
                referenceDifference: delta, joint: joint, horizon: 60
            )
            let spent = pairedProfile.exclusionProbability / alpha
            print("  \(label)      \(number(delta, 4))"
                + "       \(number(pairedProfile.exclusionProbability, 6)) \(flag(pairedProfile))"
                + "          \(number(unpairedProfile.exclusionProbability, 6)) \(flag(unpairedProfile))"
                + "        \(number(spent * 100, 2))%")
        }
    }

    // MARK: - 4

    /// How often each construction notices a real difference, and when.
    static func detectionPower() throws {
        header("4. Detection of a real difference against reference zero, horizon 60")
        let solver = try ContrastExclusionSolver(alpha: alpha)
        let joints = try [
            ("agree 0.88", PairedJointDistribution(bothSucceed: 0.60, onlyASucceeds: 0.10, onlyBSucceeds: 0.02)),
            ("agree 0.76", PairedJointDistribution(bothSucceed: 0.55, onlyASucceeds: 0.16, onlyBSucceeds: 0.08)),
            ("agree 0.60", PairedJointDistribution(bothSucceed: 0.45, onlyASucceeds: 0.24, onlyBSucceeds: 0.16))
        ]
        print("  joint         true delta   paired detect   first trial   unpaired detect   first trial")
        for (label, joint) in joints {
            let pairedProfile = try solver.pairedProfile(
                referenceDifference: 0, joint: joint, horizon: 60
            )
            let unpairedProfile = try solver.unpairedProfile(
                referenceDifference: 0, joint: joint, horizon: 60
            )
            print("  \(label)      \(number(joint.difference, 4))"
                + "       \(number(pairedProfile.exclusionProbability, 6))"
                + "      \(trial(pairedProfile))"
                + "      \(number(unpairedProfile.exclusionProbability, 6))"
                + "        \(trial(unpairedProfile))")
        }
    }

    // MARK: - 5

    /// The same two marginals, the same difference, and a sweep of how often
    /// the two systems happen to agree.
    static func pairingGainTable() throws {
        header("5. What the pairing is worth: fixed marginals, swept agreement")
        let solver = try ContrastExclusionSolver(alpha: alpha)
        let trials = 80
        print("  p_A = 0.70, p_B = 0.58, true difference = 0.1200, expected width at \(trials) items")
        print("")
        print("  agreement   paired width   unpaired width   gain")
        for onlyB in [0.00, 0.04, 0.09, 0.15, 0.22] {
            let joint = try PairedJointDistribution(
                bothSucceed: 0.58 - onlyB, onlyASucceeds: 0.12 + onlyB, onlyBSucceeds: onlyB
            )
            let comparison = try solver.widthComparison(trials: trials, joint: joint)
            print("  \(number(joint.agreementRate, 4))      \(number(comparison.pairedWidth, 6))"
                + "       \(number(comparison.unpairedWidth, 6))     \(number(comparison.pairingGain, 4))x")
        }
        let independent = try PairedJointDistribution.independent(rateA: 0.70, rateB: 0.58)
        print("")
        print("  independent arms at the same marginals: \(independent)")
        print("  agreement \(number(independent.agreementRate, 4)),"
            + " win rate given discordance \(number(independent.winRateGivenDiscordant))")
        print("  \(try solver.widthComparison(trials: trials, joint: independent))")
    }

    // MARK: - 6

    /// The actor path, folding a stream one item at a time.
    static func liveMonitor() async throws {
        header("6. Live monitor, one item at a time")
        let joint = try PairedJointDistribution(
            bothSucceed: 0.62, onlyASucceeds: 0.13, onlyBSucceeds: 0.05
        )
        let stream = Fixtures.draw(count: 150, from: joint, seed: 99_112_026)
        let monitor = try ContrastMonitor(alpha: alpha, referenceDifference: 0)
        for outcome in stream {
            try await monitor.observe(outcome)
        }
        let tally = await monitor.tally
        print("joint                 \(joint)   true difference \(number(joint.difference))")
        print("tally                 \(tally)")
        print("paired                \(try await monitor.pairedInterval())")
        print("unpaired              \(try await monitor.unpairedInterval())")
        print("pairing gain          \(number(try await monitor.pairingGain(), 4))x")
        print("first exclusion trial \(await monitor.firstExclusionTrial.map(String.init) ?? "never")")
        print("reference admissible  \(await monitor.referenceRemainsAdmissible())")
        await monitor.reset()
        print("after reset           \(await monitor.tally), admissible \(await monitor.referenceRemainsAdmissible())")
    }

    // MARK: - Formatting

    static func header(_ title: String) {
        print("")
        print(title)
        print(String(repeating: "-", count: title.count))
    }

    static func number(_ value: Double, _ places: Int = 4) -> String {
        String(format: "%.\(places)f", value)
    }

    static func number(_ value: Double?, _ places: Int = 4) -> String {
        value.map { number($0, places) } ?? "n/a"
    }

    static func bounds(_ interval: ContrastInterval) -> String {
        "[\(number(interval.lowerBound, 6)), \(number(interval.upperBound, 6))]"
    }

    static func pad(_ value: Int, _ width: Int) -> String {
        let text = String(value)
        return String(repeating: " ", count: max(0, width - text.count)) + text
    }

    static func flag(_ profile: ExactContrastProfile) -> String {
        profile.measuresMiscoverage ? "(miscoverage)" : "(detection)  "
    }

    static func trial(_ profile: ExactContrastProfile) -> String {
        profile.expectedFirstExclusionTrial.map { number($0, 4) } ?? "     n/a"
    }
}
