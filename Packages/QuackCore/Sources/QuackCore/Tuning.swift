import Foundation

/// Every dial the tuning panel exposes, in one value: the flight model, the
/// gun, the thumb controls and the roll. The panel edits it live, the device
/// keeps it, and `report()` is what the Copy button hands over, so tuned
/// values can become the next defaults.
public struct Tuning: Equatable, Sendable {
    public var flight = FlightTuning()
    public var landing = LandingTuning()
    /// Metres of field in the balloon run.
    public var fieldLength: Double = Practice.airfield.length
    public var gun = GunTuning()
    /// Points of thumb drag for full elevator, at most.
    public var throwDistance: Double = 80
    /// The least the throw shrinks to near a screen edge.
    public var minimumThrow: Double = 28
    /// Pull the thumb (or ↓) away from you for nose up instead of toward you.
    public var invertedPitch = false
    /// Seconds the plane takes to roll when it rights itself.
    public var rollDuration: Double = 0.35

    public init() {}

    /// The id the invert switch is stored and reported under; the sliders use their dial ids.
    public static let invertedPitchID = "controls.invertedPitch"

    /// Every value keyed by id, sliders and the invert switch (as 0 or 1), for storage.
    public var values: [String: Double] {
        var out = Dictionary(
            uniqueKeysWithValues: TuningDial.all.map { ($0.id, self[keyPath: $0.keyPath]) })
        out[Tuning.invertedPitchID] = invertedPitch ? 1 : 0
        return out
    }

    /// Defaults, overridden by whatever `values` knows about. Unknown ids are
    /// ignored and missing ones stay default, so a stored set survives a dial
    /// being added, renamed or removed. Values are clamped to each dial's range.
    public init(values: [String: Double]) {
        self.init()
        for dial in TuningDial.all {
            if let v = values[dial.id], v.isFinite {
                self[keyPath: dial.keyPath] = min(
                    max(v, dial.range.lowerBound), dial.range.upperBound)
            }
        }
        if let v = values[Tuning.invertedPitchID] { invertedPitch = v != 0 }
    }

    /// The ids whose values differ from the defaults.
    public var changedIDs: [String] {
        let stock = Tuning()
        var out = TuningDial.all.filter { self[keyPath: $0.keyPath] != stock[keyPath: $0.keyPath] }
            .map(\.id)
        if invertedPitch != stock.invertedPitch { out.append(Tuning.invertedPitchID) }
        return out
    }

    /// Plain text for the clipboard: one line per value, `id = value`, in panel
    /// order, with the default beside every changed one.
    public func report() -> String {
        let stock = Tuning()
        var lines = ["Quack Express tuning (\(changedIDs.count) changed)"]
        for dial in TuningDial.all {
            let v = self[keyPath: dial.keyPath]
            let d = stock[keyPath: dial.keyPath]
            let text = "\(dial.id) = \(dial.format(v))"
            lines.append(v == d ? text : "\(text)  (default \(dial.format(d)))")
        }
        let inv = "\(Tuning.invertedPitchID) = \(invertedPitch)"
        lines.append(
            invertedPitch == stock.invertedPitch ? inv : "\(inv)  (default \(stock.invertedPitch))")
        return lines.joined(separator: "\n")
    }
}

/// The panel's groups, in order.
public enum TuningSection: String, CaseIterable, Sendable {
    case flight
    case stall
    case landing
    case controls
    case gun
    case feel
}

/// One slider on the panel: which value it moves, over what range and step,
/// and how many decimals it shows. Labels are the view layer's, by id.
public struct TuningDial: Identifiable {
    public let id: String
    public let section: TuningSection
    public let keyPath: WritableKeyPath<Tuning, Double>
    public let range: ClosedRange<Double>
    public let step: Double
    public let decimals: Int

    public func format(_ value: Double) -> String {
        String(format: "%.\(decimals)f", value)
    }

