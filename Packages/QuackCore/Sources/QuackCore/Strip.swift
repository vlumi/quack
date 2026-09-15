import Foundation

/// The world: a strip of ground whose ends meet, so flying off one end brings
/// the plane back from the other, with fields along it. Positions along it are
/// metres in 0..<length; `offset` and `image` answer "which way round is
/// nearer", so everything that compares positions works across the seam.
public struct Strip: Equatable, Sendable {
    public var length: Double
    /// The fields, in order along the strip. The first is home: where a run starts.
    public var airfields: [Airfield]

    public init(length: Double, airfields: [Airfield]) {
        self.length = length
        self.airfields = airfields
    }

    /// `x` moved by whole laps into 0..<length.
    public func wrap(_ x: Double) -> Double {
        let r = x.truncatingRemainder(dividingBy: length)
        return r < 0 ? r + length : r
    }

    /// The signed distance from `a` to `b` the shorter way round: positive is
    /// ahead to the right.
    public func offset(from a: Double, to b: Double) -> Double {
        let d = wrap(b - a)
        return d > length / 2 ? d - length : d
    }

    /// A copy of `field` moved by whole laps so its middle is nearest `x`. The
    /// landing and takeoff arithmetic works on this copy as if the strip did
    /// not wrap.
    public func image(of field: Airfield, near x: Double) -> Airfield {
        let middle = field.start + field.length / 2
        return Airfield(
            start: x + offset(from: x, to: middle) - field.length / 2, length: field.length)
    }

    /// The field under `x`, as an image near it, if there is one.
    public func airfield(under x: Double) -> Airfield? {
        airfields.lazy.map { image(of: $0, near: x) }.first { $0.contains(x) }
    }

    /// The field whose middle is nearest `x`, as an image near it.
    public func nearestAirfield(to x: Double) -> Airfield? {
        airfields.map { image(of: $0, near: x) }.min {
            abs($0.start + $0.length / 2 - x) < abs($1.start + $1.length / 2 - x)
        }
    }

    /// A strip from a seed: `fields` fields spread evenly round it, each nudged
    /// by up to a quarter of the gap, the first near the start.
    public static func generate(seed: UInt64, length: Double, fields: Int, fieldLength: Double)
        -> Strip
    {
        var rng = SeededRNG(seed: seed ^ 0x5717_1B00)
        let gap = length / Double(max(1, fields))
        let airfields = (0..<max(1, fields)).map { k -> Airfield in
            let jitter = (rng.unit() - 0.5) * gap / 2
            let start = Double(k) * gap + gap / 4 + jitter
            return Airfield(start: min(max(0, start), length - fieldLength), length: fieldLength)
        }
        return Strip(length: length, airfields: airfields)
    }
}
