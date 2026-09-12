import QuackCore
import SpriteKit

/// The biplane's drawing constants. The plane itself is `PlaneNode`; the
/// paths and paints are `PlaneBuilder`; a wing seen from above is `Planform`.
enum PlaneArt {
    static let unitsPerMetre: CGFloat = 24
    static let ink = SKColor(white: 0.12, alpha: 1)
    static let duck = SKColor(red: 0.95, green: 0.72, blue: 0.02, alpha: 1)
    static let beak = SKColor(red: 0.91, green: 0.44, blue: 0.16, alpha: 1)
    static let helmet = SKColor(red: 0.36, green: 0.23, blue: 0.11, alpha: 1)
    static let fleece = SKColor(red: 0.95, green: 0.90, blue: 0.78, alpha: 1)
    static let goggle = SKColor(red: 0.55, green: 0.72, blue: 0.9, alpha: 1)
    static let gunMetal = SKColor(white: 0.23, alpha: 1)
    static let gunLight = SKColor(white: 0.6, alpha: 1)
    /// Fuselage radius, for what passes behind it.
    static let bodyRadius: CGFloat = 14
    /// Camera distance for the perspective, in design units.
    static let cameraDistance: CGFloat = 500

    /// A point projected for a roll: screen x and y in design units, and its perspective factor.
    struct Projected {
        var x: CGFloat
        var y: CGFloat
        var k: CGFloat
    }

    /// Where a point at height u (above the axis) and depth z (toward the
    /// camera) lands on screen for a roll with cosine c and sine sn.
    static func project(x: CGFloat, u: CGFloat, z: CGFloat, c: CGFloat, sn: CGFloat) -> Projected {
        let k = cameraDistance / (cameraDistance - (u * sn + z * c))
        return Projected(x: x * k, y: (-u * c + z * sn) * k, k: k)
    }
}

/// Paints and primitives, in design units (y down) scaled to points.
final class PlaneBuilder {
    let s: CGFloat
    let body: SKColor
    let wing: SKColor
    let trim: SKColor
    let emblemInk: SKColor
    let emblemField: SKColor
    let emblem: Livery.Emblem

    init(scale: CGFloat, livery: Livery) {
        s = scale
        body = SKColor(livery.body)
        wing = SKColor(livery.wing)
        trim = SKColor(livery.trim)
        emblemInk = SKColor(livery.emblemInk)
        emblemField = SKColor(livery.emblemField)
        emblem = livery.emblem
    }

    func node(_ children: SKNode...) -> SKNode {
        let n = SKNode()
        for c in children { n.addChild(c) }
        return n
    }

    /// The drawing shifted so that design line y0 sits at the node's origin,
    /// which is what the roll squashes about.
    func pivoted(_ drawing: SKNode, y0: CGFloat) -> SKNode {
        drawing.position.y = y0 * s
        return node(drawing)
    }

    func gloss() -> SKNode {
        let white = SKColor.white
        return node(
            stroke(quad((2, -14), c: (22, -15.5), (44, -13.5)), 2.5, color: white),
            stroke(quad((52, -10), c: (60, -11), (66, -6)), 3, color: white),
            stroke(quad((14, -40), c: (36, -45.5), (55, -43.5)), 2, color: white),
            circle(cx: 33, cy: 29, r: 2, fill: white, line: 0))
    }

    /// The drawing wrapped so that the design point (dx, dy) is the wrapper's
    /// origin: what the roll scales and flips the pilot about is his head.
    func centred(_ n: SKNode, _ dx: CGFloat, _ dy: CGFloat) -> SKNode {
        n.position = pt(dx, dy)
        return node(n)
    }

    func sideHead() -> SKNode {
        centred(
            node(
                circle(cx: -18, cy: -23, r: 10, fill: PlaneArt.duck, line: 2.2),
                fill(earFlap(), PlaneArt.helmet),
                fill(cap(), PlaneArt.helmet),
                stroke(fleeceWave(), 2, color: PlaneArt.fleece),
                fill(poly((-9, -22), (2, -19), (-9, -15)), PlaneArt.beak, line: 1.5),
                circle(cx: -15, cy: -21, r: 3.5, fill: PlaneArt.goggle, line: 1.5),
                circle(cx: -15, cy: -21, r: 1.2, fill: PlaneArt.ink, line: 0)
            ), 18, 23)
    }

