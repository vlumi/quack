import QuackCore
import SpriteKit

/// The guns and their shells on screen: a sandbag ring with a barrel that
/// tracks the plane, a flash when it fires, a wreck when it is knocked out;
/// shells as dark rounds with a short trail, and a burst where one hits.
enum HazardArt {
    static let barrelName = "barrel"

    static func gunNode(scale: CGFloat, palette: Palette) -> SKNode {
        let n = SKNode()
        let ring = SKShapeNode(
            path: {
                let p = CGMutablePath()
                p.addEllipse(
                    in: CGRect(
                        x: -3 * scale, y: -0.6 * scale, width: 6 * scale, height: 1.8 * scale))
                return p
            }())
        ring.fillColor = palette.lit(RGB(0xB8A77A)).color()
        ring.strokeColor = palette.lit(RGB(0x6B5E3F)).color()
        ring.lineWidth = 0.12 * scale
        n.addChild(ring)
        let barrel = SKShapeNode(
            rect: CGRect(x: 0, y: -0.18 * scale, width: 2.6 * scale, height: 0.36 * scale))
        barrel.name = barrelName
        barrel.fillColor = palette.lit(RGB(0x3A3F47)).color()
        barrel.strokeColor = .clear
        barrel.position = CGPoint(x: 0, y: 0.9 * scale)
        barrel.zRotation = .pi / 3
        n.addChild(barrel)
        let mount = SKShapeNode(circleOfRadius: 0.6 * scale)
        mount.fillColor = palette.lit(RGB(0x2E3238)).color()
        mount.strokeColor = .clear
        mount.position = CGPoint(x: 0, y: 0.9 * scale)
        n.addChild(mount)
        return n
    }

    /// Point the barrel at the plane, or leave it drooping on a dead gun.
    static func aim(_ gun: SKNode, at target: CGPoint, alive: Bool) {
        guard let barrel = gun.childNode(withName: barrelName) else { return }
        if alive {
            let dx = target.x - gun.position.x, dy = target.y - (gun.position.y + barrel.position.y)
            barrel.zRotation = atan2(dy, dx)
        } else {
            barrel.zRotation = -0.3
            gun.alpha = 0.55
        }
    }

    static func shellNode(scale: CGFloat) -> SKNode {
        let n = SKNode()
        let trail = SKShapeNode(
            rect: CGRect(
                x: -2.2 * scale, y: -0.12 * scale, width: 2.2 * scale, height: 0.24 * scale))
        trail.fillColor = SKColor(white: 0.2, alpha: 0.35)
        trail.strokeColor = .clear
        n.addChild(trail)
        let round = SKShapeNode(circleOfRadius: 0.3 * scale)
        round.fillColor = SKColor(white: 0.15, alpha: 1)
        round.strokeColor = .clear
        n.addChild(round)
        return n
    }

    /// A puff of smoke that grows and fades, at a hit or a muzzle.
    static func burst(at point: CGPoint, scale: CGFloat, in layer: SKNode, size: CGFloat = 3) {
        let puff = SKShapeNode(circleOfRadius: size * scale * 0.4)
        puff.fillColor = SKColor(white: 0.25, alpha: 0.7)
        puff.strokeColor = .clear
        puff.position = point
        layer.addChild(puff)
        puff.run(
            .sequence([
                .group([.scale(to: 2.5, duration: 0.6), .fadeOut(withDuration: 0.6)]),
                .removeFromParent(),
            ]))
    }
}
