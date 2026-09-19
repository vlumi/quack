import QuackCore
import SpriteKit

/// The other seats, the guns and their shells on screen, and the guns' news.
extension FlightScene {
    /// Flash the guns' news: a hit, the engine gone, a gun knocked out.
    func show(_ event: HazardEvent, at now: TimeInterval) {
        switch event {
        case .hit(let x, let y):
            HazardArt.burst(at: CGPoint(x: x * scale, y: y * scale), scale: scale, in: hazardLayer)
            flash = (
                run.engineShotOut(at: localSeat)
                    ? String(localized: "Engine shot out: glide to a field", bundle: .module)
                    : String(localized: "Hit! Repairs due at the next stop", bundle: .module),
                now + 2
            )
        case .gunKnockedOut:
            flash = (String(localized: "Gun knocked out", bundle: .module), now + 1.5)
        case .rivalHit(let down):
            if down {
                flash = (String(localized: "Rival shot down", bundle: .module), now + 2)
            }
            if let i = run.pilots.firstIndex(where: { $0.brain == .rival }),
                let node = seatNodes[i]
            {
                HazardArt.burst(
                    at: node.position, scale: scale, in: hazardLayer, size: down ? 4 : 2)
            }
        case .rivalDown:
            if let i = run.pilots.firstIndex(where: { $0.brain == .rival }),
                let node = seatNodes[i]
            {
                HazardArt.burst(at: node.position, scale: scale, in: hazardLayer, size: 6)
            }
        case .downed(let seat, let by):
            let at = seat == localSeat ? planeNode.position : seatNodes[seat]?.position ?? .zero
            HazardArt.burst(at: at, scale: scale, in: hazardLayer, size: 4)
            if seat == localSeat {
                flash = (String(localized: "Shot down", bundle: .module), now + 2)
            } else if by == localSeat {
                flash = (String(localized: "Got them", bundle: .module), now + 2)
            }
        }
    }

    /// A gun node per gun for the run, in the hour's light.
    func resetHazards() {
        gunNodes.forEach { $0.removeFromParent() }
        gunNodes = run.guns.map { _ in
            let n = HazardArt.gunNode(scale: scale, palette: look.palette)
            hazardLayer.addChild(n)
            return n
        }
    }

    /// A plane node, rounds and a chevron for every seat but this one, for the run.
    func resetSeats() {
        seatNodes.values.forEach { $0.removeFromParent() }
        seatBulletNodes.values.forEach { $0.forEach { $0.removeFromParent() } }
        seatMarkers.values.forEach { $0.removeFromParent() }
        seatNodes = [:]
        seatBulletNodes = [:]
        seatMarkers = [:]
        for (i, p) in run.pilots.enumerated() where i != localSeat {
            let livery: Livery = p.brain == .rival ? .rival : (i % 2 == 0 ? .courier : .duck)
            let node = PlaneNode(livery: livery, pointsPerMetre: scale)
            hazardLayer.addChild(node)
            seatNodes[i] = node
            let colour =
                p.brain == .rival
                ? SKColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1)
                : SKColor(red: 0.2, green: 0.45, blue: 0.9, alpha: 1)
            let marker = SceneArt.markerNode(scale: scale, colour: colour)
            markerLayer.addChild(marker)
            seatMarkers[i] = marker
            seatBulletNodes[i] = []
        }
    }

    /// Every other seat at its lap nearest the plane, its rounds, and its chevron.
    func placeSeats(near: (Double) -> CGFloat) {
        let strip = run.model.strip
        for (i, node) in seatNodes {
            let p = run.pilots[i]
            node.isHidden = p.down
            seatMarkers[i]?.isHidden = true
            guard !p.down else { continue }
            node.position = CGPoint(x: near(p.plane.x), y: p.plane.y * scale)
            node.zRotation = CGFloat(p.plane.heading)
            node.roll = p.plane.inverted ? .pi : 0
            node.alpha = p.falling ? 0.8 : 1
            var nodes = seatBulletNodes[i] ?? []
            while nodes.count < p.bullets.count {
                let n = SceneArt.tracerNode(scale: scale)
                hazardLayer.addChild(n)
                nodes.append(n)
            }
            for (k, n) in nodes.enumerated() {
                if k < p.bullets.count {
                    let b = p.bullets[k]
                    n.isHidden = false
                    n.position = CGPoint(x: near(b.x), y: b.y * scale)
                    n.zRotation = atan2(b.vy, b.vx)
                    n.children.first?.xScale = CGFloat(min(1, b.age * 10))
                } else {
                    n.isHidden = true
                }
            }
            seatBulletNodes[i] = nodes
            if let marker = seatMarkers[i] {
                place(
                    marker, at: me.plane.x + strip.offset(from: me.plane.x, to: p.plane.x),
                    p.plane.y, hidden: !p.isFlying, from: me.plane)
            }
        }
    }

    /// A guest draws the host's word, so its events are read off the
    /// differences: a plane's health falling is a hit, a seat falling is down.
    func showDifferences(from snapshot: FightSnapshot, at now: TimeInterval) {
        defer { lastSeats = snapshot.seats }
        guard lastSeats.count == snapshot.seats.count else { return }
        for (i, pair) in zip(lastSeats, snapshot.seats).enumerated() {
            let (was, seat) = pair
            if seat.health < was.health {
                let at = i == localSeat ? planeNode.position : seatNodes[i]?.position ?? .zero
                HazardArt.burst(at: at, scale: scale, in: hazardLayer, size: 2)
            }
            if seat.doing == .falling && was.doing != .falling {
                show(.downed(seat: i, by: nil), at: now)
            }
        }
    }

    /// Guns at their lap nearest the plane, barrels on it; shells re-laid each frame.
    func placeHazards(near: (Double) -> CGFloat) {
        let strip = run.model.strip
        let planePoint = planeNode.position
        for (node, gun) in zip(gunNodes, run.guns) {
            node.position = CGPoint(
                x: near(gun.x), y: CGFloat(strip.groundHeight(at: gun.x)) * scale)
            HazardArt.aim(node, at: planePoint, alive: gun.isAlive)
        }
        while shellNodes.count < run.shells.count {
            let n = HazardArt.shellNode(scale: scale)
            hazardLayer.addChild(n)
            shellNodes.append(n)
        }
        for (i, n) in shellNodes.enumerated() {
            if i < run.shells.count {
                let s = run.shells[i]
                n.isHidden = false
                n.position = CGPoint(x: near(s.x), y: s.y * scale)
                n.zRotation = atan2(s.vy, s.vx)
            } else {
                n.isHidden = true
            }
        }
    }
}