    func topHead() -> SKNode {
        centred(
            node(
                circle(cx: -18, cy: 0, r: 9, fill: PlaneArt.helmet, line: 2.2),
                fill(poly((-9, -3), (2, 0), (-9, 3)), PlaneArt.beak, line: 1.5),
                circle(cx: -11.5, cy: -3.5, r: 2.5, fill: PlaneArt.goggle, line: 1.5),
                circle(cx: -11.5, cy: 3.5, r: 2.5, fill: PlaneArt.goggle, line: 1.5)
            ), 18, 0)
    }

    func sideWindscreen() -> SKNode {
        node(
            fill(
                poly((2, -14.5), (-2, -25), (2, -25), (6, -14.7)),
                SKColor(white: 1, alpha: 0.55), line: 0),
            stroke(open((2, -14.5), (-2, -25), (2, -25), (6, -14.7)), 1.5))
    }

    func topWindscreen() -> SKNode {
        node(
            fill(
                rect(x: 0, y: -8, w: 2.5, h: 16, r: 0), SKColor(white: 1, alpha: 0.55), line: 0),
            stroke(line((0, -8), (0, 8)), 1.5))
    }

    /// A Vickers on the hump: breech, cooling jacket with vent holes, muzzle, ring sight.
    func sideGun() -> SKNode {
        let holes = stroke(line((14, -17.5), (38, -17.5)), 1.4, color: PlaneArt.gunLight)
        holes.path = holes.path?.copy(dashingWithPhase: 0, lengths: [0, 4 * s])
        return node(
            fill(rect(x: 10, y: -19.5, w: 32, h: 4, r: 2), PlaneArt.gunMetal, line: 1.5),
            holes,
            fill(rect(x: 6, y: -22, w: 10, h: 7.5, r: 1.5), PlaneArt.ink, line: 0),
            fill(rect(x: 42, y: -18.6, w: 5, h: 2.2, r: 1), PlaneArt.ink, line: 0),
            stroke(open((11, -22), (11, -25)), 1.5),
            stroke(open((9.5, -25), (12.5, -25)), 1.5))
    }

    func topGun() -> SKNode {
        node(
            fill(rect(x: 10, y: -2.2, w: 32, h: 4.4, r: 2), PlaneArt.gunMetal, line: 1.5),
            fill(rect(x: 6, y: -3.5, w: 10, h: 7, r: 1.5), PlaneArt.ink, line: 0),
            fill(rect(x: 42, y: -1.2, w: 5, h: 2.4, r: 1), PlaneArt.ink, line: 0))
    }

    /// Interplane struts and cross wires on one side, at depth z, projected for the roll.
    func struts(z: CGFloat, c: CGFloat, sn: CGFloat) -> CGPath {
        let p = { (x: CGFloat, u: CGFloat) -> CGPoint in
            let q = PlaneArt.project(x: x, u: u, z: z, c: c, sn: sn)
            return self.pt(q.x, q.y)
        }
        let path = CGMutablePath()
        path.move(to: p(4, -11))
        path.addLine(to: p(18, 34))
        path.move(to: p(34, -8.5))
        path.addLine(to: p(48, 33))
        path.move(to: p(4, -11))
        path.addLine(to: p(48, 33))
        path.move(to: p(34, -8.5))
        path.addLine(to: p(18, 34))
        return path
    }

    // MARK: Shapes (design coordinates, y down)

    func fuselage() -> CGPath {
        let p = CGMutablePath()
        p.move(to: pt(58, -13))
        p.addQuadCurve(to: pt(71, 0), control: pt(71, -13))
        p.addQuadCurve(to: pt(58, 13), control: pt(71, 13))
        p.addLine(to: pt(14, 15))
        p.addQuadCurve(to: pt(-64, 5), control: pt(-30, 12))
        p.addLine(to: pt(-64, -5))
        p.addQuadCurve(to: pt(14, -15), control: pt(-30, -12))
        p.closeSubpath()
        return p
    }

