import QuackCore
import SpriteKit
import SwiftUI

/// The balloon run on screen: a ground line, the plane, the balloons, the
/// rounds in the air and a clock. Everything the sim needs comes through
/// `PlaneInput`; this scene only draws the state and turns touches and keys
/// into that input. Simulation runs at the model's fixed timestep, decoupled
/// from the frame rate, so feel does not change with the display.
///
/// Everyone sees the same world: a fixed 16:9 box, `worldHeight` metres tall,
/// letterboxed on any screen of another shape. Seeing further sideways would
/// be an advantage, so nobody gets to.
public final class FlightScene: SKScene {
    /// The box, in scene units; 16:9, the iPhone SE's shape, the narrowest phone.
    public static let boxSize = CGSize(width: 1280, height: 720)
    /// Metres of world visible top to bottom.
    public static let worldHeight: CGFloat = 70

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
    private var bulletNodes: [SKNode] = []
    /// One chevron per balloon, on the edge of the box when the balloon is off it.
    private let markerLayer = SKNode()
    private var markerNodes: [SKShapeNode] = []
    private let countLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let clockLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    /// Cockpit gauges, top right: airspeed with the stall range in red, and altitude.
    private let speedDial: Dial
    private let altitudeDial = Dial(radius: 44, maximum: 150, majorEvery: 50)
    private let speedLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let altitudeLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let controls: ThumbControls
    private var cameraY: CGFloat = 0
    private var wasFiring = false

    /// The roll shown, 0 upright to 1 inverted, chasing the sim's `inverted`.
    private var rollShown: CGFloat = 0
    private var rollFrom: CGFloat = 0
    private var rollStart: TimeInterval?
    /// How long the plane takes to roll when it rights itself.
    private let rollDuration: TimeInterval = 0.35

    /// Scene units per metre.
    private let scale: CGFloat = FlightScene.boxSize.height / FlightScene.worldHeight
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

