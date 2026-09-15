import Foundation

/// The hour a run is flown at. It comes from the seed, not the device's clock,
/// so a seed always gives the same sky: a Daily Drop looks the same for everyone.
public enum TimeOfDay: String, CaseIterable, Sendable {
    case dawn
    case noon
    case evening
    case night

    /// One of the four, evenly, from the seed.
    public init(seed: UInt64) {
        var rng = SeededRNG(seed: seed ^ 0x0D15_EA5E)
        let all = TimeOfDay.allCases
        self = all[min(all.count - 1, Int(rng.unit() * Double(all.count)))]
    }
}
