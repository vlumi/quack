import QuackCore
import SpriteKit

/// The scene's small drawings: balloons, their pop, tracer rounds and the
/// edge chevrons. Sizes are in scene units, from the scene's metre scale.
enum SceneArt {
    static func balloonNode(radius r: CGFloat, colour: SKColor) -> SKNode {
        let n = SKNode()
        let body = SKShapeNode(
            ellipseIn: CGRect(x: -r, y: -r * 1.15, width: 2 * r, height: 2.3 * r))
        body.fillColor = colour
        body.strokeColor = SKColor(white: 0.12, alpha: 1)
        body.lineWidth = r * 0.11
        let knot = SKShapeNode(
            path: {
                let p = CGMutablePath()
                p.addLines(between: [
                    CGPoint(x: -r * 0.2, y: -r * 1.35), CGPoint(x: r * 0.2, y: -r * 1.35),
                    CGPoint(x: 0, y: -r * 1.1),
                ])
                p.closeSubpath()
                return p
            }())
        knot.fillColor = colour
        knot.strokeColor = SKColor(white: 0.12, alpha: 1)
        knot.lineWidth = r * 0.08
        let string = SKShapeNode(
            path: {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 0, y: -r * 1.35))
                p.addQuadCurve(
                    to: CGPoint(x: r * 0.3, y: -r * 3), control: CGPoint(x: -r * 0.5, y: -r * 2.2))
                return p
            }())
        string.strokeColor = SKColor(white: 0.12, alpha: 0.8)
        string.lineWidth = r * 0.08
        let shine = SKShapeNode(
            ellipseIn: CGRect(x: -r * 0.55, y: r * 0.25, width: r * 0.35, height: r * 0.5))
        shine.fillColor = SKColor(white: 1, alpha: 0.5)
        shine.strokeColor = .clear
        for c in [string, body, knot, shine] { n.addChild(c) }
        return n
    }

    static func burst(_ n: SKNode) {
        n.run(
            .sequence([
                .group([.scale(to: 1.5, duration: 0.12), .fadeOut(withDuration: 0.12)]),
                .removeFromParent(),
            ]))
    }

    /// A round: a dark slug with a warm tracer trail tapering behind it, so it
    /// reads against the sky. The trail is the first child, scaled by age.
    static func tracerNode(scale: CGFloat) -> SKNode {
        let n = SKNode()
        let trail = SKShapeNode(
            path: {
                let p = CGMutablePath()
                p.addLines(between: [
                    CGPoint(x: 0, y: 0.27 * scale), CGPoint(x: -4 * scale, y: 0),
                    CGPoint(x: 0, y: -0.27 * scale),
                ])
                p.closeSubpath()
                return p
            }())
        trail.fillColor = SKColor(red: 1, green: 0.8, blue: 0.4, alpha: 0.85)
        trail.strokeColor = .clear
        let slug = SKShapeNode(circleOfRadius: 0.37 * scale)
        slug.fillColor = SKColor(white: 0.12, alpha: 1)
        slug.strokeColor = SKColor(red: 1, green: 0.9, blue: 0.6, alpha: 1)
        slug.lineWidth = 1
        n.addChild(trail)
        n.addChild(slug)
        return n
    }

    static func markerNode(scale: CGFloat, colour: SKColor) -> SKShapeNode {
        let u = scale * 0.22
        let p = CGMutablePath()
        p.addLines(between: [
            CGPoint(x: 7 * u, y: 0), CGPoint(x: -5 * u, y: 5 * u), CGPoint(x: -2.5 * u, y: 0),
            CGPoint(x: -5 * u, y: -5 * u),
        ])
        p.closeSubpath()
        let m = SKShapeNode(path: p)
        m.fillColor = colour
        m.strokeColor = SKColor(white: 0.12, alpha: 1)
        m.lineWidth = u * 0.8
        m.lineJoin = .round
        return m
    }

    // MARK: The field

    /// A mown strip in the ground line: a tan band, threshold bars at both ends,
    /// and a windsock by the left threshold.
    static func airfieldNode(_ field: Airfield, scale: CGFloat) -> SKNode {
        let n = SKNode()
        let x0 = CGFloat(field.start) * scale, x1 = CGFloat(field.end) * scale
        let ink = SKColor(white: 0.12, alpha: 1)
        let band = SKShapeNode(
            rect: CGRect(x: x0, y: -1.2 * scale, width: x1 - x0, height: 1.2 * scale))
        band.fillColor = SKColor(red: 0.78, green: 0.68, blue: 0.48, alpha: 1)
        band.strokeColor = .clear
        n.addChild(band)
        let bars = CGMutablePath()
        for end in [x0, x1] {
            let inward: CGFloat = end == x0 ? 1 : -1
            for k in 0..<4 {
                let bx = end + inward * (1.5 + CGFloat(k) * 2) * scale
                bars.addRect(
                    CGRect(
                        x: bx - 0.4 * scale, y: -1.0 * scale, width: 0.8 * scale,
                        height: 0.8 * scale))
            }
        }
        let barNode = SKShapeNode(path: bars)
        barNode.fillColor = .white
        barNode.strokeColor = .clear
        n.addChild(barNode)
        let pole = SKShapeNode(
            rect: CGRect(x: x0 - 6 * scale, y: 0, width: 0.25 * scale, height: 6 * scale))
        pole.fillColor = ink
        pole.strokeColor = .clear
        n.addChild(pole)
        let sock = CGMutablePath()
        let top = CGPoint(x: x0 - 5.8 * scale, y: 6 * scale)
        sock.addLines(between: [
            top, CGPoint(x: top.x + 3 * scale, y: top.y - 0.35 * scale),
            CGPoint(x: top.x + 3 * scale, y: top.y - 0.9 * scale),
            CGPoint(x: top.x, y: top.y - 1.25 * scale),
        ])
        sock.closeSubpath()
        let sockNode = SKShapeNode(path: sock)
        sockNode.fillColor = SKColor(red: 0.93, green: 0.45, blue: 0.15, alpha: 1)
        sockNode.strokeColor = ink
        sockNode.lineWidth = 0.1 * scale
        n.addChild(sockNode)
        return n
    }

    /// The approach window drawn in the sky: a faint wedge rising from each end
    /// of the field at the approach angle ± the band, with the angle itself dashed.
    static func glideSlopes(_ field: Airfield, landing: LandingTuning, scale: CGFloat) -> SKNode {
        let n = SKNode()
        let reach: CGFloat = 220 * scale
        let a = CGFloat(landing.approachAngle) * .pi / 180
        let b = CGFloat(landing.approachBand) * .pi / 180
        for (origin, outward) in [
            (CGFloat(field.start) * scale, CGFloat(-1)), (CGFloat(field.end) * scale, 1),
        ] {
            let wedge = CGMutablePath()
            wedge.move(to: CGPoint(x: origin, y: 0))
            wedge.addLine(to: CGPoint(x: origin + outward * reach, y: reach * tan(max(0, a - b))))
            wedge.addLine(to: CGPoint(x: origin + outward * reach, y: reach * tan(a + b)))
            wedge.closeSubpath()
            let fill = SKShapeNode(path: wedge)
            fill.fillColor = SKColor(white: 1, alpha: 0.13)
            fill.strokeColor = .clear
            n.addChild(fill)
            let centre = CGMutablePath()
            centre.move(to: CGPoint(x: origin, y: 0))
            centre.addLine(to: CGPoint(x: origin + outward * reach, y: reach * tan(a)))
            let dashed = SKShapeNode(
                path: centre.copy(dashingWithPhase: 0, lengths: [2 * scale, 2 * scale]))
            dashed.strokeColor = SKColor(white: 1, alpha: 0.45)
            dashed.lineWidth = 0.25 * scale
            n.addChild(dashed)
        }
        return n
    }
}
