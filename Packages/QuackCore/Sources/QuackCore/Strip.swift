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

    public init(length: Double, airfields: [Airfield], heights: [Double] = [], spacing: Double = 5)
    {
        self.length = length
        self.airfields = airfields
        self.heights = heights
        self.spacing = spacing
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
            elevation: field.elevation)
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
    /// approach cones, blended back into the hills over `blend` metres.
    public static func generate(
        seed: UInt64, length: Double, fields: Int, fieldLength: Double, apron: Double = 70,
        blend: Double = 80
    ) -> Strip {
        var rng = SeededRNG(seed: seed ^ 0x5717_1B00)
        let gap = length / Double(max(1, fields))
        var airfields = (0..<max(1, fields)).map { k -> Airfield in
            let jitter = (rng.unit() - 0.5) * gap / 2
            let start = Double(k) * gap + gap / 4 + jitter
            return Airfield(start: min(max(0, start), length - fieldLength), length: fieldLength)
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
        return strip
    }

    /// Octaves of periodic value noise, sampled every 5 m: long swells, hills,
    /// bumps. Shifted so the lowest ground is at 0.
    private static func hills(_ rng: inout SeededRNG, length: Double) -> [Double] {
        let spacing = 5.0
        let count = max(4, Int((length / spacing).rounded()))
        var heights = [Double](repeating: 0, count: count)
        for (wavelength, amplitude) in [(800.0, 34.0), (300.0, 16.0), (110.0, 6.0), (40.0, 1.5)] {
            let cells = max(1, Int((length / wavelength).rounded()))
            let values = (0..<cells).map { _ in rng.unit() * 2 - 1 }
            for i in 0..<count {
                let u = Double(i) / Double(count) * Double(cells)
                let c = Int(u.rounded(.down))
                let f = u - Double(c)
                let s = f * f * (3 - 2 * f)
                heights[i] +=
                    amplitude * (values[c % cells] * (1 - s) + values[(c + 1) % cells] * s)
            }
        }
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
