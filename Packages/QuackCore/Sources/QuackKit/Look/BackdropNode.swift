import QuackCore
import SpriteKit

/// The backdrop's three layers on screen, fixed to the box: each a ridge drawn
/// in two tones (a lit band along the top over a shaded body) with its props
/// standing behind the ridge line. Every frame the ridges are redrawn across
/// the box and the props slid into place, each layer at its own parallax.
final class BackdropNode: SKNode {
    private struct Drawn {
        let layer: BackdropLayer
        let lit: SKShapeNode
        let shaded: SKShapeNode
        let props: [SKNode]
    }

    private var drawn: [Drawn] = []

    func build(_ backdrop: Backdrop, palette: Palette, scale: CGFloat) {
        removeAllChildren()
        drawn = backdrop.layers.enumerated().map { index, layer in
            let paint = PropArt.Paint(palette: palette, layer: index)
            let props = layer.props.map { prop -> SKNode in
                let node = PropArt.node(
                    BackdropNode.kind(prop.kind), s: scale * CGFloat(layer.propScale),
                    size: prop.size,
                    paint: paint)
                addChild(node)
                return node
            }
            let fill = palette.onLayer(Palette.Base.layers[index], index)
            let lit = SKShapeNode()
            lit.fillColor = fill.lighter(0.13).color()
            let shaded = SKShapeNode()
            shaded.fillColor = fill.darker(0.06).color()
            for shape in [lit, shaded] {
                shape.strokeColor = .clear
                addChild(shape)
            }
            return Drawn(layer: layer, lit: lit, shaded: shaded, props: props)
        }
    }

    /// Lay the layers out for a plane `planeX` metres along the strip and a
    /// camera `cameraY` points up, across a box `box` wide.
    func update(planeX: Double, cameraY: CGFloat, scale: CGFloat, box: CGSize) {
        let half = box.width / 2
        let bottom = -box.height
        for (index, d) in drawn.enumerated() {
            let layer = d.layer
            let shift = planeX * layer.parallax
            let base = CGFloat(layer.baseline) * scale - cameraY * CGFloat(layer.rise)
            let ridge = { (px: CGFloat) -> CGFloat in
                base + CGFloat(layer.height(at: layer.wrap(Double(px / scale) + shift))) * scale
            }
            let drop = 10 + 6 * CGFloat(index)
            d.lit.path = BackdropNode.ridgePath(ridge, drop: 0, half: half, bottom: bottom)
            d.shaded.path = BackdropNode.ridgePath(ridge, drop: drop, half: half, bottom: bottom)
            placeProps(d, shift: shift, ridge: ridge, scale: scale, half: half)
        }
    }

    /// The ridge as a filled shape across the box, dropped by `drop` points.
    private static func ridgePath(
        _ ridge: (CGFloat) -> CGFloat, drop: CGFloat, half: CGFloat, bottom: CGFloat
    ) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -half - 10, y: bottom))
        var px = -half - 10
        while px <= half + 10 {
            path.addLine(to: CGPoint(x: px, y: ridge(px) - drop))
            px += 8
        }
        path.addLine(to: CGPoint(x: px - 8, y: bottom))
        path.closeSubpath()
        return path
    }

    /// Props rooted a little into the ridge at their lap nearest the box.
    private func placeProps(
        _ d: Drawn, shift: Double, ridge: (CGFloat) -> CGFloat, scale: CGFloat, half: CGFloat
    ) {
        let period = CGFloat(d.layer.period) * scale
        for (node, prop) in zip(d.props, d.layer.props) {
            var x = CGFloat(d.layer.wrap(prop.x - shift)) * scale
            if x > half + 200 { x -= period }
            node.isHidden = x < -half - 200
            if !node.isHidden { node.position = CGPoint(x: x, y: ridge(x) - 3) }
        }
    }

    private static func kind(_ kind: BackdropProp.Kind) -> PropArt.Kind {
        switch kind {
        case .house: return .house
        case .church: return .church
        case .mill: return .mill
        case .tree: return .tree
        case .poplar: return .poplar
        }
    }
}
