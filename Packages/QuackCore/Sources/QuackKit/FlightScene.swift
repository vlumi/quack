import QuackCore
import SpriteKit
import SwiftUI

/// The balloon run on screen: a ground line, the plane, the balloons, the
/// rounds in the air and a clock. Everything the sim needs comes through
/// `PlaneInput`; this scene only draws the state and turns touches and keys
/// into that input. Simulation runs at the model's fixed timestep, decoupled
/// from the frame rate, so feel does not change with the display.
public final class FlightScene: SKScene {
    private var practice = Practice(seed: 1)
    private var run: UInt64 = 1
    private var input = PlaneInput.idle
    private var accumulator: TimeInterval = 0
    private var lastTime: TimeInterval?

    private let world = SKNode()
    private let planeNode: PlaneNode
    private let groundNode = SKShapeNode()
    private let balloonLayer = SKNode()
    private let bulletLayer = SKNode()
    private var balloonNodes: [SKNode] = []
    private var bulletNodes: [SKShapeNode] = []
    private let countLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let clockLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let controls = ThumbControls()
    private var cameraY: CGFloat = 0
    private var wasFiring = false

    /// The roll shown, 0 upright to 1 inverted, chasing the sim's `inverted`.
    private var rollShown: CGFloat = 0
    private var rollFrom: CGFloat = 0
    private var rollStart: TimeInterval?
    /// How long the plane takes to roll when it rights itself.
    private let rollDuration: TimeInterval = 0.35

