import QuackCore
import SpriteKit

/// The sky behind everything, fixed to the box: a smooth gradient for the
/// hour, stars at night, the sun with a soft glow or the moon in its phase,
/// and a few slow clouds sliding at a twelfth of the plane's speed. Built for
/// an hour, then only the clouds move.
final class SkyNode: SKNode {
    private struct Cloud {
        let node: SKNode
        let x: CGFloat
        let y: CGFloat
    }

    private var clouds: [Cloud] = []
    private var cloudPeriod: CGFloat = 1

    /// Clouds slide at this fraction of the plane's speed.
    static let cloudParallax: CGFloat = 0.08

    func build(_ palette: Palette, box: CGSize, stripPoints: CGFloat) {
        removeAllChildren()
        let top = box.height * 0.7
        let gradient = SKSpriteNode(texture: SkyNode.gradient(palette.sky))
        gradient.size = box
        gradient.position = CGPoint(x: 0, y: top - box.height / 2)
        addChild(gradient)
        if palette.stars > 0 { addChild(stars(palette, box: box)) }
        addChild(body(palette.body, palette: palette))
        cloudPeriod = stripPoints * SkyNode.cloudParallax
        var rng = SeededRNG(seed: 77)
        let colour = RGB.white.mix(palette.sky[2], 0.25).mix(palette.tint, palette.tintAmount * 0.9)
        clouds = (0..<6).map { i in
            let node = SkyNode.cloud(width: CGFloat(70 + rng.unit() * 90), colour: colour.color())
            addChild(node)
            return Cloud(
                node: node, x: CGFloat(i) * 330 + CGFloat(rng.unit()) * 120,
                y: top - 80 - CGFloat(rng.unit()) * 160)
        }
    }

    /// Slide the clouds for a plane `planePoints` along the strip and a camera `cameraY` up.
    func update(planePoints: CGFloat, cameraY: CGFloat, boxWidth: CGFloat) {
        for c in clouds {
            var x = (c.x - planePoints * SkyNode.cloudParallax).truncatingRemainder(
                dividingBy: cloudPeriod)
            if x < 0 { x += cloudPeriod }
            if x > boxWidth / 2 + 250 { x -= cloudPeriod }
            c.node.position = CGPoint(x: x, y: c.y - cameraY * 0.05)
            c.node.isHidden = x < -boxWidth / 2 - 250
        }
    }

    private static func gradient(_ sky: [RGB]) -> SKTexture {
        let height = 256
        return SkyNode.texture(width: 4, height: height) { ctx in
            for row in 0..<height {
                // Row 0 is the bottom of the image; the gradient fills the top 75%.
                let fromTop = 1 - Double(row) / Double(height - 1)
                let t = min(1, fromTop / 0.75)
                let c =
                    t < 0.55 ? sky[0].mix(sky[1], t / 0.55) : sky[1].mix(sky[2], (t - 0.55) / 0.45)
                ctx.setFillColor(CGColor(red: c.r, green: c.g, blue: c.b, alpha: 1))
                ctx.fill(CGRect(x: 0, y: row, width: 4, height: 1))
            }
        }
    }

    /// A texture drawn into a bitmap, or a blank one if the bitmap cannot be made.
    private static func texture(width: Int, height: Int, draw: (CGContext) -> Void) -> SKTexture {
        guard
            let ctx = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return SKTexture() }
        draw(ctx)
        guard let image = ctx.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }

    private func stars(_ palette: Palette, box: CGSize) -> SKNode {
        let n = SKNode()
        var rng = SeededRNG(seed: 3)
        let paths = [CGMutablePath(), CGMutablePath()]
        for _ in 0..<140 {
            let x = CGFloat(rng.unit()) * box.width - box.width / 2
            let y = box.height * 0.7 - CGFloat(rng.unit()) * box.height * 0.6
            let big = rng.unit() < 0.1
            let side: CGFloat = big ? 2.4 : 1.4
            paths[rng.unit() < 0.5 ? 0 : 1].addRect(CGRect(x: x, y: y, width: side, height: side))
        }
        for (path, alpha) in zip(paths, [0.9, 0.45]) {
            let s = SKShapeNode(path: path)
            s.fillColor = SKColor(
                red: 1, green: 0.98, blue: 0.92, alpha: CGFloat(alpha * palette.stars))
            s.strokeColor = .clear
            n.addChild(s)
        }
        return n
    }

    private func body(_ b: Palette.Body, palette: Palette) -> SKNode {
        let n = SKNode()
        n.position = b.position
        let glowSize = b.radius * 8
        let glow = SKSpriteNode(texture: SkyNode.glow(b.colour))
        glow.size = CGSize(width: glowSize, height: glowSize)
        n.addChild(glow)
        let r = b.radius
        if b.isMoon {
            // The whole moon faint in earthshine, the lit part a crescent: the
            // right half of the disc, less the half-ellipse of the terminator.
            let disc = SKShapeNode(circleOfRadius: r)
            disc.fillColor = palette.sky[1].mix(b.colour, 0.13).color()
            disc.strokeColor = .clear
            n.addChild(disc)
            let crescent = CGMutablePath()
            crescent.addArc(
                center: .zero, radius: r, startAngle: .pi / 2, endAngle: -.pi / 2, clockwise: true)
            for i in 0...24 {
                let a = -CGFloat.pi / 2 + CGFloat(i) / 24 * .pi
                crescent.addLine(to: CGPoint(x: cos(a) * r * 0.4, y: sin(a) * r))
            }
            crescent.closeSubpath()
            let lit = SKShapeNode(path: crescent)
            lit.fillColor = b.colour.color()
            lit.strokeColor = .clear
            n.addChild(lit)
        } else {
            let disc = SKShapeNode(circleOfRadius: r)
            disc.fillColor = b.colour.color()
            disc.strokeColor = .clear
            n.addChild(disc)
        }
        return n
    }

    /// A soft glow fading out from a quarter of the texture's width to its edge.
    private static func glow(_ c: RGB) -> SKTexture {
        let size = 128
        return SkyNode.texture(width: size, height: size) { ctx in
            let colours = [
                CGColor(red: c.r, green: c.g, blue: c.b, alpha: 0.35),
                CGColor(red: c.r, green: c.g, blue: c.b, alpha: 0),
            ]
            guard
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours as CFArray,
                    locations: [0, 1])
            else { return }
            let centre = CGPoint(x: size / 2, y: size / 2)
            ctx.drawRadialGradient(
                gradient, startCenter: centre, startRadius: CGFloat(size) / 8, endCenter: centre,
                endRadius: CGFloat(size) / 2, options: [])
        }
    }

    /// A poster cloud: three flat lozenges stacked, each shorter and lower.
    private static func cloud(width w: CGFloat, colour: SKColor) -> SKNode {
        let n = SKNode()
        for k in 0..<3 {
            let half = w * (1 - CGFloat(k) * 0.25)
            let lozenge = SKShapeNode(
                ellipseIn: CGRect(
                    x: CGFloat(k) * 14 - half, y: -CGFloat(k) * 12 - 7, width: 2 * half, height: 14)
            )
            lozenge.fillColor = colour
            lozenge.strokeColor = .clear
            n.addChild(lozenge)
        }
        return n
    }
}
