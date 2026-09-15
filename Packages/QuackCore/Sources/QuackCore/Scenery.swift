import Foundation

/// A house or a tree on the strip: scenery, and solid. Flying into one is a
/// crash and rounds stop in it. The solid part is a box a little smaller than
/// the drawing, so brushing the leaves or the eaves is forgiven.
public struct Obstacle: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case house
        case tree
        case pine
    }

    public var kind: Kind
    /// Metres along the strip of its middle.
    public var x: Double
    /// 1 is the standard size; the drawing and the solid box scale with it.
    public var size: Double

    public init(kind: Kind, x: Double, size: Double = 1) {
        self.kind = kind
        self.x = x
        self.size = size
    }

    /// Metres of the solid box either side of `x`.
    public var halfWidth: Double {
        switch kind {
        case .house: return 3.4 * size
        case .tree: return 1.8 * size
        case .pine: return 1.2 * size
        }
    }

    /// Metres of the solid box above the ground under its middle.
    public var height: Double {
        switch kind {
        case .house, .tree: return 7 * size
        case .pine: return 7.2 * size
        }
    }
}

extension Strip {
    /// The obstacle whose solid box spans `x`, if any, measured round the seam.
    public func obstacle(at x: Double) -> Obstacle? {
        scenery.first { abs(offset(from: $0.x, to: x)) <= $0.halfWidth }
    }

    /// Metres above sea level of whatever is solid at `x`: the ground, or the
    /// top of an obstacle standing there.
    public func surfaceHeight(at x: Double) -> Double {
        let ground = groundHeight(at: x)
        guard let o = obstacle(at: x) else { return ground }
        return max(ground, groundHeight(at: o.x) + o.height)
    }

    /// Scenery from a seed: something every 18 to 64 m, about half of it round
    /// trees, a third pines and one in eight a house. Anything that would stand
    /// on a field's shelf or poke above its approach line is left out.
    static func scenery(seed: UInt64, on strip: Strip, apron: Double, slope: Double) -> [Obstacle] {
        var rng = SeededRNG(seed: seed ^ 0x5CE7_E000)
        var out: [Obstacle] = []
        var x = 0.0
        while true {
            x += 18 + rng.unit() * 46
            guard x < strip.length else { return out }
            let roll = rng.unit()
            let size = 0.8 + rng.unit() * 0.5
            let kind: Obstacle.Kind = roll < 0.12 ? .house : roll < 0.5 ? .pine : .tree
            let o = Obstacle(kind: kind, x: x, size: kind == .house ? min(size, 1.1) : size)
            if strip.leavesApproachesClear(o, apron: apron, slope: slope) {
                out.append(o)
            }
        }
    }

    /// Off every field's shelf, and under the line rising at `slope` from the
    /// field's nearer end, with 2 m to spare.
    func leavesApproachesClear(_ o: Obstacle, apron: Double, slope: Double) -> Bool {
        let top = groundHeight(at: o.x) + o.height
        return airfields.allSatisfy { field in
            let beyond =
                abs(offset(from: field.start + field.length / 2, to: o.x)) - field.length / 2
                - o.halfWidth
            return beyond > apron && top <= field.elevation + beyond * slope - 2
        }
    }
}
