import SpriteKit

/// A row of little icons that counts something: one per item, the ones still
/// there in colour and the rest faded. Balloons left, rounds in the belt.
final class Tally: SKNode {
    enum Icon {
        case balloon
        case round
    }

    private let icon: Icon
    private let pitch: CGFloat
    private var marks: [SKShapeNode] = []
    private var colours: [SKColor] = []

    init(icon: Icon, pitch: CGFloat) {
        self.icon = icon
        self.pitch = pitch
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// One mark per item, each in its colour, laid out left to right from the origin.
    func reset(colours: [SKColor]) {
        marks.forEach { $0.removeFromParent() }
        self.colours = colours
        marks = colours.enumerated().map { i, colour in
            let mark = SKShapeNode(path: Tally.path(icon))
            mark.fillColor = colour
            mark.strokeColor = SKColor(white: 0.12, alpha: 1)
            mark.lineWidth = 1
            mark.position = CGPoint(x: CGFloat(i) * pitch, y: 0)
            addChild(mark)
            return mark
        }
    }

    /// Which items are still there.
    func update(present: [Bool]) {
        for (mark, (colour, here)) in zip(marks, zip(colours, present)) {
            mark.fillColor = here ? colour : SKColor(white: 1, alpha: 0.18)
            mark.strokeColor = SKColor(white: 0.12, alpha: here ? 1 : 0.35)
        }
    }

    /// The first `count` items are there, the rest gone.
    func update(count: Int) {
        update(present: marks.indices.map { $0 < count })
    }

    private static func path(_ icon: Icon) -> CGPath {
        let p = CGMutablePath()
        switch icon {
        case .balloon:
            p.addEllipse(in: CGRect(x: -5, y: -4, width: 10, height: 12))
            p.move(to: CGPoint(x: -1.5, y: -5.5))
            p.addLine(to: CGPoint(x: 1.5, y: -5.5))
            p.addLine(to: CGPoint(x: 0, y: -3.5))
            p.closeSubpath()
        case .round:
            p.addRoundedRect(
                in: CGRect(x: -2, y: -6, width: 4, height: 12), cornerWidth: 2, cornerHeight: 2)
        }
        return p
    }
}
