import QuackCore
import SpriteKit

/// The biplane, drawn from a livery: a cartoon Camel with the duck at the
/// stick. Geometry is in art units with the nose along +x and the design
/// sheet's y (down) flipped to SpriteKit's (up); 24 units make a metre, so the
/// plane is a little over six metres long. Every part is a filled or stroked
/// path, so a livery is a colour change, not a redraw.
enum PlaneArt {
    static let unitsPerMetre: CGFloat = 24
    static let ink = SKColor(white: 0.12, alpha: 1)
    static let duck = SKColor(red: 0.95, green: 0.72, blue: 0.02, alpha: 1)
    static let beak = SKColor(red: 0.91, green: 0.44, blue: 0.16, alpha: 1)
    static let helmet = SKColor(red: 0.36, green: 0.23, blue: 0.11, alpha: 1)
    static let fleece = SKColor(red: 0.95, green: 0.90, blue: 0.78, alpha: 1)
    static let goggle = SKColor(red: 0.55, green: 0.72, blue: 0.9, alpha: 1)

    /// The assembled plane and its gloss layer, whose alpha the scene drives
    /// from the plane's attitude against the sun.
    struct Drawing {
        let node: SKNode
        let gloss: SKNode
    }

    static func make(livery: Livery, pointsPerMetre: CGFloat) -> Drawing {
        let b = Builder(scale: pointsPerMetre / unitsPerMetre, livery: livery)
        let root = SKNode()
        for part in b.parts() { root.addChild(part) }
        let gloss = b.gloss()
        root.addChild(gloss)
        return Drawing(node: root, gloss: gloss)
    }

    /// Builds the parts back to front, in art units.
    struct Builder {
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

        func parts() -> [SKNode] {
            var out: [SKNode] = []
            out.append(ellipse(cx: 75, cy: 0, rx: 4, ry: 24, fill: ink.withAlphaComponent(0.28)))
            out.append(fill(airfoil(xTE: -74, xLE: -38, t: 6, y0: 0), wing))
            out.append(stroke(line((-61, -2.4), (-61, 2.1)), 1.5))
            out.append(
                fill(poly((-66, -4), (-60, -38), q: (-58, -42), (-52, -40), (-30, -6)), body))
            out.append(emblemNode(at: (-52.5, -21), radius: 8))
            out.append(stroke(line((-60, 6), (-64, 13)), 2.8))
            out.append(fill(fuselage(), body))
            out.append(fill(cowl(), trim))
            out.append(fill(rect(x: 52, y: -4, w: 4, h: 8, r: 1), ink, line: 0))
            out.append(fill(cockpit(), ink))
            out.append(circle(cx: -18, cy: -23, r: 10, fill: duck, line: 2.2))
            out.append(fill(earFlap(), helmet))
            out.append(fill(cap(), helmet))
            out.append(stroke(fleeceWave(), 2, color: fleece))
            out.append(fill(poly((-9, -22), (2, -19), (-9, -15)), beak, line: 1.5))
            out.append(circle(cx: -15, cy: -21, r: 3.5, fill: goggle, line: 1.5))
            out.append(circle(cx: -15, cy: -21, r: 1.2, fill: ink, line: 0))
            out.append(
                fill(
                    poly((2, -14.5), (-2, -25), (2, -25), (6, -14.7)),
                    SKColor(white: 1, alpha: 0.55), line: 0))
            out.append(stroke(open((2, -14.5), (-2, -25), (2, -25), (6, -14.7)), 1.5))
            out.append(stroke(open((30, 17), (36, 29), (44, 17)), 2.8))
            out.append(circle(cx: 36, cy: 32, r: 9, fill: ink, line: 0))
            out.append(circle(cx: 36, cy: 32, r: 3, fill: wing, line: 0))
            out.append(fill(airfoil(xTE: -6, xLE: 60, t: 9, y0: -36), wing))
            out.append(fill(airfoil(xTE: -14, xLE: 46, t: 8, y0: 15), wing))
            out.append(stroke(line((4, 11), (48, -33)), 1.5))
            out.append(stroke(line((34, 8.5), (18, -34)), 1.5))
            out.append(stroke(line((4, 11), (18, -34)), 2.8))
            out.append(stroke(line((34, 8.5), (48, -33)), 2.8))
            out.append(circle(cx: 73, cy: 0, r: 4.5, fill: ink, line: 0))
            return out
        }

        /// Enamel highlights: a streak along the fuselage top, the cowl, the
        /// upper wing and the hubcap. Shown by attitude, see FlightScene.
        func gloss() -> SKNode {
            let g = SKNode()
            let white = SKColor.white
            g.addChild(stroke(quad((2, -14), c: (22, -15.5), (44, -13.5)), 2.5, color: white))
            g.addChild(stroke(quad((52, -10), c: (60, -11), (66, -6)), 3, color: white))
            g.addChild(stroke(quad((14, -40), c: (36, -45.5), (55, -43.5)), 2, color: white))
            g.addChild(circle(cx: 33, cy: 29, r: 2, fill: white, line: 0))
            return g
        }

        // MARK: Shapes (design-sheet coordinates, y down)

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
        /// `xTE` and `xLE` are the trailing and leading edges, `t` the
        /// thickness, `y0` the chord line.
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

        func quad(_ a: (CGFloat, CGFloat), c: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) -> CGPath
        {
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
            n.strokeColor = line > 0 ? ink : .clear
            n.lineWidth = line * s
            n.lineJoin = .round
            n.lineCap = .round
            n.isAntialiased = true
            return n
        }

        func stroke(_ path: CGPath, _ width: CGFloat, color: SKColor = PlaneArt.ink) -> SKShapeNode
        {
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
}

extension SKColor {
    convenience init(_ c: Livery.Color) {
        self.init(red: c.red, green: c.green, blue: c.blue, alpha: 1)
    }
}
