import QuackCore
import SpriteKit

/// Houses, churches, windmills, hangars and trees, in the poster look: flat
/// shapes with no outlines, trees as lozenges lit down one side. Each node's
/// origin is the prop's foot; `s` is points per metre of prop.
enum PropArt {
    /// What a prop is drawn as. Scenery on the strip and props on the backdrop share them.
    enum Kind {
        case house
        case church
        case mill
        case hangar
        case tree
        case pine
        case poplar
    }

    /// Colours for one layer in one hour.
    struct Paint {
        let palette: Palette
        let layer: Int

        func fill(_ c: RGB) -> SKColor { palette.onLayer(c, layer).color() }
        func light(_ c: RGB, by t: Double) -> SKColor {
            palette.onLayer(c, layer).lighter(t).color()
        }
        /// Lamplight at night, on every layer but the farthest.
        var window: SKColor {
            guard palette.windows > 0, layer > 0 else {
                return fill(Palette.Base.window).withAlphaComponent(0.7)
            }
            return Palette.Base.lamplight.color(alpha: 0.35 + 0.65 * palette.windows)
        }
    }

    static func node(_ kind: Kind, s: CGFloat, size: Double = 1, paint: Paint) -> SKNode {
        let s = s * CGFloat(size)
        switch kind {
        case .house: return house(s: s, big: size > 1, paint: paint)
        case .church: return church(s: s, paint: paint)
        case .mill: return mill(s: s, paint: paint)
        case .hangar: return hangar(s: s, paint: paint)
        case .tree: return tree(s: s, paint: paint)
        case .pine:
            return lozenge(
                Crown(height: 8, width: 2.4, bottom: 1.2, trunk: 1.5, colour: Palette.Base.pine),
                s: s, paint: paint)
        case .poplar:
            return lozenge(
                Crown(height: 9, width: 1.9, bottom: 0.6, trunk: 0, colour: Palette.Base.tree),
                s: s, paint: paint)
        }
    }

    private static func shape(_ path: CGPath, _ colour: SKColor, in parent: SKNode) {
        let n = SKShapeNode(path: path)
        n.fillColor = colour
        n.strokeColor = .clear
        n.isAntialiased = true
        parent.addChild(n)
    }