    func cowl() -> CGPath {
        let p = CGMutablePath()
        p.move(to: pt(58, -13))
        p.addQuadCurve(to: pt(71, 0), control: pt(71, -13))
        p.addQuadCurve(to: pt(58, 13), control: pt(71, 13))
        p.addLine(to: pt(48, 13.4))
        p.addLine(to: pt(48, -13.4))
        p.closeSubpath()
        return p
    }

    func cockpit() -> CGPath {
        let p = CGMutablePath()
        p.move(to: pt(-31, -11.2))
        p.addQuadCurve(to: pt(-18, -5), control: pt(-31, -5))
        p.addQuadCurve(to: pt(-5, -13.5), control: pt(-5, -5))
        p.closeSubpath()
        return p
    }

    func earFlap() -> CGPath {
        let p = CGMutablePath()
        p.move(to: pt(-28, -25.5))
        p.addQuadCurve(to: pt(-25, -13), control: pt(-30, -15))
        p.addQuadCurve(to: pt(-21.5, -25.5), control: pt(-21, -14))
        p.closeSubpath()
        return p
    }

    func cap() -> CGPath {
        let p = CGMutablePath()
        p.move(to: pt(-28.3, -25))
        p.addCurve(to: pt(-18, -36), control1: pt(-30, -33), control2: pt(-25, -36))
        p.addCurve(to: pt(-7.7, -25), control1: pt(-11, -36), control2: pt(-6, -33))
        p.closeSubpath()
        return p
    }

    func fleeceWave() -> CGPath {
        let p = CGMutablePath()
        p.move(to: pt(-27.6, -25.3))
        p.addQuadCurve(to: pt(-22.7, -25.3), control: pt(-25.2, -27.1))
        p.addQuadCurve(to: pt(-17.8, -25.3), control: pt(-20.2, -23.5))
        p.addQuadCurve(to: pt(-12.9, -25.3), control: pt(-15.4, -27.1))
        p.addQuadCurve(to: pt(-8, -25.3), control: pt(-10.4, -23.5))
        return p
    }

    /// A wing seen edge-on: rounded leading edge, tapering trailing edge.
    func airfoil(xTE: CGFloat, xLE: CGFloat, t: CGFloat, y0: CGFloat) -> CGPath {
        let c = xLE - xTE
        let p = CGMutablePath()
        p.move(to: pt(xTE, y0))
        p.addCurve(
            to: pt(xLE - 0.04 * c, y0 - 0.8 * t),
            control1: pt(xTE + 0.3 * c, y0 - 0.55 * t),
            control2: pt(xLE - 0.25 * c, y0 - 0.95 * t))
        p.addQuadCurve(
            to: pt(xLE - 0.06 * c, y0 + 0.3 * t), control: pt(xLE + 0.02 * c, y0 - 0.3 * t))
        p.addCurve(
            to: pt(xTE, y0),
            control1: pt(xLE - 0.3 * c, y0 + 0.45 * t),
            control2: pt(xTE + 0.3 * c, y0 + 0.2 * t))
        p.closeSubpath()
        return p
    }

    func emblemNode(at c: (CGFloat, CGFloat), radius r: CGFloat) -> SKNode {
        let g = SKNode()
        g.position = pt(c.0, c.1)
        switch emblem {
        case .roundel:
            g.addChild(circle(cx: 0, cy: 0, r: r, fill: emblemInk, line: 0))
            g.addChild(circle(cx: 0, cy: 0, r: r * 0.65, fill: emblemField, line: 0))
            g.addChild(circle(cx: 0, cy: 0, r: r * 0.3, fill: emblemInk, line: 0))
        case .star:
            g.addChild(circle(cx: 0, cy: 0, r: r, fill: emblemField, line: 0))
            let p = CGMutablePath()
            for i in 0..<10 {
                let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
                let rr = i.isMultiple(of: 2) ? r * 0.75 : r * 0.3
                let v = CGPoint(x: cos(a) * rr * s, y: -sin(a) * rr * s)
                if i == 0 { p.move(to: v) } else { p.addLine(to: v) }
            }
            p.closeSubpath()
            g.addChild(fill(p, emblemInk, line: 0))
        case .checker:
            g.addChild(circle(cx: 0, cy: 0, r: r, fill: emblemField, line: 0))
            g.addChild(
                fill(
                    rect(x: -0.6 * r, y: -0.6 * r, w: 0.6 * r, h: 0.6 * r, r: 0), emblemInk,
                    line: 0))
            g.addChild(fill(rect(x: 0, y: 0, w: 0.6 * r, h: 0.6 * r, r: 0), emblemInk, line: 0))
            let ring = circle(cx: 0, cy: 0, r: r, fill: .clear, line: 1.5)
            ring.strokeColor = emblemInk
            g.addChild(ring)
        }
        return g
    }

