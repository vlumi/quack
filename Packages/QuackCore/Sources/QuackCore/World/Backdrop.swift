import Foundation

/// Something standing on a backdrop layer's ridge.
public struct BackdropProp: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case house
        case church
        case mill
        case tree
        case poplar
    }

    public var kind: Kind
    /// Metres along the layer.
    public var x: Double
    /// 1 is the standard size.
    public var size: Double
}

/// One layer of the backdrop: a ridge and what stands on it.
public struct BackdropLayer: Equatable, Sendable {
    /// The fraction of the plane's speed the layer slides at.
    public var parallax: Double
    /// The fraction of the camera's climb the layer follows.
    public var rise: Double
    /// Metres below the camera's anchor line that ridge heights stand on.
    public var baseline: Double
    /// Metres the layer repeats over.
    public var period: Double
    /// Ridge heights above the baseline, every `spacing` metres from 0.
    public var heights: [Double]
    public var spacing: Double
    public var props: [BackdropProp]
    /// Drawn size of a prop metre, smaller further back.
    public var propScale: Double

    /// The ridge's height above the baseline at `x`, wrapping.
    public func height(at x: Double) -> Double {
        let n = heights.count
        let u = x / spacing
        let i = Int(u.rounded(.down))
        let f = u - Double(i)
        let a = heights[(i % n + n) % n]
        let b = heights[((i + 1) % n + n) % n]
        return a + (b - a) * f
    }

    /// `x` moved by whole periods into 0..<period.
    public func wrap(_ x: Double) -> Double {
        let r = x.truncatingRemainder(dividingBy: period)
        return r < 0 ? r + period : r
    }
}

/// What lies behind the strip: three layers of hills, each sliding past slower
/// the further back it is and carrying its own villages and trees. Only to
/// look at; nothing in it can be touched. Every layer repeats over the strip's
/// length times its parallax, so a lap of the strip is a lap of every layer and
/// the seam never shows. Lengths are metres as seen on screen, at the strip's
/// scale.
public struct Backdrop: Equatable, Sendable {
    /// Back to front: the far ridge, the village hills, the hedgerows.
    public var layers: [BackdropLayer]

    public static func generate(seed: UInt64, stripLength: Double) -> Backdrop {
        var rng = SeededRNG(seed: seed ^ 0xBAC_D509)
        let far = layer(
            &rng, parallax: 0.15, rise: 0.03, baseline: 9.3, lift: 26.7,
            octaves: [(136, 6.8), (41, 2.1)], propScale: 0.22, stripLength: stripLength)
        let mid = layer(
            &rng, parallax: 0.4, rise: 0.07, baseline: 11.3, lift: 20.9,
            octaves: [(87.5, 4.4), (25.3, 1.4)], propScale: 0.38, stripLength: stripLength)
        let hedge = layer(
            &rng, parallax: 0.7, rise: 0.14, baseline: 11.3, lift: 13.1,
            octaves: [(50.5, 1.9), (12.6, 0.6)], propScale: 0.6, stripLength: stripLength)
        var layers = [far, mid, hedge]
        layers[0].props = farProps(&rng, period: far.period)
        layers[1].props = villages(&rng, period: mid.period)
        layers[2].props = hedgerows(&rng, period: hedge.period)
        return Backdrop(layers: layers)
    }

    // swiftlint:disable:next function_parameter_count
    private static func layer(
        _ rng: inout SeededRNG, parallax: Double, rise: Double, baseline: Double, lift: Double,
        octaves: [(Double, Double)], propScale: Double, stripLength: Double
    ) -> BackdropLayer {
        let period = stripLength * parallax
        let count = max(4, Int((period / 0.8).rounded()))
        let noise = ValueNoise.periodic(&rng, count: count, period: period, octaves: octaves)
        return BackdropLayer(
            parallax: parallax, rise: rise, baseline: -baseline, period: period,
            heights: noise.map { lift + $0 }, spacing: period / Double(count), props: [],
            propScale: propScale)
    }

    /// Lone poplars along the far ridge, and now and then a windmill.
    private static func farProps(_ rng: inout SeededRNG, period: Double) -> [BackdropProp] {
        var out: [BackdropProp] = []
        var x = 0.0
        while x < period {
            out.append(
                BackdropProp(
                    kind: rng.unit() < 0.15 ? .mill : .poplar, x: x, size: 0.7 + rng.unit() * 0.4))
            x += 8.7 + rng.unit() * 25.3
        }
        return out
    }

    /// Villages on the middle hills: a few houses, a church or a windmill,
    /// poplars at one end, and round trees scattered between villages.
    private static func villages(_ rng: inout SeededRNG, period: Double) -> [BackdropProp] {
        var out: [BackdropProp] = []
        var x = 5.8
        while x < period {
            let houses = 3 + Int(rng.unit() * 4)
            for i in 0..<houses {
                out.append(
                    BackdropProp(
                        kind: .house, x: x + Double(i) * (3.3 + rng.unit() * 1.75),
                        size: 0.8 + rng.unit() * 0.4))
            }
            out.append(
                BackdropProp(
                    kind: rng.unit() < 0.5 ? .church : .mill, x: x + Double(houses) * 4.3 + 1.9,
                    size: 1))
            for i in 0..<3 {
                out.append(
                    BackdropProp(
                        kind: .poplar, x: x - 2.9 - Double(i) * 1.55, size: 0.9 + rng.unit() * 0.4))
            }
            x += 58 + rng.unit() * 87.5
            var t = x - 40.8
            while t < x - 5.8 {
                out.append(BackdropProp(kind: .tree, x: t, size: 0.7 + rng.unit() * 0.5))
                t += 3.9 + rng.unit() * 8.75
            }
        }
        return out
    }

    /// Rows of round trees along the hedgerows, with the odd farmhouse.
    private static func hedgerows(_ rng: inout SeededRNG, period: Double) -> [BackdropProp] {
        var out: [BackdropProp] = []
        var x = 0.0
        while x < period {
            let run = 4 + Int(rng.unit() * 7)
            for i in 0..<run {
                out.append(
                    BackdropProp(
                        kind: .tree, x: x + Double(i) * (2.5 + rng.unit()),
                        size: 0.8 + rng.unit() * 0.5))
            }
            if rng.unit() < 0.35 {
                out.append(BackdropProp(kind: .house, x: x + Double(run) * 3.1 + 3.9, size: 1))
            }
            x += Double(run) * 3.3 + 15.6 + rng.unit() * 40.8
        }
        return out
    }
}
