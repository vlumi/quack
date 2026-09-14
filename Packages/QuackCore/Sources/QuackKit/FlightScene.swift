import QuackCore
import SpriteKit
import SwiftUI

/// The balloon run on screen: the field, the plane, the balloons, the rounds
/// in the air, the gauges and a clock. Everything the sim needs comes through
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

    var practice = Practice(seed: 1)
    private var run: UInt64 = 1
    private var input = PlaneInput.idle
    private var accumulator: TimeInterval = 0
    private var lastTime: TimeInterval?

    let world = SKNode()
    let planeNode: PlaneNode
    private let groundNode = SKShapeNode()
    private let glideSlopeNode = SKNode()
    private let balloonLayer = SKNode()
    private let bulletLayer = SKNode()
    private var balloonNodes: [SKNode] = []
    private var bulletNodes: [SKNode] = []
    /// One chevron per balloon, and one for the field, on the edge of the box
    /// when what they point at is off it.
    let markerLayer = SKNode()
    var markerNodes: [SKShapeNode] = []
    let fieldMarker: SKShapeNode
    let countLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    let clockLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    /// What the plane is doing, or what just happened to it.
    let statusLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    var flash: (text: String, until: TimeInterval)?
    /// Cockpit gauges, top right: airspeed with the stall range in red, and altitude.
    let speedDial: Dial
    let altitudeDial = Dial(radius: 44, maximum: 150, majorEvery: 50)
    let speedLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    let altitudeLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let controls: ThumbControls
    var cameraY: CGFloat = 0
    private var wasFiring = false

    /// The roll shown, 0 upright to 1 inverted, chasing the sim's `inverted`.
    private var rollShown: CGFloat = 0
    private var rollFrom: CGFloat = 0
    private var rollStart: TimeInterval?
    /// How long the plane takes to roll when it rights itself.
    private var rollDuration: TimeInterval = 0.35

    /// The dials in force. Set by the tuning panel; applied at once, and again
    /// to every new run.
    public var tuning = Tuning() {
        didSet { applyTuning() }
    }
    /// Freezes the flight while the tuning panel is open; the clock does not run.
    public var simulationPaused = false

    /// Scene units per metre.
    let scale: CGFloat = FlightScene.boxSize.height / FlightScene.worldHeight
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
        speedDial = Dial(radius: 44, maximum: 240, majorEvery: 60)
        fieldMarker = SceneArt.markerNode(scale: scale, colour: .white)
        super.init(size: FlightScene.boxSize)
        scaleMode = .aspectFit
        backgroundColor = SKColor(red: 0.55, green: 0.72, blue: 0.9, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.3)
        addChild(world)
        world.addChild(glideSlopeNode)
        world.addChild(SceneArt.airfieldNode(Practice.airfield, scale: scale))
        world.addChild(groundNode)
        world.addChild(balloonLayer)
        world.addChild(bulletLayer)
        world.addChild(planeNode)
        markerLayer.zPosition = 50
        markerLayer.addChild(fieldMarker)
        addChild(markerLayer)
        groundNode.strokeColor = SKColor(red: 0.25, green: 0.45, blue: 0.2, alpha: 1)
        groundNode.lineWidth = 0.5 * scale
        setUpHUD()
        startRun()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    public override func didMove(to view: SKView) {
        #if os(iOS)
        // A UIView takes one touch at a time unless told otherwise, and
        // SpriteView does not tell it: the first thumb down took every touch,
        // so holding the trigger locked out the elevator and the other way round.
        view.isMultipleTouchEnabled = true
        #endif
        layoutHUD()
        redrawGround()
    }

    private func applyTuning() {
        practice.model.flight.tuning = tuning.flight
        practice.model.landing = tuning.landing
        practice.gun = tuning.gun
        controls.throwDistance = CGFloat(tuning.throwDistance)
        controls.minimumThrow = CGFloat(tuning.minimumThrow)
        controls.invertedPitch = tuning.invertedPitch
        rollDuration = tuning.rollDuration
        speedDial.redBelow = CGFloat(tuning.flight.stallSpeed * 3.6)
        glideSlopeNode.removeAllChildren()
        glideSlopeNode.addChild(
            SceneArt.glideSlopes(Practice.airfield, landing: tuning.landing, scale: scale))
    }

    private func startRun() {
        practice = Practice(seed: run)
        applyTuning()
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
        flash = nil
    }

    public override func update(_ currentTime: TimeInterval) {
        defer { lastTime = currentTime }
        guard let last = lastTime, !simulationPaused else { return }
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
            if let event = practice.lastEvent { show(event, at: currentTime) }
            accumulator -= FlightModel.dt
        }
        render(at: currentTime)
    }

    private func render(at now: TimeInterval) {
        let plane = practice.plane
        planeNode.position = CGPoint(x: plane.x * scale, y: plane.y * scale)
        planeNode.zRotation = CGFloat(plane.heading)
        if case .wrecked = practice.phase {
            planeNode.alpha = Int(now * 8) % 2 == 0 ? 0.25 : 1
        } else {
            planeNode.alpha = 1
        }

        updateRoll(inverted: plane.inverted, at: now)

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
        updateHUD(at: now)
    }

    /// The sim flips instantly; the drawing rolls, top toward the camera, with a
    /// little easing, and rolls back the same way in reverse.
    private func updateRoll(inverted: Bool, at now: TimeInterval) {
        let target: CGFloat = inverted ? 1 : 0
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
