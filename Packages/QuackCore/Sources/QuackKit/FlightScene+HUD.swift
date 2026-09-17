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
        ammoLabel.fontSize = 20
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
        for label in [speedLabel, altitudeLabel, fuelLabel] {
            label.fontSize = 20
            label.fontColor = SKColor(white: 0.12, alpha: 1)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .top
            label.zPosition = 100
            addChild(label)
        }
        minimap.zPosition = 100
        addChild(minimap)
        for tally in [balloonTally, roundTally] {
            tally.zPosition = 100
            addChild(tally)
        }
        let ink = SKColor(white: 0.12, alpha: 1)
        let symbols = [
            (fuelDial, "fuelpump.fill"), (speedDial, "speedometer"),
            (altitudeDial, "arrow.up.to.line"),
        ]
        for (dial, symbol) in symbols {
            dial.zPosition = 100
            dial.setIcon(SceneArt.symbol(symbol, pointSize: 22, colour: ink), size: 18)
            addChild(dial)
        }
    }

    /// Paint the readouts in the hour's ink.
    func applyInk() {
        for label in [countLabel, clockLabel, statusLabel, speedLabel, altitudeLabel, ammoLabel] {
            label.fontColor = hudInk
        }
    }

    /// The parked panel's buttons.
    public func takeOff(direction: Double) { takeOffRequest = direction }
    public func pick(_ index: Int) { practice.pick(index) }

    /// Keep the SwiftUI layer's view of the run current, touching it only on a change.
    func publishHUD() {
        let parked: Bool
        if case .parked(let repair) = practice.phase, repair == 0, !attract {
            parked = true
        } else {
            parked = false
        }
        if hud.parked != parked { hud.parked = parked }
        if hud.board != practice.offers { hud.board = practice.offers }
        if hud.chosen != practice.chosenOffer { hud.chosen = practice.chosenOffer }
        if hud.carrying != practice.contract { hud.carrying = practice.contract }
        let names = practice.model.strip.airfields.map(\.name)
        if hud.fieldNames != names { hud.fieldNames = names }
    }

    /// Flash the guns' news: a hit, the engine gone, a gun knocked out.
    func show(_ event: HazardEvent, at now: TimeInterval) {
        switch event {
        case .hit(let x, let y):
            HazardArt.burst(at: CGPoint(x: x * scale, y: y * scale), scale: scale, in: hazardLayer)
            flash = (
                practice.engineShotOut
                    ? String(localized: "Engine shot out: glide to a field", bundle: .module)
                    : String(localized: "Hit! Repairs due at the next stop", bundle: .module),
                now + 2
            )
        case .gunKnockedOut:
            flash = (String(localized: "Gun knocked out", bundle: .module), now + 1.5)
        case .enemyHit(let down):
            if down {
                flash = (String(localized: "Rival shot down", bundle: .module), now + 2)
            }
            if let e = practice.enemy {
                HazardArt.burst(
                    at: CGPoint(x: enemyNode.position.x, y: e.plane.y * scale), scale: scale,
                    in: hazardLayer, size: down ? 4 : 2)
            }
        case .enemyDown:
            HazardArt.burst(
                at: enemyNode.position, scale: scale, in: hazardLayer, size: 6)
        }
    }

    /// A gun node per gun for the run, in the hour's light.
    func resetHazards() {
        gunNodes.forEach { $0.removeFromParent() }
        gunNodes = practice.guns.map { _ in
            let n = HazardArt.gunNode(scale: scale, palette: look.palette)
            hazardLayer.addChild(n)
            return n
        }
    }

    /// The rival at its lap nearest the plane, its rounds, and its chevron.
    func placeEnemy(near: (Double) -> CGFloat) {
        guard let e = practice.enemy, !e.down else {
            enemyNode.isHidden = true
            enemyMarker.isHidden = true
            return
        }
        enemyNode.isHidden = false
        enemyNode.position = CGPoint(x: near(e.plane.x), y: e.plane.y * scale)
        enemyNode.zRotation = CGFloat(e.plane.heading)
        enemyNode.roll = e.plane.inverted ? .pi : 0
        if e.falling { enemyNode.alpha = 0.8 } else { enemyNode.alpha = 1 }
        while enemyBulletNodes.count < practice.enemyBullets.count {
            let n = SceneArt.tracerNode(scale: scale)
            hazardLayer.addChild(n)
            enemyBulletNodes.append(n)
        }
        for (i, n) in enemyBulletNodes.enumerated() {
            if i < practice.enemyBullets.count {
                let b = practice.enemyBullets[i]
                n.isHidden = false
                n.position = CGPoint(x: near(b.x), y: b.y * scale)
                n.zRotation = atan2(b.vy, b.vx)
                n.children.first?.xScale = CGFloat(min(1, b.age * 10))
            } else {
                n.isHidden = true
            }
        }
        let strip = practice.model.strip
        place(
            enemyMarker, at: practice.plane.x + strip.offset(from: practice.plane.x, to: e.plane.x),
            e.plane.y, hidden: !e.isFlying, from: practice.plane)
    }

    /// Guns at their lap nearest the plane, barrels on it; shells re-laid each frame.
    func placeHazards(near: (Double) -> CGFloat) {
        let strip = practice.model.strip
        let planePoint = planeNode.position
        for (node, gun) in zip(gunNodes, practice.guns) {
            node.position = CGPoint(
                x: near(gun.x), y: CGFloat(strip.groundHeight(at: gun.x)) * scale)
            HazardArt.aim(node, at: planePoint, alive: gun.isAlive)
        }
        while shellNodes.count < practice.shells.count {
            let n = HazardArt.shellNode(scale: scale)
            hazardLayer.addChild(n)
            shellNodes.append(n)
        }
        for (i, n) in shellNodes.enumerated() {
            if i < practice.shells.count {
                let s = practice.shells[i]
                n.isHidden = false
                n.position = CGPoint(x: near(s.x), y: s.y * scale)
                n.zRotation = atan2(s.vy, s.vx)
            } else {
                n.isHidden = true
            }
        }
    }

    /// The readouts, gauges, minimap and chevrons, off behind the title screen.
    func setHUDHidden(_ hidden: Bool) {
        let chrome: [SKNode] = [
            countLabel, clockLabel, ammoLabel, statusLabel, speedLabel, altitudeLabel, minimap,
            speedDial, altitudeDial, fuelDial, fuelLabel, markerLayer, balloonTally, roundTally,
        ]
        for node in chrome { node.isHidden = hidden }
    }

    /// One mark per balloon in its colour, one per round in the belt, for the run.
    func resetTallies() {
        balloonTally.reset(colours: practice.balloons.indices.map { look.palette.balloon($0) })
        roundTally.reset(
            colours: Array(
                repeating: SKColor(red: 0.85, green: 0.7, blue: 0.3, alpha: 1),
                count: practice.capacity))
    }

    func layoutHUD() {
        let left = -size.width / 2 + 24
        let top = size.height * 0.7 - 24
        countLabel.position = CGPoint(x: left, y: top)
        clockLabel.position = CGPoint(x: left, y: top - 40)
        balloonTally.position = CGPoint(x: left + 6, y: top - 56)
        roundTally.position = CGPoint(x: left + 3, y: top - 92)
        ammoLabel.position = CGPoint(x: roundTally.position.x + 8, y: top - 78)
        statusLabel.position = CGPoint(x: 0, y: top)
        minimap.position = CGPoint(x: 0, y: top - 108)
        let right = size.width / 2 - 24
        altitudeDial.position = CGPoint(x: right - 44, y: top - 44)
        speedDial.position = CGPoint(x: right - 44 - 112, y: top - 44)
        fuelDial.position = CGPoint(x: right - 44 - 224, y: top - 44)
        fuelLabel.position = CGPoint(x: fuelDial.position.x, y: fuelDial.position.y - 52)
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

    /// Flash the courier's news: a bag loaded, delivered, or lost.
    func show(_ event: CourierEvent, at now: TimeInterval) {
        let text: String
        switch event {
        case .loaded(let c) where c.kind == .passenger:
            text = String(localized: "Passenger to \(name(c.to)) aboard", bundle: .module)
        case .loaded(let c):
            text = String(localized: "Mail for \(name(c.to)) aboard", bundle: .module)
        case .delivered(_, let pay):
            text = String(localized: "Delivered: \(francs(pay))", bundle: .module)
        case .lost(let c) where c.kind == .passenger:
            text = String(localized: "The passenger walks home", bundle: .module)
        case .lost:
            text = String(localized: "The mail is lost", bundle: .module)
        case .complaint:
            text = String(localized: "The passenger is not enjoying this", bundle: .module)
        }
        flash = (text, now + 2)
    }

    func name(_ field: Int) -> String { practice.model.strip.airfields[field].name }

    /// "Mail for X" or "Passenger to X".
    func job(_ c: Contract) -> String {
        c.kind == .passenger
            ? String(localized: "Passenger to \(name(c.to))", bundle: .module)
            : String(localized: "Mail for \(name(c.to))", bundle: .module)
    }

    func francs(_ amount: Double) -> String {
        String(localized: "\(Int(amount.rounded())) fr", bundle: .module)
    }

    func updateHUD(at now: TimeInterval) {
        let plane = practice.plane
        let kmh = Int((plane.speed * 3.6).rounded())
        // Above sea level, which is what thins the air; on a field it reads the field's elevation.
        let metres = Int((plane.y - practice.model.landing.gearHeight).rounded())
        speedDial.value = CGFloat(kmh)
        altitudeDial.value = CGFloat(metres)
        fuelDial.value = CGFloat(practice.fuelShare)
        let left = Int(practice.fuel.rounded(.down))
        fuelLabel.text = String(
            localized: "\(left / 60):\(left % 60, specifier: "%02d") fuel", bundle: .module)
        fuelLabel.fontColor =
            practice.fuelShare < 0.2 ? SKColor(red: 0.75, green: 0.1, blue: 0.1, alpha: 1) : hudInk
        speedLabel.text = String(localized: "\(kmh) km/h", bundle: .module)
        altitudeLabel.text = String(localized: "\(metres) m", bundle: .module)
        let seconds = practice.elapsed.formatted(.number.precision(.fractionLength(1)))
        if practice.mode == .courier {
            countLabel.text = francs(practice.money)
            if let contract = practice.contract, let pay = practice.payNow {
                clockLabel.text = job(contract) + ": " + francs(pay)
            } else if let pick = practice.chosen {
                clockLabel.text = job(pick) + ", " + francs(pick.fare)
            } else {
                clockLabel.text = String(localized: "\(seconds) s", bundle: .module)
            }
        } else if practice.isFinished {
            countLabel.text = String(
                localized: "Landed in \(seconds) s. Fire to go again.", bundle: .module)
            clockLabel.text = ""
        } else {
            // The balloons left are the row of balloons; the clock takes the top line.
            countLabel.text = String(localized: "\(seconds) s", bundle: .module)
            clockLabel.text = ""
        }
        balloonTally.isHidden = practice.mode != .balloons || practice.isFinished
        balloonTally.update(present: practice.balloons.map { !$0.popped })
        roundTally.update(count: practice.ammo)
        updateAmmo()
        minimap.update(practice)
        statusLabel.text = status(at: now)
    }

    /// Rounds left; red and a hint when the belt is empty, a note while it loads.
    private func updateAmmo() {
        // The belt is the row of rounds; words only when there is something to say.
        if practice.ammo == 0 && !practice.isRearming {
            ammoLabel.text = String(localized: "Out of rounds: land to rearm", bundle: .module)
            ammoLabel.fontColor = SKColor(red: 0.75, green: 0.1, blue: 0.1, alpha: 1)
        } else if practice.isRearming {
            ammoLabel.text = String(localized: "Rearming", bundle: .module)
            ammoLabel.fontColor = hudInk
        } else {
            ammoLabel.text = ""
        }
    }

    private func status(at now: TimeInterval) -> String {
        if let flash, now < flash.until { return flash.text }
        switch practice.phase {
        case .approach:
            return String(localized: "Landing", bundle: .module)
        case .parked(let repair) where repair > 0:
            return String(localized: "Repairing", bundle: .module)
        case .parked where practice.isRefuelling || practice.isRearming:
            return practice.isRefuelling
                ? String(localized: "Refuelling", bundle: .module)
                : String(localized: "Rearming", bundle: .module)
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
        // The chevron points at the destination, aboard or being picked, else the nearest field.
        let target = (practice.contract ?? practice.chosen).map {
            strip.image(of: strip.airfields[$0.to], near: plane.x)
        }
        if let field = target ?? strip.nearestAirfield(to: plane.x) {
            let nearest = min(max(plane.x, field.start), field.end)
            place(fieldMarker, at: nearest, field.elevation, hidden: false, from: plane)
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
        let gauges = CGRect(x: right - 362, y: top - 150, width: 412, height: 200)
        let readouts = CGRect(x: left - 20, y: top - 130, width: 380, height: 180)
        let status = CGRect(x: -440, y: top - 180, width: 880, height: 230)
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
