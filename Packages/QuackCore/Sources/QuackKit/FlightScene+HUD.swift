import QuackCore
import SpriteKit

/// The scene's screen-space chrome: the clock and balloon count, the status
/// line, the gauges, and the chevrons on the box's edge.
extension FlightScene {
    func setUpHUD() {
        for label in [countLabel, clockLabel] {
            label.fontSize = 30
            label.fontColor = SKColor(white: 0.12, alpha: 1)
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.zPosition = 100
            addChild(label)
        }
        statusLabel.fontSize = 26
        statusLabel.fontColor = SKColor(white: 0.12, alpha: 1)
        statusLabel.horizontalAlignmentMode = .center
        statusLabel.verticalAlignmentMode = .top
        statusLabel.zPosition = 100
        addChild(statusLabel)
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
    }

    func layoutHUD() {
        let left = -size.width / 2 + 24
        let top = size.height * 0.7 - 24
        countLabel.position = CGPoint(x: left, y: top)
        clockLabel.position = CGPoint(x: left, y: top - 40)
        statusLabel.position = CGPoint(x: 0, y: top)
        let right = size.width / 2 - 24
        altitudeDial.position = CGPoint(x: right - 44, y: top - 44)
        speedDial.position = CGPoint(x: right - 44 - 112, y: top - 44)
        altitudeLabel.position = CGPoint(
            x: altitudeDial.position.x, y: altitudeDial.position.y - 52)
        speedLabel.position = CGPoint(x: speedDial.position.x, y: speedDial.position.y - 52)
    }

    /// Flash what just happened for a moment; routine transitions stay quiet.
    func show(_ event: FlightEvent, at now: TimeInterval) {
        let text: String
        switch event {
        case .bounce: text = String(localized: "Bounced", bundle: .module)
        case .brokenUndercarriage: text = String(localized: "Broken undercarriage", bundle: .module)
        case .crash: text = String(localized: "Crashed", bundle: .module)
        case .touchdown: text = String(localized: "Touchdown", bundle: .module)
        case .assistEngaged, .assistAborted, .parked, .liftoff, .backOnField: return
        }
        flash = (text, now + 1.5)
    }

    func updateHUD(at now: TimeInterval) {
        let plane = practice.plane
        let kmh = Int((plane.speed * 3.6).rounded())
        let metres = Int((plane.y - practice.model.landing.gearHeight).rounded())
        speedDial.value = CGFloat(kmh)
        altitudeDial.value = CGFloat(metres)
        speedLabel.text = String(localized: "\(kmh) km/h", bundle: .module)
        altitudeLabel.text = String(localized: "\(metres) m", bundle: .module)
        let seconds = practice.elapsed.formatted(.number.precision(.fractionLength(1)))
        if practice.isFinished {
            countLabel.text = String(
                localized: "Landed in \(seconds) s. Fire to go again.", bundle: .module)
            clockLabel.text = ""
        } else {
            countLabel.text = String(
                localized: "\(practice.remaining) balloons left", bundle: .module)
            clockLabel.text = String(localized: "\(seconds) s", bundle: .module)
        }
        statusLabel.text = status(at: now)
    }

    private func status(at now: TimeInterval) -> String {
        if let flash, now < flash.until { return flash.text }
        switch practice.phase {
        case .approach:
            return String(localized: "Landing", bundle: .module)
        case .parked(let repair) where repair > 0:
            return String(localized: "Repairing", bundle: .module)
        case .parked where practice.startedAt == nil:
            return String(localized: "Pull up to take off", bundle: .module)
        default:
            return practice.needsToLand
                ? String(localized: "All popped: land to stop the clock", bundle: .module) : ""
        }
    }

    // MARK: Edge markers

    /// The pilot can see further than the box. A balloon, or the field, outside
    /// it shows as a chevron on the edge, on the line from the plane, bolder and
    /// bigger the nearer it is.
    func updateMarkers() {
        let plane = practice.plane
        for (i, b) in practice.balloons.enumerated() {
            place(markerNodes[i], at: b.x, b.y, hidden: b.popped, from: plane)
        }
        let field = Practice.airfield
        let nearest = min(max(plane.x, field.start), field.end)
        place(fieldMarker, at: nearest, 0, hidden: false, from: plane)
    }

    private func place(
        _ m: SKShapeNode, at x: Double, _ y: Double, hidden: Bool, from plane: PlaneState
    ) {
        let inset: CGFloat = 30
        let left = -size.width / 2 + inset, right = size.width / 2 - inset
        let bottom = -size.height * anchorPoint.y + inset
        let top = size.height * (1 - anchorPoint.y) - inset
        let pp = CGPoint(x: 0, y: planeNode.position.y - cameraY)
        let sp = CGPoint(x: world.position.x + x * scale, y: world.position.y + y * scale)
        let onScreen = (left...right).contains(sp.x) && (bottom...top).contains(sp.y)
        m.isHidden = hidden || onScreen
        guard !m.isHidden else { return }
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
        let metres = hypot(x - plane.x, y - plane.y)
        let near = max(0, min(1, 1 - (metres - 60) / 400))
        m.alpha = 0.35 + 0.65 * near
        m.setScale(0.6 + 0.4 * near)
    }
}
