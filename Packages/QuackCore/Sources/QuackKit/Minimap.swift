import QuackCore
import SpriteKit

/// The whole world shrunk into a small box under the status line: the strip
/// squeezed far harder side to side than up and down, so height still reads.
/// The ground runs along the bottom with the fields on it, each balloon still
/// up is a dot at its height, and the plane is a marker pointing the way it
/// flies. The box's left and right edges are the same place.
final class Minimap: SKNode {
    /// Metres of height the box shows; a plane above it rides the top edge.
    static let heightShown: Double = 150

    private let size: CGSize
    private var fieldMarks: [SKShapeNode] = []
    private var balloonDots: [SKShapeNode] = []
    private let planeMark = SKShapeNode()
    private let ink = SKColor(white: 0.12, alpha: 1)

    init(size: CGSize) {
        self.size = size
        super.init()
        let frame = SKShapeNode(
            rect: CGRect(x: -size.width / 2, y: 0, width: size.width, height: size.height),
            cornerRadius: 3)
        frame.fillColor = SKColor(white: 1, alpha: 0.28)
        frame.strokeColor = ink.withAlphaComponent(0.5)
        frame.lineWidth = 1.5
        addChild(frame)
        let ground = SKShapeNode(
            rect: CGRect(x: -size.width / 2, y: 0, width: size.width, height: 2))
        ground.fillColor = SKColor(red: 0.25, green: 0.45, blue: 0.2, alpha: 1)
        ground.strokeColor = .clear
        ground.zPosition = 1
        addChild(ground)
        let tri = CGMutablePath()
        tri.addLines(between: [CGPoint(x: 6, y: 0), CGPoint(x: -4, y: 4), CGPoint(x: -4, y: -4)])
        tri.closeSubpath()
        planeMark.path = tri
        planeMark.fillColor = .white
        planeMark.strokeColor = ink
        planeMark.lineWidth = 1.2
        planeMark.zPosition = 3
        addChild(planeMark)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Rebuild the marks for a new run: its fields, and a dot per balloon in its colour.
    func reset(strip: Strip, balloonColours: [SKColor]) {
        fieldMarks.forEach { $0.removeFromParent() }
        fieldMarks = strip.airfields.map { field in
            let w = max(4, CGFloat(field.length / strip.length) * size.width)
            let mark = SKShapeNode(rect: CGRect(x: -w / 2, y: 0, width: w, height: 3))
            mark.fillColor = SKColor(red: 0.78, green: 0.68, blue: 0.48, alpha: 1)
            mark.strokeColor = ink
            mark.lineWidth = 0.8
            mark.zPosition = 2
            addChild(mark)
            return mark
        }
        balloonDots.forEach { $0.removeFromParent() }
        balloonDots = balloonColours.map { colour in
            let dot = SKShapeNode(circleOfRadius: 2.2)
            dot.fillColor = colour
            dot.strokeColor = ink.withAlphaComponent(0.6)
            dot.lineWidth = 0.6
            dot.zPosition = 2
            addChild(dot)
            return dot
        }
    }

    func update(_ practice: Practice) {
        let strip = practice.model.strip
        let gear = practice.model.landing.gearHeight
        let across = { (x: Double) -> CGFloat in
            (CGFloat(strip.wrap(x) / strip.length) - 0.5) * self.size.width
        }
        let up = { (height: Double) -> CGFloat in
            CGFloat(min(1, max(0, height / Minimap.heightShown))) * (self.size.height - 4) + 2
        }
        for (mark, field) in zip(fieldMarks, strip.airfields) {
            mark.position = CGPoint(x: across(field.start + field.length / 2), y: 1)
        }
        for (dot, balloon) in zip(balloonDots, practice.balloons) {
            dot.isHidden = balloon.popped
            dot.position = CGPoint(x: across(balloon.x), y: up(balloon.y))
        }
        let plane = practice.plane
        planeMark.position = CGPoint(x: across(plane.x), y: up(plane.y - gear))
        // Pointing the way the plane flies, as it would look in the squeezed box.
        let sx = size.width / CGFloat(strip.length)
        let sy = (size.height - 4) / CGFloat(Minimap.heightShown)
        planeMark.zRotation = atan2(
            CGFloat(sin(plane.heading)) * sy, CGFloat(cos(plane.heading)) * sx)
    }
}
