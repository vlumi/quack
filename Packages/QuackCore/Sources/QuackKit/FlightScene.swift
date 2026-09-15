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
    /// What the runs are for; the title screen sets it.
    public private(set) var mode = Practice.Mode.courier
    /// Behind the title screen the world runs but nobody is flying: inputs
    /// are ignored and the readouts are off.
    public var attract = false {
        didSet { setHUDHidden(attract) }
    }
    private var input = PlaneInput.idle
    private var accumulator: TimeInterval = 0
    private var lastTime: TimeInterval?

    let world = SKNode()
    let planeNode: PlaneNode
    /// The sky, the backdrop, the ground and the scenery, for the run's hour.
    private let look = StripLook()
    /// Readout ink for the hour: dark by day, pale at night.
    var hudInk = SKColor(white: 0.12, alpha: 1)
    /// One node per field, each holding its strip and its two approach cones,
    /// placed every frame at the field's lap nearest the plane.
    private let fieldLayer = SKNode()
    private var fieldNodes: [SKNode] = []
    private let balloonLayer = SKNode()
    private let bulletLayer = SKNode()
    private var balloonNodes: [SKNode] = []
    private var bulletNodes: [SKNode] = []
    /// One chevron per balloon, and one for the field, on the edge of the box
    /// when what they point at is off it.
    let markerLayer = SKNode()
    var markerNodes: [SKShapeNode] = []
    let fieldMarker: SKShapeNode
    /// The whole world, tiny, under the status line.
    let minimap = Minimap(size: CGSize(width: 320, height: 40))
    let countLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    let clockLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    /// Rounds left, and whether they are being loaded.
    let ammoLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    /// What the plane is doing, or what just happened to it.
    let statusLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    var flash: (text: String, until: TimeInterval)?
    /// Cockpit gauges, top right: airspeed with the stall range in red, and
    /// altitude above sea level with the thin air in red.
    let speedDial: Dial
    let altitudeDial = Dial(radius: 44, maximum: 300, majorEvery: 100)
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

    /// The thumb overlay draws from `overlay`, which the controls keep current.
    public init(overlay: ThumbOverlayState) {
        planeNode = PlaneNode(livery: .courier, pointsPerMetre: scale)
        controls = ThumbControls(overlay: overlay)
        speedDial = Dial(radius: 44, maximum: 240, majorEvery: 60)
        fieldMarker = SceneArt.markerNode(scale: scale, colour: .white)
        super.init(size: FlightScene.boxSize)
        scaleMode = .aspectFit
        anchorPoint = CGPoint(x: 0.5, y: 0.3)
        addChild(look.sky)
        addChild(look.backdrop)
        addChild(world)
        // Scenery stands behind the ground's edge; the fields go over the
        // ground, since their bands sit just under its line.
        world.addChild(look.scenery)
        world.addChild(look.ground)
        world.addChild(look.groundShade)
        world.addChild(fieldLayer)
        world.addChild(balloonLayer)
        world.addChild(bulletLayer)
        world.addChild(planeNode)
        world.addChild(look.clouds)
        markerLayer.zPosition = 50
        markerLayer.addChild(fieldMarker)
        addChild(markerLayer)
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
        render(at: 0)
    }

    private func applyTuning() {
        practice.model.flight.tuning = tuning.flight
        practice.model.landing = tuning.landing
        practice.gun = tuning.gun
        practice.windTuning = tuning.wind
        practice.courierTuning = tuning.courier
        controls.throwDistance = CGFloat(tuning.throwDistance)
        controls.minimumThrow = CGFloat(tuning.minimumThrow)
        controls.invertedPitch = tuning.invertedPitch
        rollDuration = tuning.rollDuration
        speedDial.redBelow = CGFloat(tuning.flight.stallSpeed * 3.6)
        practice.resizeFields(to: tuning.fieldLength)
        altitudeDial.redAbove = CGFloat(tuning.flight.thinAirFrom)
        applyLook()
        fieldNodes.forEach { $0.removeFromParent() }
        fieldNodes = practice.model.strip.airfields.map { field in
            // Drawn with the field starting at 0; `render` places it.
            let local = Airfield(start: 0, length: field.length, name: field.name)
            let node = SKNode()
            node.addChild(SceneArt.approachCones(practice.model, field: local, scale: scale))
            node.addChild(SceneArt.airfieldNode(local, scale: scale, palette: look.palette))
            SceneArt.setWindsock(
                in: node, step: practice.windStep, direction: practice.windDirection)
            fieldLayer.addChild(node)
            return node
        }
        minimap.reset(
            strip: practice.model.strip,
            balloonColours: practice.balloons.indices.map { look.palette.balloon($0) })
    }

    /// Build the world's look again if the run, its hour or its scenery changed,
    /// and recolour what takes the hour's light: the balloons and the readouts.
    private func applyLook() {
        let hour = tuning.timeOfDay(seeded: practice.hour)
        guard look.needsBuild(practice, hour: hour) else { return }
        look.build(practice, hour: hour, scale: scale, box: size)
        backgroundColor = look.palette.sky[2].color()
        hudInk = look.palette.hudInk
        applyInk()
        balloonNodes.forEach { $0.removeFromParent() }
        balloonNodes = practice.balloons.enumerated().map { i, b in
            let n = SceneArt.balloonNode(
                radius: CGFloat(b.radius) * scale, colour: look.palette.balloon(i))
            n.position = CGPoint(x: b.x * scale, y: b.y * scale)
            if !b.popped { balloonLayer.addChild(n) }
            return n
        }
    }

    /// Fly `mode`: a fresh run of it, unless the run behind the title is that
    /// mode and nobody has touched it yet, which is then simply flown.
    public func start(_ mode: Practice.Mode) {
        guard mode != self.mode || practice.startedAt != nil else { return }
        self.mode = mode
        run += 1
        startRun()
    }

    private func startRun() {
        practice = Practice(seed: run, mode: mode, fieldLength: tuning.fieldLength)
        applyTuning()
        // A new run starts with the tuned belt, not the default one.
        practice.ammo = practice.capacity
        markerNodes.forEach { $0.removeFromParent() }
        markerNodes = practice.balloons.indices.map { i in
            let m = SceneArt.markerNode(scale: scale, colour: Palette.Base.balloons[i % 6].color())
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
        input = attract ? .idle : controls.input
        // Once the run is done, the next pull of the trigger starts the next one.
        if practice.isFinished && input.fire && !wasFiring {
            run += 1
            startRun()
        }
        wasFiring = input.fire
        while accumulator >= FlightModel.dt {
            practice.advance(input: input)
            if let event = practice.lastEvent { show(event, at: currentTime) }
            if let event = practice.courierEvent { show(event, at: currentTime) }
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
        planeNode.xScale = swingScale()

        // Gloss: the top surface catches the sun in proportion to how squarely
        // it faces it, so it sweeps during a loop and vanishes inverted.
        let up = CGVector(dx: -sin(plane.heading), dy: cos(plane.heading))
        let facing = (up.dx * sun.dx + up.dy * sun.dy) * (plane.inverted ? -1 : 1)
        planeNode.gloss.alpha = max(0, facing) * max(0, facing) * pow(cos(planeNode.roll), 2)

        // Balloons that popped this frame burst; rounds are re-laid each frame.
        let strip = practice.model.strip
        // Everything on the strip is drawn at its lap nearest the plane, so the
        // seam never shows.
        let near = { (x: Double) -> CGFloat in
            CGFloat(plane.x + strip.offset(from: plane.x, to: x)) * self.scale
        }
        for (node, field) in zip(fieldNodes, strip.airfields) {
            node.position = CGPoint(x: near(field.start), y: field.elevation * scale)
        }
        for (i, b) in practice.balloons.enumerated() {
            if b.popped && balloonNodes[i].parent != nil && !balloonNodes[i].hasActions() {
                SceneArt.burst(balloonNodes[i])
            }
            if !b.popped {
                balloonNodes[i].position = CGPoint(x: near(b.x), y: CGFloat(b.y) * scale)
            }
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
                n.position = CGPoint(x: near(b.x), y: b.y * scale)
                n.zRotation = atan2(b.vy, b.vx)
                // The trail grows to full length over the first tenth of a second,
                // so a fresh round does not wear a tail back through the nose.
                n.children.first?.xScale = CGFloat(min(1, b.age * 10))
            } else {
                n.isHidden = true
            }
        }

        follow(plane)
        look.update(
            practice, planePoints: planeNode.position, cameraY: cameraY, scale: scale, box: size)
        updateMarkers()
        updateHUD(at: now)
    }

    /// The sim flips instantly; the drawing rolls, top toward the camera, with a
    /// little easing, and rolls back the same way in reverse. On the ground a
    /// plane never rolls: it swings round (`swingScale`), so the drawing snaps.
    private func updateRoll(inverted: Bool, at now: TimeInterval) {
        let target: CGFloat = inverted ? 1 : 0
        if practice.phase.isOnGround {
            rollShown = target
            rollStart = nil
        }
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

    /// A plane swinging round on the ground is drawn narrowing to edge-on and
    /// widening again mirrored: a yaw seen from the side. The sim flips its
    /// facing at the end, where a mirrored drawing and a flipped one look the same.
    private func swingScale() -> CGFloat {
        guard case .taxiing(let steps, _) = practice.phase, case .turn(let elapsed) = steps.first
        else { return 1 }
        return CGFloat(cos(.pi * min(1, elapsed / max(0.01, tuning.landing.turnTime))))
    }

    private func follow(_ plane: PlaneState) {
        // Camera: follows sideways always; up and down it keeps the lowest ground
        // near the plane on the anchor line, and rises further once the plane
        // would leave the top 40% of the view, easing so a loop does not yank
        // the ground.
        let below =
            [-30.0, 0, 30].map { practice.model.strip.groundHeight(at: plane.x + $0) }.min() ?? 0
        let target2 = max(below * scale, planeNode.position.y - size.height * 0.4)
        cameraY += (target2 - cameraY) * 0.12
        world.position = CGPoint(x: -planeNode.position.x, y: -cameraY)
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