    /// Every slider, in panel order. Ranges are wide enough to overshoot the
    /// defaults both ways, which is what finding the edge of a feel needs.
    public static let all: [TuningDial] = [
        TuningDial(
            id: "flight.gravity", section: .flight, keyPath: \.flight.gravity, range: 6...40,
            step: 1, decimals: 0),
        TuningDial(
            id: "flight.thrust", section: .flight, keyPath: \.flight.thrust, range: 2...20,
            step: 0.5, decimals: 1),
        TuningDial(
            id: "flight.cruiseSpeed", section: .flight, keyPath: \.flight.cruiseSpeed,
            range: 20...70, step: 1, decimals: 0),
        TuningDial(
            id: "flight.pitchRate", section: .flight, keyPath: \.flight.pitchRate, range: 1...6,
            step: 0.1, decimals: 1),
        TuningDial(
            id: "flight.liftDeficitSink", section: .flight, keyPath: \.flight.liftDeficitSink,
            range: 0...20, step: 0.5,
            decimals: 1),
        TuningDial(
            id: "stall.speed", section: .stall, keyPath: \.flight.stallSpeed, range: 6...35,
            step: 1, decimals: 0),
        TuningDial(
            id: "stall.band", section: .stall, keyPath: \.flight.stallBand, range: 0.5...12,
            step: 0.5, decimals: 1),
        TuningDial(
            id: "stall.dropRate", section: .stall, keyPath: \.flight.stallDropRate, range: 0.5...10,
            step: 0.5, decimals: 1),
        TuningDial(
            id: "stall.sink", section: .stall, keyPath: \.flight.stallSink, range: 0...30, step: 1,
            decimals: 0),
        TuningDial(
            id: "landing.approachAngle", section: .landing, keyPath: \.landing.approachAngle,
            range: 2...20, step: 1,
            decimals: 0),
        TuningDial(
            id: "landing.approachBand", section: .landing, keyPath: \.landing.approachBand,
            range: 1...12, step: 1,
            decimals: 0),
        TuningDial(
            id: "landing.coneLength", section: .landing, keyPath: \.landing.coneLength,
            range: 15...150, step: 5,
            decimals: 0),
        TuningDial(
            id: "landing.diveLimit", section: .landing, keyPath: \.landing.diveLimit, range: 5...60,
            step: 5,
            decimals: 0),
        TuningDial(
            id: "landing.bounceMargin", section: .landing, keyPath: \.landing.bounceMargin,
            range: 1...15, step: 1,
            decimals: 0),
        TuningDial(
            id: "landing.braking", section: .landing, keyPath: \.landing.braking, range: 4...60,
            step: 1, decimals: 0),
        TuningDial(
            id: "landing.takeoffAcceleration", section: .landing,
            keyPath: \.landing.takeoffAcceleration,
            range: 4...40, step: 1, decimals: 0),
        TuningDial(
            id: "landing.fieldLength", section: .landing, keyPath: \.fieldLength, range: 30...200,
            step: 5,
            decimals: 0),
        TuningDial(
            id: "landing.repairTime", section: .landing, keyPath: \.landing.repairTime,
            range: 0...10, step: 0.5,
            decimals: 1),
        TuningDial(
            id: "controls.throwDistance", section: .controls, keyPath: \.throwDistance,
            range: 30...160, step: 5, decimals: 0),
        TuningDial(
            id: "controls.minimumThrow", section: .controls, keyPath: \.minimumThrow,
            range: 10...80, step: 2, decimals: 0),
        TuningDial(
            id: "gun.muzzleSpeed", section: .gun, keyPath: \.gun.muzzleSpeed, range: 40...300,
            step: 10, decimals: 0),
        TuningDial(
            id: "gun.fireInterval", section: .gun, keyPath: \.gun.fireInterval, range: 0.03...0.5,
            step: 0.01, decimals: 2),
        TuningDial(
            id: "gun.bulletLife", section: .gun, keyPath: \.gun.bulletLife, range: 0.3...3,
            step: 0.1, decimals: 1),
        TuningDial(
            id: "feel.rollDuration", section: .feel, keyPath: \.rollDuration, range: 0.05...1,
            step: 0.05, decimals: 2),
    ]

    /// The sliders in one section, in panel order.
    public static func dials(in section: TuningSection) -> [TuningDial] {
        all.filter { $0.section == section }
    }
}