    private static func polygon(_ points: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: points)
        p.closeSubpath()
        return p
    }

    private static func house(s: CGFloat, big: Bool, paint: Paint) -> SKNode {
        let n = SKNode()
        let w = 8 * s, h = 5 * s
        shape(
            CGPath(rect: CGRect(x: -w / 2, y: 0, width: w, height: h), transform: nil),
            paint.fill(big ? Palette.Base.wall2 : Palette.Base.wall), in: n)
        shape(
            polygon([
                CGPoint(x: -w / 2 - 0.6 * s, y: h), CGPoint(x: 0, y: h + 3.6 * s),
                CGPoint(x: w / 2 + 0.6 * s, y: h),
            ]), paint.fill(big ? Palette.Base.roof2 : Palette.Base.roof), in: n)
        shape(
            CGPath(
                rect: CGRect(x: w * 0.2, y: h + 1.4 * s, width: s, height: 2 * s), transform: nil),
            paint.fill(Palette.Base.roof2), in: n)
        for x in [-w * 0.32, w * 0.12] {
            shape(
                CGPath(
                    rect: CGRect(x: x, y: 0.72 * h - 1.5 * s, width: 1.3 * s, height: 1.5 * s),
                    transform: nil), paint.window, in: n)
        }
        return n
    }

    private static func church(s: CGFloat, paint: Paint) -> SKNode {
        let n = SKNode()
        let w = 11 * s, h = 5.5 * s
        shape(
            CGPath(rect: CGRect(x: -w / 2, y: 0, width: w, height: h), transform: nil),
            paint.fill(Palette.Base.wall), in: n)
        shape(
            polygon([
                CGPoint(x: -w / 2, y: h), CGPoint(x: -w / 2 + 2 * s, y: h + 3 * s),
                CGPoint(x: w / 2, y: h + 3 * s), CGPoint(x: w / 2, y: h),
            ]), paint.fill(Palette.Base.roof2), in: n)
        let tx = -w / 2 - 1.5 * s
        shape(
            CGPath(rect: CGRect(x: tx, y: 0, width: 3.4 * s, height: 11 * s), transform: nil),
            paint.fill(Palette.Base.wall), in: n)
        shape(
            polygon([
                CGPoint(x: tx - 0.3 * s, y: 11 * s), CGPoint(x: tx + 1.7 * s, y: 18 * s),
                CGPoint(x: tx + 3.7 * s, y: 11 * s),
            ]), paint.fill(Palette.Base.roof2), in: n)
        shape(
            CGPath(
                rect: CGRect(x: tx + 1.1 * s, y: 7 * s, width: 1.2 * s, height: 2 * s),
                transform: nil), paint.window, in: n)
        return n
    }

    private static func mill(s: CGFloat, paint: Paint) -> SKNode {
        let n = SKNode()
        shape(
            polygon([
                CGPoint(x: -2.4 * s, y: 0), CGPoint(x: -1.4 * s, y: 9 * s),
                CGPoint(x: 1.4 * s, y: 9 * s), CGPoint(x: 2.4 * s, y: 0),
            ]), paint.fill(Palette.Base.wall2), in: n)
        let cap = CGMutablePath()
        cap.addArc(
            center: CGPoint(x: 0, y: 9 * s), radius: 1.6 * s, startAngle: 0, endAngle: .pi,
            clockwise: false)
        cap.closeSubpath()
        shape(cap, paint.fill(Palette.Base.roof), in: n)
        let sails = SKNode()
        sails.position = CGPoint(x: 0, y: 9 * s)
        let blades = CGMutablePath()
        for k in 0..<4 {
            let t = CGAffineTransform(rotationAngle: CGFloat(k) * .pi / 2)
            blades.addRect(
                CGRect(x: -0.35 * s, y: 0.4 * s, width: 0.7 * s, height: 6.5 * s), transform: t)
        }
        shape(blades, paint.fill(Palette.Base.sail), in: sails)
        sails.zRotation = 0.35
        sails.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 14)))
        n.addChild(sails)
        return n
    }

    private static func hangar(s: CGFloat, paint: Paint) -> SKNode {
        let n = SKNode()
        let w = 20 * s, h = 4.5 * s
        let body = CGMutablePath()
        body.move(to: CGPoint(x: -w / 2, y: 0))
        body.addLine(to: CGPoint(x: -w / 2, y: h))
        body.addQuadCurve(to: CGPoint(x: w / 2, y: h), control: CGPoint(x: 0, y: h + 6 * s))
        body.addLine(to: CGPoint(x: w / 2, y: 0))
        body.closeSubpath()
        shape(body, paint.fill(Palette.Base.hangar), in: n)
        let door = CGPath(
            rect: CGRect(x: -6 * s, y: 0, width: 12 * s, height: 5.2 * s), transform: nil)
        let lit = paint.palette.windows
        shape(door, lit > 0 ? paint.fill(RGB(0x7A6A40)) : paint.fill(Palette.Base.door), in: n)
        if lit > 0 { shape(door, Palette.Base.lamplight.color(alpha: 0.5 * lit), in: n) }
        let sign = SKLabelNode(fontNamed: "AvenirNext-Bold")
        sign.text = "QUACK"
        sign.fontSize = 1.4 * s
        sign.fontColor = paint.fill(.white).withAlphaComponent(0.85)
        sign.verticalAlignmentMode = .baseline
        sign.position = CGPoint(x: 0, y: h + 1.1 * s)
        n.addChild(sign)
        return n
    }

    private static func tree(s: CGFloat, paint: Paint) -> SKNode {
        let n = SKNode()
        shape(
            CGPath(
                rect: CGRect(x: -0.4 * s, y: 0, width: 0.8 * s, height: 2.6 * s), transform: nil),
            paint.fill(Palette.Base.trunk), in: n)
        let crown = CGRect(x: -2.6 * s, y: 1.6 * s, width: 5.2 * s, height: 6.8 * s)
        shape(CGPath(ellipseIn: crown, transform: nil), paint.fill(Palette.Base.tree), in: n)
        let left = CGMutablePath()
        let c = CGPoint(x: crown.midX, y: crown.midY)
        left.move(to: CGPoint(x: c.x, y: crown.maxY))
        for i in 0...24 {
            let a = CGFloat.pi / 2 + CGFloat(i) / 24 * .pi
            left.addLine(
                to: CGPoint(x: c.x + cos(a) * crown.width / 2, y: c.y + sin(a) * crown.height / 2))
        }
        left.closeSubpath()
        shape(left, paint.light(Palette.Base.tree, by: 0.15), in: n)
        return n
    }

    /// A pointed crown's shape, in metres: its top, how far it bulges each side,
    /// where its point meets the trunk, and the trunk's height (0 for none).
    private struct Crown {
        let height: CGFloat
        let width: CGFloat
        let bottom: CGFloat
        let trunk: CGFloat
        let colour: RGB
    }

    /// A pointed crown, widest below the middle, lit down its left side.
    private static func lozenge(_ crown: Crown, s: CGFloat, paint: Paint) -> SKNode {
        let (height, width, bottom, trunk, colour) = (
            crown.height, crown.width, crown.bottom, crown.trunk, crown.colour
        )
        let n = SKNode()
        if trunk > 0 {
            shape(
                CGPath(
                    rect: CGRect(x: -0.35 * s, y: 0, width: 0.7 * s, height: trunk * s),
                    transform: nil), paint.fill(Palette.Base.trunk), in: n)
        }
        let top = CGPoint(x: 0, y: height * s), foot = CGPoint(x: 0, y: bottom * s)
        let bulge = 0.4 * height * s
        let whole = CGMutablePath()
        whole.move(to: top)
        whole.addQuadCurve(to: foot, control: CGPoint(x: width * s, y: bulge))
        whole.addQuadCurve(to: top, control: CGPoint(x: -width * s, y: bulge))
        shape(whole, paint.fill(colour), in: n)
        let left = CGMutablePath()
        left.move(to: top)
        left.addQuadCurve(to: foot, control: CGPoint(x: -width * s, y: bulge))
        left.closeSubpath()
        shape(left, paint.light(colour, by: 0.16), in: n)
        return n
    }
}
