import QuackCore
import SpriteKit
import SwiftUI

/// A ground line, a plane, two thumbs. Everything the sim needs comes through
/// `PlaneInput`; this scene only draws the state and turns touches and keys
/// into that input. Simulation runs at the model's fixed timestep, decoupled
/// from the frame rate, so feel does not change with the display.
public final class FlightScene: SKScene {
    private let model = FlightModel()
    private var plane = PlaneState(x: 0, y: 60, heading: 0, speed: 40)
    private var input = PlaneInput.idle
    private var accumulator: TimeInterval = 0
    private var lastTime: TimeInterval?

    private let world = SKNode()
    private let planeNode = SKShapeNode()
    private let groundNode = SKShapeNode()
    private let controls = ThumbControls()

    /// Points per metre.
    private let scale: CGFloat = 6

    public override init() {
        super.init(size: CGSize(width: 800, height: 450))
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.55, green: 0.72, blue: 0.9, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.3)
        addChild(world)
        world.addChild(groundNode)
        world.addChild(planeNode)
        planeNode.path = FlightScene.planePath()
        planeNode.strokeColor = SKColor(white: 0.12, alpha: 1)
        planeNode.lineWidth = 2
        planeNode.lineJoin = .round
        groundNode.strokeColor = SKColor(red: 0.25, green: 0.45, blue: 0.2, alpha: 1)
        groundNode.lineWidth = 3
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    public override func didMove(to view: SKView) {
        redrawGround()
    }

    public override func update(_ currentTime: TimeInterval) {
        defer { lastTime = currentTime }
        guard let last = lastTime else { return }
        accumulator += min(currentTime - last, 0.25)
        input = controls.input
        while accumulator >= FlightModel.dt {
            plane = model.advance(plane, input: input)
            accumulator -= FlightModel.dt
        }
        if plane.y < 0 {
            // Milestone 1 has no landing yet: the ground is a floor, and touching
            // it resets the flight so the feel loop stays short.
            plane = PlaneState(x: plane.x, y: 60, heading: 0, speed: 40)
        }
        render()
    }

    private func render() {
        planeNode.position = CGPoint(x: plane.x * scale, y: plane.y * scale)
        planeNode.zRotation = CGFloat(plane.heading)
        planeNode.yScale = plane.inverted ? -1 : 1
        world.position = CGPoint(x: -planeNode.position.x, y: 0)
        redrawGround()
    }

    private func redrawGround() {
        let half = size.width
        let x0 = planeNode.position.x - half
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x0, y: 0))
        path.addLine(to: CGPoint(x: x0 + 2 * half, y: 0))
        // Tick marks so motion over the ground is readable.
        let step: CGFloat = 20 * scale
        var x = (x0 / step).rounded(.down) * step
        while x < x0 + 2 * half {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: -8))
            x += step
        }
        groundNode.path = path
    }

    /// Side view of a biplane in a few strokes: fuselage, two wings, tail, prop.
    private static func planePath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -14, y: 0))
        p.addLine(to: CGPoint(x: 14, y: 0))
        p.move(to: CGPoint(x: -4, y: 6))
        p.addLine(to: CGPoint(x: 6, y: 6))
        p.move(to: CGPoint(x: -4, y: -5))
        p.addLine(to: CGPoint(x: 6, y: -5))
        p.move(to: CGPoint(x: -2, y: 6))
        p.addLine(to: CGPoint(x: -2, y: -5))
        p.move(to: CGPoint(x: 4, y: 6))
        p.addLine(to: CGPoint(x: 4, y: -5))
        p.move(to: CGPoint(x: -14, y: 0))
        p.addLine(to: CGPoint(x: -14, y: 6))
        p.move(to: CGPoint(x: 14, y: -4))
        p.addLine(to: CGPoint(x: 14, y: 4))
        return p
    }

    // MARK: Input

    #if os(iOS)
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { controls.began(t, in: self) }
    }
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { controls.moved(t, in: self) }
    }
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { controls.ended(t) }
    }
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { controls.ended(t) }
    }
    #endif

    #if os(macOS)
    /// Keyboard stands in for the two thumbs: ↑/↓ elevator, space power.
    public func keyboard(_ press: KeyPress) {
        controls.keyboard(press)
    }
    #endif
}
