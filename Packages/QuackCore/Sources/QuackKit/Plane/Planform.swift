import QuackCore
import SpriteKit

/// A wing or tailplane seen from above, at height u: a rounded plan-form
/// re-drawn from its projected corners, in two crops, the piece in front
/// of the fuselage and the piece behind it.
final class Planform {
    let b: PlaneBuilder
    let u: CGFloat
    let xTE: CGFloat
    let xLE: CGFloat
    let span: CGFloat
    let bulge: CGFloat
    let radius: CGFloat
    let emblems: [(CGFloat, CGFloat)]
    let front = SKCropNode()
    let back = SKCropNode()
    private let frontShape = SKShapeNode()
    private let backShape = SKShapeNode()
    private let frontMask = SKShapeNode()
    private let backMask = SKShapeNode()
    private var frontEmblems: [SKNode] = []
    private var backEmblems: [SKNode] = []

    init(
        b: PlaneBuilder, u: CGFloat, xTE: CGFloat, xLE: CGFloat, span: CGFloat, bulge: CGFloat,
        radius: CGFloat, emblems: [(CGFloat, CGFloat)]
    ) {
        self.b = b
        self.u = u
        self.xTE = xTE
        self.xLE = xLE
        self.span = span
        self.bulge = bulge
        self.radius = radius
        self.emblems = emblems
        for (crop, shape, mask) in [
            (front, frontShape, frontMask), (back, backShape, backMask),
        ] {
            shape.fillColor = b.wing
            shape.strokeColor = PlaneArt.ink
            shape.lineWidth = 2.2 * b.s
            shape.lineJoin = .round
            shape.isAntialiased = true
            mask.fillColor = .white
            mask.strokeColor = .clear
            crop.maskNode = mask
            crop.addChild(shape)
        }
        for _ in emblems {
            let f = b.emblemNode(at: (0, 0), radius: 10)
            let g = b.emblemNode(at: (0, 0), radius: 10)
            frontEmblems.append(f)
            backEmblems.append(g)
            front.addChild(f)
            back.addChild(g)
        }
    }

    /// The projected wing outline: tip curves bulging past the span.
    private func outlinePath(_ proj: (CGFloat, CGFloat) -> PlaneArt.Projected) -> CGPath {
        let fT = proj(xTE, -span), fL = proj(xLE, -span), nT = proj(xTE, span),
            nL = proj(xLE, span)
        let bfT = proj(xTE, -span - bulge), bfL = proj(xLE, -span - bulge)
        let bnT = proj(xTE, span + bulge), bnL = proj(xLE, span + bulge)
        let p = CGMutablePath()
        p.move(to: b.pt(fT.x, fT.y))
        p.addCurve(
            to: b.pt(fL.x, fL.y), control1: b.pt(bfT.x, bfT.y), control2: b.pt(bfL.x, bfL.y))
        p.addLine(to: b.pt(nL.x, nL.y))
        p.addCurve(
            to: b.pt(nT.x, nT.y), control1: b.pt(bnL.x, bnL.y), control2: b.pt(bnT.x, bnT.y))
        p.closeSubpath()
        return p
    }

    private func placeEmblems(_ proj: (CGFloat, CGFloat) -> PlaneArt.Projected, sn: CGFloat) {
        for (i, e) in emblems.enumerated() {
            let q = proj(e.0, e.1)
            for n in [frontEmblems[i], backEmblems[i]] {
                n.position = b.pt(q.x, q.y)
                n.xScale = q.k * 0.9
                n.yScale = q.k * 0.9 * sn
            }
        }
    }

    func layout(c: CGFloat, sn: CGFloat) {
        let s = b.s
        let proj = { (x: CGFloat, z: CGFloat) -> PlaneArt.Projected in
            PlaneArt.project(x: x, u: self.u, z: z, c: c, sn: sn)
        }
        let outline = outlinePath(proj)
        frontShape.path = outline
        backShape.path = outline
        let visible: CGFloat = sn > 0.02 ? 1 : 0
        front.alpha = visible
        back.alpha = visible
        placeEmblems(proj, sn: sn)
        // Where the plan-form passes behind the fuselage: a line at constant screen y.
        let ac = abs(c)
        var zb: CGFloat = ac < 1e-4 ? (u * sn > radius ? -1e4 : 1e4) : (radius - u * sn) / c
        zb = max(-1e4, min(1e4, zb))
        let yb = abs(zb) >= 1e4 ? (zb > 0 ? 1e4 : -1e4) : proj(0, zb).y
        // Screen y (design) grows with z, so the front piece (z > zb when cos ≥ 0) is below the line.
        let frontRange: (CGFloat, CGFloat) = c >= 0 ? (yb, 1e4) : (-1e4, yb)
        let backRange: (CGFloat, CGFloat) = c >= 0 ? (-1e4, yb) : (yb, 1e4)
        frontMask.path = maskRect(frontRange, s)
        backMask.path = maskRect(backRange, s)
    }

    /// A mask covering design y in lo...hi, as points (y flipped).
    private func maskRect(_ r: (CGFloat, CGFloat), _ s: CGFloat) -> CGPath {
        let top = -r.0 * s, bottom = -r.1 * s
        return CGPath(
            rect: CGRect(x: -5000, y: bottom, width: 10000, height: top - bottom),
            transform: nil)
    }
}
