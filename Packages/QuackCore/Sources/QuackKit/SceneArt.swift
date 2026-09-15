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
    /// and a windsock beside the middle, faded back so a plane landing or
    /// rolling past it reads as passing in front rather than through it.
    static let sockName = "windsock"

    /// Point a field's windsock downwind, one shape per wind step so a glance
    /// says which: hanging down the pole in a calm, drooping in a low wind,
    /// half out, nearly straight, and straight out and flapping in a gale.
    static func setWindsock(in field: SKNode, step: WindStep, direction: Double) {
        guard let sock = field.childNode(withName: "//\(sockName)") else { return }
        let key = "\(step.rawValue)\(direction)"
        guard sock.userData?["wind"] as? String != key else { return }
        sock.userData = ["wind": key]
        sock.removeAllActions()
        let way: CGFloat = direction < 0 ? -1 : 1
        let droop: CGFloat
        switch step {
        case .calm: droop = 1.45
        case .low: droop = 1.0
        case .medium: droop = 0.55
        case .strong: droop = 0.18
        case .gale: droop = 0
        }
        sock.xScale = way * (0.55 + 0.45 * (1 - droop / 1.45))
        sock.zRotation = -way * droop
        if step == .gale {
            let up = SKAction.rotate(byAngle: way * 0.1, duration: 0.18)
            let down = SKAction.rotate(byAngle: -way * 0.1, duration: 0.22)
            sock.run(.repeatForever(.sequence([up, down])))
        }
    }

    static func airfieldNode(_ field: Airfield, scale: CGFloat, palette: Palette) -> SKNode {
        let n = SKNode()
        let x0 = CGFloat(field.start) * scale, x1 = CGFloat(field.end) * scale
        let ink = SKColor(white: 0.12, alpha: 1)
        let band = SKShapeNode(
            rect: CGRect(x: x0, y: -1.2 * scale, width: x1 - x0, height: 1.2 * scale))
        band.fillColor = palette.lit(Palette.Base.field).color()
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
        barNode.fillColor = palette.lit(.white).color()
        barNode.strokeColor = .clear
        n.addChild(barNode)
        let windsock = SKNode()
        windsock.alpha = 0.55
        windsock.zPosition = -1
        n.addChild(windsock)
        let mid = (x0 + x1) / 2
        let pole = SKShapeNode(
            rect: CGRect(x: mid - 0.12 * scale, y: 0, width: 0.25 * scale, height: 6 * scale))
        pole.fillColor = ink
        pole.strokeColor = .clear
        windsock.addChild(pole)
        // The sock hangs from the pole's top, pointing downwind; the scene
        // turns it for the wind (`SceneArt.setWindsock`).
        let sock = CGMutablePath()
        sock.addLines(between: [
            .zero, CGPoint(x: 3 * scale, y: -0.35 * scale), CGPoint(x: 3 * scale, y: -0.9 * scale),
            CGPoint(x: 0, y: -1.25 * scale),
        ])
        sock.closeSubpath()
        let sockNode = SKShapeNode(path: sock)
        sockNode.name = SceneArt.sockName
        sockNode.position = CGPoint(x: mid + 0.1 * scale, y: 6 * scale)
        sockNode.fillColor = palette.lit(Palette.Base.sock).color()
        sockNode.strokeColor = ink
        sockNode.lineWidth = 0.1 * scale
        windsock.addChild(sockNode)
        return n
    }

    /// The approach cone drawn in the sky over each end of the field, the exact
    /// region where the assist can take over: floor, ceiling and the low throat
    /// over the threshold, with the approach angle dashed along its middle.
    static func approachCones(_ model: AirfieldModel, field: Airfield, scale: CGFloat) -> SKNode {
        let n = SKNode()
        let landing = model.landing
        let a = landing.approachAngle * .pi / 180
        let b = landing.approachBand * .pi / 180
        for (end, outwardSign) in [(field.start, -1.0), (field.end, 1.0)] {
            func point(_ outward: Double, _ height: Double) -> CGPoint {
                CGPoint(x: (end + outwardSign * outward) * scale, y: height * scale)
            }
            let samples = stride(from: -landing.throatLength, through: landing.coneLength, by: 1)
                .map { $0 }
            let cone = CGMutablePath()
            cone.move(to: point(samples[0], model.coneFloor(outward: samples[0], a: a, b: b)))
            for o in samples.dropFirst() {
                cone.addLine(to: point(o, model.coneFloor(outward: o, a: a, b: b)))
            }
            for o in samples.reversed() {
                cone.addLine(to: point(o, model.coneCeiling(along: max(0, o), a: a, b: b)))
            }
            cone.closeSubpath()
            let fill = SKShapeNode(path: cone)
            fill.fillColor = SKColor(white: 1, alpha: 0.14)
            fill.strokeColor = SKColor(white: 1, alpha: 0.3)
            fill.lineWidth = 0.15 * scale
            n.addChild(fill)
            let centre = CGMutablePath()
            centre.move(to: point(0, 0))
            centre.addLine(to: point(landing.coneLength, landing.coneLength * tan(a)))
            let dashed = SKShapeNode(
                path: centre.copy(dashingWithPhase: 0, lengths: [2 * scale, 2 * scale]))
            dashed.strokeColor = SKColor(white: 1, alpha: 0.45)
            dashed.lineWidth = 0.25 * scale
            n.addChild(dashed)
        }
        return n
    }
}
