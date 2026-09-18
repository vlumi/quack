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
        if practice.mode == .duckfight {
            let over = practice.isFinished
            if hud.fightOver != over { hud.fightOver = over }
            let standings = practice.standings.map { s in
                HUDState.Standing(
                    name: session?.roster.name(for: s.seat)
                        ?? (practice.pilots[s.seat].brain == .rival
                            ? String(localized: "Rival", bundle: .module) : "\(s.seat + 1)"),
                    kills: s.kills, downs: s.downs, isMe: s.seat == localSeat)
            }
            if hud.standings != standings { hud.standings = standings }
        }
        let parked: Bool
        if case .parked(let repair) = me.phase, repair == 0, !attract {
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
        let plane = me.plane
        let kmh = Int((plane.speed * 3.6).rounded())
        // Above sea level, which is what thins the air; on a field it reads the field's elevation.
        let metres = Int((plane.y - practice.model.landing.gearHeight).rounded())
        speedDial.value = CGFloat(kmh)
        altitudeDial.value = CGFloat(metres)
        fuelDial.value = CGFloat(practice.fuelShare(at: localSeat))
        let left = Int(me.fuel.rounded(.down))
        fuelLabel.text = String(
            localized: "\(left / 60):\(left % 60, specifier: "%02d") fuel", bundle: .module)
        fuelLabel.fontColor =
            practice.fuelShare(at: localSeat) < 0.2
            ? SKColor(red: 0.75, green: 0.1, blue: 0.1, alpha: 1) : hudInk
        speedLabel.text = String(localized: "\(kmh) km/h", bundle: .module)
        altitudeLabel.text = String(localized: "\(metres) m", bundle: .module)
        let seconds = practice.elapsed.formatted(.number.precision(.fractionLength(1)))
        if practice.mode == .duckfight {
            let left = max(0, practice.duckfight.duration - practice.elapsed)
            countLabel.text = String(
                localized: "\(Int(left) / 60):\(Int(left) % 60, specifier: "%02d") left",
                bundle: .module)
            clockLabel.text = String(
                localized: "\(me.kills) downed, \(me.downs) down", bundle: .module)
        } else if practice.mode == .courier {
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
        roundTally.update(count: me.ammo)
        updateAmmo()
        minimap.update(practice, seat: localSeat)
        statusLabel.text = status(at: now)
    }

    /// Rounds left; red and a hint when the belt is empty, a note while it loads.
    private func updateAmmo() {
        // The belt is the row of rounds; words only when there is something to say.
        if me.ammo == 0 && !practice.isRearming(at: localSeat) {
            ammoLabel.text = String(localized: "Out of rounds: land to rearm", bundle: .module)
            ammoLabel.fontColor = SKColor(red: 0.75, green: 0.1, blue: 0.1, alpha: 1)
        } else if practice.isRearming(at: localSeat) {
            ammoLabel.text = String(localized: "Rearming", bundle: .module)
            ammoLabel.fontColor = hudInk
        } else {
            ammoLabel.text = ""
        }
    }

    private func status(at now: TimeInterval) -> String {
        if let flash, now < flash.until { return flash.text }
        switch me.phase {
        case .approach:
            return String(localized: "Landing", bundle: .module)
        case .parked(let repair) where repair > 0:
            return String(localized: "Repairing", bundle: .module)
        case _ where me.down:
            return String(
                localized: "Back in \(Int((me.respawnIn ?? 0).rounded(.up)))", bundle: .module)
        case .parked
        where practice.isRefuelling(at: localSeat) || practice.isRearming(at: localSeat):
            return practice.isRefuelling(at: localSeat)
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
        let plane = me.plane
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

    func place(
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