    /// Points per metre.
    private let scale: CGFloat = 6
    /// Where the sun is, for the gloss: up and a little ahead.
    private let sun = CGVector(dx: 0.33, dy: 0.94)
    private static let balloonColours: [SKColor] = [
        SKColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1),
        SKColor(red: 0.95, green: 0.72, blue: 0.02, alpha: 1),
        SKColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 1),
        SKColor(red: 0.3, green: 0.65, blue: 0.3, alpha: 1),
        SKColor(red: 0.9, green: 0.45, blue: 0.15, alpha: 1),
        SKColor(red: 0.6, green: 0.3, blue: 0.7, alpha: 1),
    ]

    public override init() {
        planeNode = PlaneNode(livery: .courier, pointsPerMetre: scale)
        super.init(size: CGSize(width: 800, height: 450))
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.55, green: 0.72, blue: 0.9, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.3)
        addChild(world)
        world.addChild(groundNode)
        world.addChild(balloonLayer)
        world.addChild(bulletLayer)
        world.addChild(planeNode)
        groundNode.strokeColor = SKColor(red: 0.25, green: 0.45, blue: 0.2, alpha: 1)
        groundNode.lineWidth = 3
        for label in [countLabel, clockLabel] {
            label.fontSize = 22
            label.fontColor = SKColor(white: 0.12, alpha: 1)
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.zPosition = 100
            addChild(label)
        }
        startRun()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    public override func didMove(to view: SKView) {
        layoutHUD()
        redrawGround()
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        layoutHUD()
    }

    private func startRun() {
        practice = Practice(seed: run)
        balloonNodes.forEach { $0.removeFromParent() }
        balloonNodes = practice.balloons.enumerated().map { i, b in
            let n = FlightScene.balloonNode(
                radius: CGFloat(b.radius) * scale, colour: FlightScene.balloonColours[i % 6])
            n.position = CGPoint(x: b.x * scale, y: b.y * scale)
            balloonLayer.addChild(n)
            return n
        }
        rollShown = 0
        rollStart = nil
        planeNode.roll = 0
    }

    public override func update(_ currentTime: TimeInterval) {
        defer { lastTime = currentTime }
        guard let last = lastTime else { return }
        accumulator += min(currentTime - last, 0.25)
        input = controls.input
        // Once the run is done, the next pull of the trigger starts the next one.
        if practice.isFinished && input.fire && !wasFiring {
            run += 1
            startRun()
        }
        wasFiring = input.fire
        while accumulator >= FlightModel.dt {
            practice.advance(input: input)
            accumulator -= FlightModel.dt
        }
        if practice.plane.y < 0 {
            // Milestone 1 has no landing yet: the ground is a floor, and touching
            // it resets the flight so the feel loop stays short.
            practice.resetPlane()
        }
        render(at: currentTime)
    }

    private func render(at now: TimeInterval) {
        let plane = practice.plane
        planeNode.position = CGPoint(x: plane.x * scale, y: plane.y * scale)
        planeNode.zRotation = CGFloat(plane.heading)

        // The sim flips instantly; the drawing rolls, top toward the camera,
        // with a little easing, and rolls back the same way in reverse.
        let target: CGFloat = plane.inverted ? 1 : 0
        if rollShown != target && rollStart == nil {
            rollStart = now
            rollFrom = rollShown
        }
        if let start = rollStart {
            let t = min(1, (now - start) / rollDuration)
            let eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            rollShown = rollFrom + (target - rollFrom) * CGFloat(eased)
            if t >= 1 {
                rollShown = target
                rollStart = nil
            }
        }
        planeNode.roll = rollShown * .pi

        // Gloss: the top surface catches the sun in proportion to how squarely
        // it faces it, so it sweeps during a loop and vanishes inverted.
        let up = CGVector(dx: -sin(plane.heading), dy: cos(plane.heading))
        let facing = (up.dx * sun.dx + up.dy * sun.dy) * (plane.inverted ? -1 : 1)
        planeNode.gloss.alpha = max(0, facing) * max(0, facing) * pow(cos(planeNode.roll), 2)

        // Balloons that popped this frame burst; rounds are re-laid each frame.
        for (i, b) in practice.balloons.enumerated() where b.popped && balloonNodes[i].parent != nil
        {
            FlightScene.burst(balloonNodes[i])
        }
        while bulletNodes.count < practice.bullets.count {
            let n = SKShapeNode(rect: CGRect(x: -0.6 * scale, y: -1, width: 1.2 * scale, height: 2))
            n.fillColor = SKColor(red: 1, green: 0.93, blue: 0.6, alpha: 1)
            n.strokeColor = .clear
            bulletLayer.addChild(n)
            bulletNodes.append(n)
        }
        for (i, n) in bulletNodes.enumerated() {
            if i < practice.bullets.count {
                let b = practice.bullets[i]
                n.isHidden = false
                n.position = CGPoint(x: b.x * scale, y: b.y * scale)
                n.zRotation = atan2(b.vy, b.vx)
            } else {
                n.isHidden = true
            }
        }

        // Camera: follows sideways always, and upward once the plane would leave
        // the top 40% of the view, easing so a loop does not yank the ground.
        let target2 = max(0, planeNode.position.y - size.height * 0.4)
        cameraY += (target2 - cameraY) * 0.12
        world.position = CGPoint(x: -planeNode.position.x, y: -cameraY)
        redrawGround()
        updateHUD()
    }

    // MARK: HUD

    private func layoutHUD() {
        let left = -size.width / 2 + 16
        let top = size.height * 0.7 - 16
        countLabel.position = CGPoint(x: left, y: top)
        clockLabel.position = CGPoint(x: left, y: top - 30)
    }

    private func updateHUD() {
        let seconds = practice.elapsed.formatted(.number.precision(.fractionLength(1)))
        if practice.isFinished {
            countLabel.text = String(
                localized: "All popped in \(seconds) s. Fire to go again.", bundle: .module)
            clockLabel.text = ""
        } else {
            countLabel.text = String(
                localized: "\(practice.remaining) balloons left", bundle: .module)
            clockLabel.text = String(localized: "\(seconds) s", bundle: .module)
        }
    }

    // MARK: Balloons

    private static func balloonNode(radius r: CGFloat, colour: SKColor) -> SKNode {
        let n = SKNode()
        let body = SKShapeNode(
            ellipseIn: CGRect(x: -r, y: -r * 1.15, width: 2 * r, height: 2.3 * r))
        body.fillColor = colour
        body.strokeColor = SKColor(white: 0.12, alpha: 1)
        body.lineWidth = 2
        let knot = SKShapeNode(
            path: {
                let p = CGMutablePath()
                p.addLines(between: [
                    CGPoint(x: -r * 0.2, y: -r * 1.35), CGPoint(x: r * 0.2, y: -r * 1.35),
                    CGPoint(x: 0, y: -r * 1.1),
                ])
                p.closeSubpath()
                return p
            }())
        knot.fillColor = colour
        knot.strokeColor = SKColor(white: 0.12, alpha: 1)
        knot.lineWidth = 1.5
        let string = SKShapeNode(
            path: {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 0, y: -r * 1.35))
                p.addQuadCurve(
                    to: CGPoint(x: r * 0.3, y: -r * 3), control: CGPoint(x: -r * 0.5, y: -r * 2.2))
                return p
            }())
        string.strokeColor = SKColor(white: 0.12, alpha: 0.8)
        string.lineWidth = 1.5
        let shine = SKShapeNode(
            ellipseIn: CGRect(x: -r * 0.55, y: r * 0.25, width: r * 0.35, height: r * 0.5))
        shine.fillColor = SKColor(white: 1, alpha: 0.5)
        shine.strokeColor = .clear
        for c in [string, body, knot, shine] { n.addChild(c) }
        return n
    }

    private static func burst(_ n: SKNode) {
        n.run(
            .sequence([
                .group([.scale(to: 1.5, duration: 0.12), .fadeOut(withDuration: 0.12)]),
                .removeFromParent(),
            ]))
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
    /// Keyboard stands in for the thumbs: ↓ nose up, ↑ nose down, space fires.
    public func keyboard(_ press: KeyPress) {
        controls.keyboard(press)
    }
    #endif
}
