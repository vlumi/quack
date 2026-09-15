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
        ammoLabel.fontSize = 24
        ammoLabel.horizontalAlignmentMode = .left
        ammoLabel.verticalAlignmentMode = .top
        ammoLabel.zPosition = 100
        addChild(ammoLabel)
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
        minimap.zPosition = 100
        addChild(minimap)
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
        ammoLabel.position = CGPoint(x: left, y: top - 80)
        statusLabel.position = CGPoint(x: 0, y: top)
        minimap.position = CGPoint(x: 0, y: top - 84)
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
        updateAmmo()
        minimap.update(practice)
        statusLabel.text = status(at: now)
    }

    /// Rounds left; red and a hint when the belt is empty, a note while it loads.
    private func updateAmmo() {
        let ink = SKColor(white: 0.12, alpha: 1)
        if practice.ammo == 0 && !practice.isRearming {
            ammoLabel.text = String(localized: "Out of rounds: land to rearm", bundle: .module)
            ammoLabel.fontColor = SKColor(red: 0.75, green: 0.1, blue: 0.1, alpha: 1)
        } else if practice.isRearming {
            ammoLabel.text = String(localized: "\(practice.ammo) rounds, rearming", bundle: .module)
            ammoLabel.fontColor = ink
        } else {
            ammoLabel.text = String(localized: "\(practice.ammo) rounds", bundle: .module)
            ammoLabel.fontColor = ink
        }
    }

    private func status(at now: TimeInterval) -> String {
        if let flash, now < flash.until { return flash.text }
        switch practice.phase {
        case .approach:
            return String(localized: "Landing", bundle: .module)
        case .parked(let repair) where repair > 0:
            return String(localized: "Repairing", bundle: .module)
        case .parked where !practice.isFinished:
            return String(localized: "Pull up to take off, push to turn around", bundle: .module)
        case .taxiing:
            return String(localized: "Taxiing", bundle: .module)
        default:
            return practice.needsToLand
                ? String(
                    localized: "All popped: land at any field to stop the clock", bundle: .module)
                : ""
        }
    }

    // MARK: Edge markers

    /// The pilot can see further than the box. A balloon, or the field, outside
    /// it shows as a chevron on the edge, on the line from the plane, bolder and
    /// bigger the nearer it is.
    func updateMarkers() {
        let plane = practice.plane
        let strip = practice.model.strip
        for (i, b) in practice.balloons.enumerated() {
            place(
                markerNodes[i], at: plane.x + strip.offset(from: plane.x, to: b.x), b.y,
                hidden: b.popped, from: plane)
        }
        if let field = strip.nearestAirfield(to: plane.x) {
            let nearest = min(max(plane.x, field.start), field.end)
            place(fieldMarker, at: nearest, 0, hidden: false, from: plane)
        }
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
        // Keep clear of the chrome: the status line and minimap top centre, the
        // clock and rounds top left, the gauges top right. On the top edge a
        // marker slides sideways out of the status area; anything that lands on
        // the corner readouts or gauges slides down the side below them.
        let gauges = CGRect(x: right - 250, y: top - 150, width: 300, height: 200)
        let readouts = CGRect(x: left - 20, y: top - 130, width: 380, height: 180)
        let status = CGRect(x: -440, y: top - 100, width: 880, height: 150)
        if status.contains(at) {
            at.x = at.x < 0 ? status.minX : status.maxX
        }
        if readouts.contains(at) {
            at = CGPoint(x: left, y: readouts.minY)
        }
        if gauges.contains(at) {
            at = CGPoint(x: right, y: gauges.minY)
        }
        m.position = at
        m.zRotation = atan2(dy, dx)
        let metres = hypot(x - plane.x, y - plane.y)
        let near = max(0, min(1, 1 - (metres - 60) / 400))
        m.alpha = 0.35 + 0.65 * near
        m.setScale(0.6 + 0.4 * near)
    }
}