    // MARK: Primitives

    /// Design-sheet units to points, flipping y.
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * s, y: -y * s)
    }

    func poly(_ pts: (CGFloat, CGFloat)...) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: pts.map { pt($0.0, $0.1) })
        p.closeSubpath()
        return p
    }

    /// A polygon whose second edge is a quadratic curve through `q`.
    func poly(
        _ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat), q: (CGFloat, CGFloat),
        _ c: (CGFloat, CGFloat), _ d: (CGFloat, CGFloat)
    ) -> CGPath {
        let p = CGMutablePath()
        p.move(to: pt(a.0, a.1))
        p.addLine(to: pt(b.0, b.1))
        p.addQuadCurve(to: pt(c.0, c.1), control: pt(q.0, q.1))
        p.addLine(to: pt(d.0, d.1))
        p.closeSubpath()
        return p
    }

    func open(_ pts: (CGFloat, CGFloat)...) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: pts.map { pt($0.0, $0.1) })
        return p
    }

    func line(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) -> CGPath {
        open(a, b)
    }

    func quad(_ a: (CGFloat, CGFloat), c: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) -> CGPath {
        let p = CGMutablePath()
        p.move(to: pt(a.0, a.1))
        p.addQuadCurve(to: pt(b.0, b.1), control: pt(c.0, c.1))
        return p
    }

    func rect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat) -> CGPath {
        let frame = CGRect(x: x * s, y: -(y + h) * s, width: w * s, height: h * s)
        return CGPath(
            roundedRect: frame, cornerWidth: r * s, cornerHeight: r * s, transform: nil)
    }

    func fill(_ path: CGPath, _ color: SKColor, line: CGFloat = 2.2) -> SKShapeNode {
        let n = SKShapeNode(path: path)
        n.fillColor = color
        n.strokeColor = line > 0 ? PlaneArt.ink : .clear
        n.lineWidth = line * s
        n.lineJoin = .round
        n.lineCap = .round
        n.isAntialiased = true
        return n
    }

    func stroke(_ path: CGPath, _ width: CGFloat, color: SKColor = PlaneArt.ink) -> SKShapeNode {
        let n = SKShapeNode(path: path)
        n.fillColor = .clear
        n.strokeColor = color
        n.lineWidth = width * s
        n.lineJoin = .round
        n.lineCap = .round
        n.isAntialiased = true
        return n
    }

    func circle(cx: CGFloat, cy: CGFloat, r: CGFloat, fill color: SKColor, line: CGFloat)
        -> SKShapeNode
    {
        let frame = CGRect(
            x: (cx - r) * s, y: -(cy + r) * s, width: 2 * r * s, height: 2 * r * s)
        return fill(CGPath(ellipseIn: frame, transform: nil), color, line: line)
    }

    func ellipse(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat, fill color: SKColor)
        -> SKShapeNode
    {
        let frame = CGRect(
            x: (cx - rx) * s, y: -(cy + ry) * s, width: 2 * rx * s, height: 2 * ry * s)
        return fill(CGPath(ellipseIn: frame, transform: nil), color, line: 0)
    }
}

extension SKColor {
    convenience init(_ c: Livery.Color) {
        self.init(red: c.red, green: c.green, blue: c.blue, alpha: 1)
    }
}
