import QuackCore
import SpriteKit

/// The whole world shrunk into a small box under the status line: the strip
/// squeezed far harder side to side than up and down, so height still reads.
/// The hills fill the bottom with the fields on their shelves, each balloon
/// still up is a dot at its height, and the plane is a marker pointing the way
/// it flies. The box is as tall as the ceiling. Its left and right edges are
/// the same place.
final class Minimap: SKNode {
    private let size: CGSize
    private let terrain = SKShapeNode()
    /// What the terrain was last drawn for: the strip and the height shown.
    private var drawn: (strip: Strip, height: Double)?
    private var fieldMarks: [SKShapeNode] = []
    private var balloonDots: [SKShapeNode] = []
    private let planeMark = SKShapeNode()
    private let ink = SKColor(white: 0.12, alpha: 1)
    private static let fieldTan = SKColor(red: 0.78, green: 0.68, blue: 0.48, alpha: 1)

    init(size: CGSize) {
        self.size = size
        super.init()
        let frame = SKShapeNode(
            rect: CGRect(x: -size.width / 2, y: 0, width: size.width, height: size.height),
            cornerRadius: 3)
        // Opaque, so no star or cloud behind it passes for a balloon.
        frame.fillColor = SKColor(red: 0.62, green: 0.78, blue: 0.92, alpha: 1)
        frame.strokeColor = ink.withAlphaComponent(0.7)
        frame.lineWidth = 2
        addChild(frame)
        terrain.fillColor = SKColor(red: 0.22, green: 0.42, blue: 0.18, alpha: 1)
        terrain.strokeColor = .clear
        terrain.zPosition = 1
        addChild(terrain)
        let tri = CGMutablePath()
        tri.addLines(between: [CGPoint(x: 9, y: 0), CGPoint(x: -6, y: 6), CGPoint(x: -6, y: -6)])
        tri.closeSubpath()
        planeMark.path = tri
        planeMark.fillColor = .white
        planeMark.strokeColor = ink
        planeMark.lineWidth = 1.8
        planeMark.zPosition = 3
        addChild(planeMark)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Rebuild the marks for a new run: its fields, and a dot per balloon in its colour.
    func reset(strip: Strip, balloonColours: [SKColor]) {
        drawn = nil
        fieldMarks.forEach { $0.removeFromParent() }
        fieldMarks = strip.airfields.map { field in
            let w = max(8, CGFloat(field.length / strip.length) * size.width)
            let mark = SKShapeNode(rect: CGRect(x: -w / 2, y: -2.5, width: w, height: 5))
            mark.fillColor = Minimap.fieldTan
            mark.strokeColor = ink
            mark.lineWidth = 1.2
            mark.zPosition = 2
            addChild(mark)
            return mark
        }
        balloonDots.forEach { $0.removeFromParent() }
        balloonDots = balloonColours.map { colour in
            let dot = SKShapeNode(circleOfRadius: 3.5)
            dot.fillColor = colour
            dot.strokeColor = SKColor(white: 1, alpha: 0.9)
            dot.lineWidth = 1.2
            dot.zPosition = 2
            addChild(dot)
            return dot
        }
    }

    func update(_ practice: Practice, seat: Int = 0) {
        let strip = practice.model.strip
        let gear = practice.model.landing.gearHeight
        let across = { (x: Double) -> CGFloat in
            (CGFloat(strip.wrap(x) / strip.length) - 0.5) * self.size.width
        }
        let shown = practice.model.flight.tuning.ceiling
        let up = { (height: Double) -> CGFloat in
            CGFloat(min(1, max(0, height / shown))) * (self.size.height - 4) + 2
        }
        if drawn?.strip != strip || drawn?.height != shown {
            drawTerrain(strip, up: up)
            drawn = (strip, shown)
        }
        for (i, (mark, field)) in zip(fieldMarks, strip.airfields).enumerated() {
            mark.position = CGPoint(
                x: across(field.start + field.length / 2), y: up(field.elevation))
            // The destination's mark is lit red: the job aboard, or the one being picked.
            let isDestination = (practice.contract ?? practice.chosen)?.to == i
            mark.fillColor =
                isDestination
                ? SKColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1) : Minimap.fieldTan
            mark.setScale(isDestination ? 1.6 : 1)
        }
        for (dot, balloon) in zip(balloonDots, practice.balloons) {
            dot.isHidden = balloon.popped
            dot.position = CGPoint(x: across(balloon.x), y: up(balloon.y))
        }
        let plane = practice.pilots[min(seat, practice.pilots.count - 1)].plane
        planeMark.position = CGPoint(x: across(plane.x), y: up(plane.y - gear))
        // Pointing the way the plane flies, as it would look in the squeezed box.
        let sx = size.width / CGFloat(strip.length)
        let sy = (size.height - 4) / CGFloat(shown)
        planeMark.zRotation = atan2(
            CGFloat(sin(plane.heading)) * sy, CGFloat(cos(plane.heading)) * sx)
    }

    /// The hills as a filled silhouette, a sample per point across the box.
    private func drawTerrain(_ strip: Strip, up: (Double) -> CGFloat) {
        let path = CGMutablePath()
        let left = -size.width / 2
        path.move(to: CGPoint(x: left, y: 0))
        for i in 0...Int(size.width) {
            let x = Double(i) / Double(size.width) * strip.length
            path.addLine(to: CGPoint(x: left + CGFloat(i), y: up(strip.groundHeight(at: x))))
        }
        path.addLine(to: CGPoint(x: -left, y: 0))
        path.closeSubpath()
        terrain.path = path
    }
}
