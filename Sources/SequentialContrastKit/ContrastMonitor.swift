import Foundation

/// A live monitor that folds paired eval outcomes in one item at a time and
/// reports both constructions from the same tally.
///
/// It keeps both because the interesting reading is usually the gap between
/// them. The unpaired interval is what a comparison that did not record which
/// item was which would have produced; the paired interval is what the same
/// data supports once the pairing is kept. Watching them diverge is the
/// cheapest available argument for recording the pairing in the first place.
///
/// `firstExclusionTrial` tracks the paired construction, because that is the
/// one that can actually stop early.
public actor ContrastMonitor {
    /// The construction that uses the pairing.
    public let paired: PairedContrastSequence
    /// The construction that discards it.
    public let unpaired: UnpairedContrastSequence
    /// The difference being watched, if any. Zero is the usual choice: it asks
    /// whether the two systems differ at all.
    public let referenceDifference: Double?
    /// Everything observed so far.
    public private(set) var tally = ContrastTally.empty
    /// First trial at which the paired construction ruled out
    /// `referenceDifference`, if it has.
    public private(set) var firstExclusionTrial: Int?

    /// Builds a monitor at one shared `alpha`, rejecting a reference the
    /// constructions could never evaluate.
    public init(alpha: Double, referenceDifference: Double? = 0) throws {
        if let referenceDifference {
            guard referenceDifference >= -1, referenceDifference <= 1 else {
                throw ContrastError.differenceOutOfRange(referenceDifference)
            }
        }
        self.paired = try PairedContrastSequence(alpha: alpha)
        self.unpaired = try UnpairedContrastSequence(alpha: alpha)
        self.referenceDifference = referenceDifference
    }

    /// Folds one scored item in and returns the paired interval that now
    /// holds.
    @discardableResult
    public func observe(_ outcome: PairedOutcome) throws -> ContrastInterval {
        tally = tally.appending(outcome)
        let interval = try paired.interval(for: tally)
        if let referenceDifference, firstExclusionTrial == nil,
           interval.excludes(referenceDifference) {
            firstExclusionTrial = tally.trials
        }
        return interval
    }

    /// Folds a whole stream in, in order, and returns the paired interval that
    /// now holds. An empty stream leaves the monitor untouched.
    @discardableResult
    public func observe(contentsOf stream: [PairedOutcome]) throws -> ContrastInterval {
        for outcome in stream {
            try observe(outcome)
        }
        return try pairedInterval()
    }

    /// The paired reading implied by everything observed so far.
    public func pairedInterval() throws -> ContrastInterval {
        try paired.interval(for: tally)
    }

    /// The unpaired reading implied by the same observations.
    public func unpairedInterval() throws -> ContrastInterval {
        try unpaired.interval(for: tally)
    }

    /// How much wider the unpaired reading is than the paired one, as a ratio
    /// of widths.
    ///
    /// There is no divide-by-zero case to guard. The paired width is a product
    /// of a discordance interval with a win interval, both found by bisection
    /// between a strictly excluded end and a strictly admissible one, so
    /// neither ever collapses to a point and the product never has zero width
    /// — not even before the first item, where the reading is the whole of
    /// `[-1, 1]`. A guard here would be a branch no test could take.
    public func pairingGain() throws -> Double {
        try unpairedInterval().width / pairedInterval().width
    }

    /// Whether the reference difference is still admissible under the paired
    /// construction. `true` when no reference was configured, since nothing is
    /// being watched.
    public func referenceRemainsAdmissible() -> Bool {
        firstExclusionTrial == nil
    }

    /// Drops every observation, keeping the configuration.
    public func reset() {
        tally = .empty
        firstExclusionTrial = nil
    }
}
