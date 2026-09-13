import SpriteKit

/// A cockpit gauge: a ring of ticks and a needle that sweeps 270° clockwise
/// from the lower left, with an optional red arc for the range to stay out of.
final class Dial: SKNode {
    private let needle = SKShapeNode()
    private let maximum: CGFloat
    private let sweep: CGFloat = 1.5 * .pi
    private let start: CGFloat = -1.25 * .pi

    var value: CGFloat = 0 {
        didSet { needle.zRotation = angle(value) }
    }

    /// `redBelow` marks 0…value in red; `majorEvery` places the long ticks.
    init(radius: CGFloat, maximum: CGFloat, majorEvery: CGFloat, redBelow: CGFloat? = nil) {
        self.maximum = maximum
        super.init()
        let ink = SKColor(white: 0.12, alpha: 1)
        let face = SKShapeNode(circleOfRadius: radius)
        face.fillColor = SKColor(white: 1, alpha: 0.55)
        face.strokeColor = ink
        face.lineWidth = radius * 0.06
        addChild(face)
        if let red = redBelow {
            let p = CGMutablePath()
            p.addArc(
                center: .zero, radius: radius * 0.8, startAngle: angle(0), endAngle: angle(red),
                clockwise: true)
            let arc = SKShapeNode(path: p)
            arc.strokeColor = SKColor(red: 0.8, green: 0.15, blue: 0.15, alpha: 0.9)
            arc.lineWidth = radius * 0.12
            addChild(arc)
        }
        let ticks = CGMutablePath()
        var v: CGFloat = 0
        var i = 0
        while v <= maximum + 0.001 {
            let a = angle(v)
            let inner = radius * (i.isMultiple(of: 2) ? 0.68 : 0.8)
            ticks.move(to: CGPoint(x: cos(a) * inner, y: sin(a) * inner))
            ticks.addLine(to: CGPoint(x: cos(a) * radius * 0.9, y: sin(a) * radius * 0.9))
            v += majorEvery / 2
            i += 1
        }
        let tickNode = SKShapeNode(path: ticks)
        tickNode.strokeColor = ink
        tickNode.lineWidth = radius * 0.05
        addChild(tickNode)
        let np = CGMutablePath()
        np.addLines(between: [
            CGPoint(x: -radius * 0.18, y: 0), CGPoint(x: 0, y: radius * 0.07),
            CGPoint(x: radius * 0.85, y: 0),
            CGPoint(x: 0, y: -radius * 0.07),
        ])
        np.closeSubpath()
        needle.path = np
        needle.fillColor = ink
        needle.strokeColor = .clear
        addChild(needle)
        let hub = SKShapeNode(circleOfRadius: radius * 0.09)
        hub.fillColor = ink
        hub.strokeColor = .clear
        addChild(hub)
        needle.zRotation = angle(0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Needle angle for a value: clockwise from the lower left, clamped to the dial.
    private func angle(_ v: CGFloat) -> CGFloat {
        start - min(max(0, v), maximum) / maximum * sweep
    }
}
