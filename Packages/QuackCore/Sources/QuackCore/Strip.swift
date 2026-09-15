import Foundation

/// The world: a strip of ground whose ends meet, so flying off one end brings
/// the plane back from the other, with hills and fields along it. Positions
/// along it are metres in 0..<length; `offset` and `image` answer "which way
/// round is nearer", so everything that compares positions works across the
/// seam. Heights are metres above sea level, the lowest ground being 0.
public struct Strip: Equatable, Sendable {
    public var length: Double
    /// The fields, in order along the strip. The first is home: where a run starts.
    public var airfields: [Airfield]
    /// Ground heights sampled every `spacing` metres from 0, wrapping; empty is flat at 0.
    public var heights: [Double]
    public var spacing: Double
    /// Houses and trees standing on the strip, in order along it.
    public var scenery: [Obstacle]

    public init(
        length: Double, airfields: [Airfield], heights: [Double] = [], spacing: Double = 5,
        scenery: [Obstacle] = []
    ) {
        self.length = length
        self.airfields = airfields
        self.heights = heights
        self.spacing = spacing
        self.scenery = scenery
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

    /// Metres of ground above sea level at `x`: a smooth curve through the
    /// samples (Catmull-Rom), continuous across the seam, never below 0.
    public func groundHeight(at x: Double) -> Double {
        guard !heights.isEmpty else { return 0 }
        let n = heights.count
        let u = wrap(x) / spacing
        let i = Int(u.rounded(.down))
        let f = u - Double(i)
        let p0 = heights[((i - 1) % n + n) % n]
        let p1 = heights[i % n]
        let p2 = heights[(i + 1) % n]
        let p3 = heights[(i + 2) % n]
        let a = -0.5 * p0 + 1.5 * p1 - 1.5 * p2 + 0.5 * p3
        let b = p0 - 2.5 * p1 + 2 * p2 - 0.5 * p3
        let c = -0.5 * p0 + 0.5 * p2
        return max(0, ((a * f + b) * f + c) * f + p1)
    }

    /// A copy of `field` moved by whole laps so its middle is nearest `x`. The
    /// landing and takeoff arithmetic works on this copy as if the strip did
    /// not wrap.
    public func image(of field: Airfield, near x: Double) -> Airfield {
        let middle = field.start + field.length / 2
        return Airfield(
            start: x + offset(from: x, to: middle) - field.length / 2, length: field.length,
            elevation: field.elevation, name: field.name)
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

    /// A strip from a seed: rolling hills from a few octaves of noise that repeat
    /// round the strip, and `fields` fields spread evenly round it, each nudged
    /// by up to a quarter of the gap, the first near the start. Each field sits
    /// on a flat shelf reaching `apron` metres past its ends, room for its
    /// approach cones, blended back into the hills over `blend` metres. Houses
    /// and trees stand everywhere else that leaves the approaches clear, under
    /// a line rising at `approachSlope` from each field's ends.
    public static func generate(
        seed: UInt64, length: Double, fields: Int, fieldLength: Double, apron: Double = 70,
        blend: Double = 80, approachSlope: Double = tan(8 * .pi / 180)
    ) -> Strip {
        var rng = SeededRNG(seed: seed ^ 0x5717_1B00)
        let gap = length / Double(max(1, fields))
        let names = fieldNames(seed: seed, count: max(1, fields))
        var airfields = (0..<max(1, fields)).map { k -> Airfield in
            let jitter = (rng.unit() - 0.5) * gap / 2
            let start = Double(k) * gap + gap / 4 + jitter
            return Airfield(
                start: min(max(0, start), length - fieldLength), length: fieldLength,
                name: names[k])
        }
        let heights = hills(&rng, length: length)
        var strip = Strip(
            length: length, airfields: [], heights: heights, spacing: length / Double(heights.count)
        )
        for k in airfields.indices {
            let field = airfields[k]
            airfields[k].elevation = strip.groundHeight(at: field.start + field.length / 2)
            strip.flatten(airfields[k], apron: apron, blend: blend)
        }
        strip.airfields = airfields
        strip.scenery = Strip.scenery(seed: seed, on: strip, apron: apron, slope: approachSlope)
        return strip
    }

    /// Village names for the fields, no two the same, from the seed.
    static func fieldNames(seed: UInt64, count: Int) -> [String] {
        var rng = SeededRNG(seed: seed ^ 0x0A3E_5000)
        var pool = Strip.villages
        var out: [String] = []
        while out.count < count {
            if pool.isEmpty { pool = Strip.villages }
            out.append(pool.remove(at: min(pool.count - 1, Int(rng.unit() * Double(pool.count)))))
        }
        return out
    }

    /// The villages a field can be named after.
    static let villages = [
        "Ashby", "Brill", "Crake", "Dunmore", "Elmley", "Fenny", "Gosford", "Hartley", "Ivinghoe",
        "Kettle", "Lynton", "Marlow", "Nettlebed", "Oakley", "Purton", "Quarry", "Ripley", "Stow",
        "Tring", "Wendover",
    ]

    /// Octaves of periodic value noise, sampled every 5 m: long swells, hills,
    /// bumps. Shifted so the lowest ground is at 0.
    private static func hills(_ rng: inout SeededRNG, length: Double) -> [Double] {
        let count = max(4, Int((length / 5).rounded()))
        let heights = ValueNoise.periodic(
            &rng, count: count, period: length,
            octaves: [(800, 34), (300, 16), (110, 6), (40, 1.5)])
        let lowest = heights.min() ?? 0
        return heights.map { $0 - lowest }
    }

    /// Level the ground under `field` and its aprons to its elevation, easing
    /// back to the hills beyond.
    private mutating func flatten(_ field: Airfield, apron: Double, blend: Double) {
        let shelfStart = field.start - apron
        let shelfLength = field.length + 2 * apron
        for i in heights.indices {
            let into = wrap(Double(i) * spacing - shelfStart)
            let outside = into <= shelfLength ? 0 : min(into - shelfLength, length - into)
            if outside < blend {
                let t = outside / blend
                let s = t * t * (3 - 2 * t)
                heights[i] = field.elevation * (1 - s) + heights[i] * s
            }
        }
    }
}
