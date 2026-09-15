import QuackCore
import SpriteKit

/// How the world looks for a run's hour, and the parts of it the scene places:
/// the sky and backdrop behind the box, and on the strip the ground in two
/// tones, the houses and trees standing on it, and a hangar by each field.
/// Built again when the run, its hour or its scenery changes.
final class StripLook {
    let sky = SkyNode()
    let backdrop = BackdropNode()
    /// World-space: scenery and hangars, drawn behind the ground's edge.
    let scenery = SKNode()
    let ground = SKShapeNode()
    let groundShade = SKShapeNode()
    /// World-space, in front of the plane: the clouds at its depth.
    let clouds = SKNode()
    private var cloudNodes: [SKNode] = []
    private(set) var palette = Palette(.noon)
    private var built: (seed: UInt64, hour: TimeOfDay)?
    private var builtScenery: [Obstacle] = []
    private var sceneryNodes: [SKNode] = []
    private var hangarNodes: [SKNode] = []

    init() {
        clouds.alpha = 0.62
        // Over the plane, whose parts stack their own z positions.
        clouds.zPosition = 40
        sky.zPosition = -30
        backdrop.zPosition = -20
        for shape in [ground, groundShade] {
            shape.strokeColor = .clear
        }
    }

    /// Whether building for this run and hour would change anything.
    func needsBuild(_ practice: Practice, hour: TimeOfDay) -> Bool {
        built?.seed != practice.seed || built?.hour != hour
            || builtScenery != practice.model.strip.scenery
            || hangarNodes.count != practice.model.strip.airfields.count
    }

    func build(_ practice: Practice, hour: TimeOfDay, scale: CGFloat, box: CGSize) {
        let strip = practice.model.strip
        palette = Palette(hour)
        built = (practice.seed, hour)
        builtScenery = strip.scenery
        sky.build(palette, box: box, stripPoints: CGFloat(strip.length) * scale)
        backdrop.build(
            Backdrop.generate(seed: practice.seed, stripLength: strip.length), palette: palette,
            scale: scale)
        ground.fillColor = palette.lit(Palette.Base.ground).lighter(0.12).color()
        groundShade.fillColor = palette.lit(Palette.Base.ground).darker(0.04).color()
        scenery.removeAllChildren()
        let paint = PropArt.Paint(palette: palette, layer: 3)
        hangarNodes = strip.airfields.map { _ in
            let n = PropArt.node(.hangar, s: scale, paint: paint)
            scenery.addChild(n)
            return n
        }
        clouds.removeAllChildren()
        let cloudColour = RGB.white.mix(palette.sky[2], 0.25)
            .mix(palette.tint, palette.tintAmount * 0.9).color()
        cloudNodes = practice.clouds.map { cloud in
            let n = StripLook.cloud(width: CGFloat(cloud.width) * scale, colour: cloudColour)
            clouds.addChild(n)
            return n
        }
        sceneryNodes = strip.scenery.map { o in
            let n = PropArt.node(StripLook.kind(o.kind), s: scale, size: o.size, paint: paint)
            scenery.addChild(n)
            return n
        }
    }

    /// Place everything for the plane at `plane` (points along the world) and
    /// the camera at `cameraY`.
    func update(
        _ practice: Practice, planePoints: CGPoint, cameraY: CGFloat, scale: CGFloat, box: CGSize
    ) {
        let strip = practice.model.strip
        let planeX = practice.plane.x
        sky.update(
            planePoints: planePoints.x, driftPoints: CGFloat(practice.airDrift) * scale,
            cameraY: cameraY, boxWidth: box.width)
        backdrop.update(planeX: planeX, cameraY: cameraY, scale: scale, box: box)
        let near = { (x: Double) -> CGFloat in
            CGFloat(planeX + strip.offset(from: planeX, to: x)) * scale
        }
        let reach = Double(box.width / scale)
        for (node, o) in zip(sceneryNodes, strip.scenery) {
            node.isHidden = abs(strip.offset(from: planeX, to: o.x)) > reach
            node.position = CGPoint(
                x: near(o.x), y: CGFloat(strip.groundHeight(at: o.x)) * scale - 4)
        }
        for (node, cloud) in zip(cloudNodes, practice.clouds) {
            node.isHidden = abs(strip.offset(from: planeX, to: cloud.x)) > reach + cloud.width
            node.position = CGPoint(x: near(cloud.x), y: CGFloat(cloud.y) * scale)
        }
        for (node, field) in zip(hangarNodes, strip.airfields) {
            // Behind the field, left of the windsock: a plane on the field
            // passes in front of it. Scenery, not solid.
            let x = field.start + min(16, field.length / 2 - 12)
            node.isHidden = abs(strip.offset(from: planeX, to: x)) > reach
            node.position = CGPoint(x: near(x), y: CGFloat(field.elevation) * scale)
        }
        redrawGround(strip, planePoints: planePoints, cameraY: cameraY, scale: scale, box: box)
    }

    /// The ground a screen either side of the plane, sampled every two metres:
    /// a lit band along the surface over a shaded body.
    private func redrawGround(
        _ strip: Strip, planePoints: CGPoint, cameraY: CGFloat, scale: CGFloat, box: CGSize
    ) {
        let half = box.width
        let x0 = planePoints.x - half
        let bottom = cameraY - box.height
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x0, y: bottom))
        let step: CGFloat = 2 * scale
        var x = (x0 / step).rounded(.down) * step
        while x <= x0 + 2 * half + step {
            path.addLine(
                to: CGPoint(x: x, y: CGFloat(strip.groundHeight(at: Double(x / scale))) * scale))
            x += step
        }
        path.addLine(to: CGPoint(x: x - step, y: bottom))
        path.closeSubpath()
        ground.path = path
        var down = CGAffineTransform(translationX: 0, y: -12)
        groundShade.path = path.copy(using: &down)
    }

    /// A cloud as one flat shape, so its translucency is even: a poster
    /// cumulus, three lozenges heaped up from a wide base, cut flat underneath.
    private static func cloud(width: CGFloat, colour: SKColor) -> SKNode {
        let lozenges = [
            CGRect(x: -width / 2, y: -width * 0.09, width: width, height: width * 0.18),
            CGRect(x: -width * 0.3, y: 0, width: width * 0.66, height: width * 0.24),
            CGRect(x: -width * 0.28, y: width * 0.08, width: width * 0.36, height: width * 0.2),
        ]
        let floor = -width * 0.05
        var tops: [CGPoint] = []
        var bottoms: [CGPoint] = []
        for i in 0...64 {
            let x = -width / 2 + width * CGFloat(i) / 64
            var top = -CGFloat.infinity
            var bottom = CGFloat.infinity
            for r in lozenges where x >= r.minX && x <= r.maxX {
                let u = (x - r.midX) / (r.width / 2)
                let half = r.height / 2 * sqrt(max(0, 1 - u * u))
                top = max(top, r.midY + half)
                bottom = min(bottom, r.midY - half)
            }
            guard top > floor else { continue }
            tops.append(CGPoint(x: x, y: top))
            bottoms.append(CGPoint(x: x, y: max(bottom, floor)))
        }
        let path = CGMutablePath()
        path.addLines(between: tops + bottoms.reversed())
        path.closeSubpath()
        let n = SKShapeNode(path: path)
        n.fillColor = colour
        n.strokeColor = .clear
        return n
    }

    private static func kind(_ kind: Obstacle.Kind) -> PropArt.Kind {
        switch kind {
        case .house: return .house
        case .tree: return .tree
        case .pine: return .pine
        }
    }
}