    /// The thumb overlay draws from `overlay`, which the controls keep current.
    public init(overlay: ThumbOverlayState) {
        planeNode = PlaneNode(livery: .courier, pointsPerMetre: scale)
        controls = ThumbControls(overlay: overlay)
        let stall = CGFloat(practice.model.tuning.stallSpeed * 3.6)
        speedDial = Dial(radius: 44, maximum: 240, majorEvery: 60, redBelow: stall)
        super.init(size: FlightScene.boxSize)
        scaleMode = .aspectFit
        backgroundColor = SKColor(red: 0.55, green: 0.72, blue: 0.9, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.3)
        addChild(world)
        world.addChild(groundNode)
        world.addChild(balloonLayer)
        world.addChild(bulletLayer)
        world.addChild(planeNode)
        markerLayer.zPosition = 50
        addChild(markerLayer)
        groundNode.strokeColor = SKColor(red: 0.25, green: 0.45, blue: 0.2, alpha: 1)
        groundNode.lineWidth = 0.5 * scale
        for label in [countLabel, clockLabel] {
            label.fontSize = 30
            label.fontColor = SKColor(white: 0.12, alpha: 1)
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.zPosition = 100
            addChild(label)
        }
        for label in [speedLabel, altitudeLabel] {
            label.fontSize = 20
            label.fontColor = SKColor(white: 0.12, alpha: 1)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .top
            label.zPosition = 100
            addChild(label)
        }
        for dial in [speedDial, altitudeDial] {
            dial.zPosition = 100
            addChild(dial)
        }
        startRun()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    public override func didMove(to view: SKView) {
        layoutHUD()
        redrawGround()
    }

    private func startRun() {
        practice = Practice(seed: run)
        balloonNodes.forEach { $0.removeFromParent() }
        balloonNodes = practice.balloons.enumerated().map { i, b in
            let n = SceneArt.balloonNode(
                radius: CGFloat(b.radius) * scale, colour: FlightScene.balloonColours[i % 6])
            n.position = CGPoint(x: b.x * scale, y: b.y * scale)
            balloonLayer.addChild(n)
            return n
        }
        markerNodes.forEach { $0.removeFromParent() }
        markerNodes = practice.balloons.indices.map { i in
            let m = SceneArt.markerNode(scale: scale, colour: FlightScene.balloonColours[i % 6])
            markerLayer.addChild(m)
            return m
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
            SceneArt.burst(balloonNodes[i])
        }
        while bulletNodes.count < practice.bullets.count {
            let n = SceneArt.tracerNode(scale: scale)
            bulletLayer.addChild(n)
            bulletNodes.append(n)
        }
        for (i, n) in bulletNodes.enumerated() {
            if i < practice.bullets.count {
                let b = practice.bullets[i]
                n.isHidden = false
                n.position = CGPoint(x: b.x * scale, y: b.y * scale)
                n.zRotation = atan2(b.vy, b.vx)
                // The trail grows to full length over the first tenth of a second,
                // so a fresh round does not wear a tail back through the nose.
                n.children.first?.xScale = CGFloat(min(1, b.age * 10))
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
        updateMarkers()
        updateHUD()
    }

    // MARK: Edge markers

    /// The pilot can see further than the box. A balloon outside it shows as a
    /// chevron on the edge, on the line from the plane to the balloon, bolder
    /// and bigger the nearer it is.
    private func updateMarkers() {
        let inset: CGFloat = 30
        let left = -size.width / 2 + inset, right = size.width / 2 - inset
        let bottom = -size.height * anchorPoint.y + inset,
            top = size.height * (1 - anchorPoint.y) - inset
        let plane = practice.plane
        let pp = CGPoint(x: 0, y: planeNode.position.y - cameraY)
        for (i, b) in practice.balloons.enumerated() {
            let m = markerNodes[i]
            let sp = CGPoint(x: world.position.x + b.x * scale, y: world.position.y + b.y * scale)
            let onScreen = (left...right).contains(sp.x) && (bottom...top).contains(sp.y)
            if b.popped || onScreen {
                m.isHidden = true
                continue
            }
            m.isHidden = false
            let dx = sp.x - pp.x, dy = sp.y - pp.y
            let tx = dx > 0 ? (right - pp.x) / dx : dx < 0 ? (left - pp.x) / dx : .infinity
            let ty = dy > 0 ? (top - pp.y) / dy : dy < 0 ? (bottom - pp.y) / dy : .infinity
            let t = max(0, min(tx, ty))
            var at = CGPoint(x: pp.x + dx * t, y: pp.y + dy * t)
            // Keep clear of the gauges in the top-right corner: slide along the
            // edge the marker is on until it is out from under them.
            let gauges = CGRect(x: right - 250, y: top - 150, width: 300, height: 200)
            if gauges.contains(at) {
                if tx < ty { at.y = min(at.y, gauges.minY) } else { at.x = min(at.x, gauges.minX) }
            }
            m.position = at
            m.zRotation = atan2(dy, dx)
            let metres = hypot(b.x - plane.x, b.y - plane.y)
            let near = max(0, min(1, 1 - (metres - 60) / 400))
            m.alpha = 0.35 + 0.65 * near
            m.setScale(0.6 + 0.4 * near)
        }
    }

    // MARK: HUD

    private func layoutHUD() {
        let left = -size.width / 2 + 24
        let top = size.height * 0.7 - 24
        countLabel.position = CGPoint(x: left, y: top)
        clockLabel.position = CGPoint(x: left, y: top - 40)
        let right = size.width / 2 - 24
        altitudeDial.position = CGPoint(x: right - 44, y: top - 44)
        speedDial.position = CGPoint(x: right - 44 - 112, y: top - 44)
        altitudeLabel.position = CGPoint(
            x: altitudeDial.position.x, y: altitudeDial.position.y - 52)
        speedLabel.position = CGPoint(x: speedDial.position.x, y: speedDial.position.y - 52)
    }

    private func updateHUD() {
        let kmh = Int((practice.plane.speed * 3.6).rounded())
        let metres = Int(practice.plane.y.rounded())
        speedDial.value = CGFloat(kmh)
        altitudeDial.value = CGFloat(metres)
        speedLabel.text = String(localized: "\(kmh) km/h", bundle: .module)
        altitudeLabel.text = String(localized: "\(metres) m", bundle: .module)
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
            path.addLine(to: CGPoint(x: x, y: -1.3 * scale))
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
