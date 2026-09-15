import QuackCore
import SpriteKit

/// The whole strip, very small: a line with the fields on it, a dot for each
/// balloon still up and a marker for the plane, so the pilot always knows
/// where they are on a world wider than the screen. The line's two ends are
/// the same place.
final class Minimap: SKNode {
    private let width: CGFloat
    private let line = SKShapeNode()
    private var fieldMarks: [SKShapeNode] = []
    private var balloonDots: [SKShapeNode] = []
    private let planeMark = SKShapeNode()
    private let ink = SKColor(white: 0.12, alpha: 1)

    init(width: CGFloat) {
        self.width = width
        super.init()
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -width / 2, y: 0))
        p.addLine(to: CGPoint(x: width / 2, y: 0))
        line.path = p
        line.strokeColor = ink.withAlphaComponent(0.55)
        line.lineWidth = 2
        addChild(line)
        let tri = CGMutablePath()
        tri.addLines(between: [CGPoint(x: 6, y: 0), CGPoint(x: -4, y: 5), CGPoint(x: -4, y: -5)])
        tri.closeSubpath()
        planeMark.path = tri
        planeMark.fillColor = .white
        planeMark.strokeColor = ink
        planeMark.lineWidth = 1.5
        planeMark.zPosition = 2
        addChild(planeMark)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Rebuild the marks for a new run: its fields, and a dot per balloon in its colour.
    func reset(strip: Strip, balloonColours: [SKColor]) {
        fieldMarks.forEach { $0.removeFromParent() }
        fieldMarks = strip.airfields.map { field in
            let mark = SKShapeNode(
                rectOf: CGSize(
                    width: max(3, CGFloat(field.length / strip.length) * width), height: 6))
            mark.fillColor = SKColor(red: 0.78, green: 0.68, blue: 0.48, alpha: 1)
            mark.strokeColor = ink
            mark.lineWidth = 1
            mark.zPosition = 1
            addChild(mark)
            return mark
        }
        balloonDots.forEach { $0.removeFromParent() }
        balloonDots = balloonColours.map { colour in
            let dot = SKShapeNode(circleOfRadius: 2.5)
            dot.fillColor = colour
            dot.strokeColor = .clear
            dot.zPosition = 1
            addChild(dot)
            return dot
        }
    }

    func update(_ practice: Practice) {
        let strip = practice.model.strip
        let along = { (x: Double) -> CGFloat in
            (CGFloat(strip.wrap(x) / strip.length) - 0.5) * self.width
        }
        for (mark, field) in zip(fieldMarks, strip.airfields) {
            mark.position = CGPoint(x: along(field.start + field.length / 2), y: 0)
        }
        for (dot, balloon) in zip(balloonDots, practice.balloons) {
            dot.isHidden = balloon.popped
            dot.position = CGPoint(x: along(balloon.x), y: 7)
        }
        planeMark.position = CGPoint(x: along(practice.plane.x), y: -8)
        planeMark.xScale = CGFloat(practice.plane.direction)
    }
}
