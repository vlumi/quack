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
}
