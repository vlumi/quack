import Foundation

/// A rival pilot in the same kind of plane, flown by the sim: patrols a
/// stretch of the strip, turns on the courier when close, fires short bursts
/// along its heading, and goes down to rounds. One a courier run.
public struct Enemy: Equatable, Sendable {
    public var plane: PlaneState
    /// The stretch it patrols, metres along the strip; it turns back at the ends.
    public var patrol: ClosedRange<Double>
    /// Hits it can still take; 0 and it is falling.
    public var health: Int
    /// Seconds into the burst-and-pause cycle.
    public var fireClock: Double = 0
    /// Falling out of the sky, until the ground.
    public var falling = false
    /// Gone for the run.
    public var down = false

    public init(plane: PlaneState, patrol: ClosedRange<Double>, health: Int) {
        self.plane = plane
        self.patrol = patrol
        self.health = health
    }

    public var isFlying: Bool { !falling && !down }
}

/// How the rival flies and fights.
public struct EnemyTuning: Equatable, Sendable {
    /// Metres within which it turns on the courier.
    public var engageRange: Double = 300
    /// Metres within which it fires, when pointed at the courier.
    public var fireRange: Double = 120
    /// Radians off its heading the courier may be for it to fire.
    public var fireCone: Double = 0.18
    /// Seconds of burst, then seconds of pause.
    public var burst: Double = 0.35
    public var pause: Double = 1.2
    /// Rounds to shoot it down.
    public var health: Int = 2
    /// Metres either side of its home it patrols.
    public var patrolHalf: Double = 300
    /// Metres above the ground it keeps between, on patrol.
    public var minHeight: Double = 30
    public var maxHeight: Double = 110
    /// Metres from the rival's centre that count as a hit on it.
    public var hitRadius: Double = 2.5

    public init() {}
}

extension Practice {
    /// The rival for a courier run: half a lap from home, flying right, high.
    static func enemy(strip: Strip, tuning: EnemyTuning, health: Int) -> Enemy {
        let home = strip.airfields[0]
        let centre = strip.wrap(home.start + strip.length / 2)
        let y = strip.groundHeight(at: centre) + 70
        return Enemy(
            plane: PlaneState(x: centre, y: y, heading: 0, speed: 40),
            patrol: (centre - tuning.patrolHalf)...(centre + tuning.patrolHalf), health: health)
    }

    /// The rival's mind for one step: pursue the courier in range, else patrol
    /// the stretch, always keeping to the height band. The elevator is all it has.
    func enemyInput(_ e: Enemy) -> PlaneInput {
        let strip = model.strip
        let t = enemyTuning
        let dx = strip.offset(from: e.plane.x, to: plane.x)
        let dy = plane.y - e.plane.y
        let distance = hypot(dx, dy)
        let height = e.plane.y - strip.groundHeight(at: e.plane.x)
        let heading = e.plane.heading
        let wanted: Double
        if distance <= t.engageRange && !phase.isOnGround && height > t.minHeight * 0.5 {
            // Lead the courier a little and fly at it.
            let lead = distance / max(1, e.plane.speed + 60)
            wanted = atan2(dy + plane.vy * lead, dx + plane.vx * lead)
        } else {
            // Patrol: along the stretch, turning back at its ends, within the band.
            let along = strip.offset(from: e.patrol.lowerBound, to: e.plane.x)
            let span = e.patrol.upperBound - e.patrol.lowerBound
            let way: Double
            if along <= 0 {
                way = 1
            } else if along >= span {
                way = -1
            } else {
                way = e.plane.direction
            }
            let climb: Double
            if height < t.minHeight {
                climb = 0.35
            } else if height > t.maxHeight {
                climb = -0.25
            } else {
                climb = 0
            }
            wanted = way > 0 ? climb : .pi - climb
        }
        // The elevator is plane-relative: inverted, a pull turns the heading the other way.
        let turn = FlightModel.shortestTurn(from: heading, to: wanted)
        let sense: Double = e.plane.inverted ? -1 : 1
        let pitch = abs(turn) < 0.03 ? 0 : min(1, max(-1, turn * 4)) * sense
        let pointed = distance <= t.fireRange && abs(turn) <= t.fireCone && !phase.isOnGround
        return PlaneInput(pitch: pitch, power: true, fire: pointed)
    }

    /// The rival's step: fly by its own input in the same air, fire bursts,
    /// take the courier's rounds, and fall when shot down.
    mutating func advanceEnemy(dt: Double) {
        guard var e = enemy, !e.down else { return }
        let strip = model.strip
        let t = enemyTuning
        if e.falling {
            e.plane.speed = max(0, e.plane.speed - 8 * dt)
            e.plane.heading = FlightModel.wrap(e.plane.heading - 2 * dt * e.plane.direction)
            e.plane.x = strip.wrap(e.plane.x + e.plane.vx * dt)
            e.plane.y += e.plane.vy * dt - 12 * dt
            if e.plane.y <= strip.surfaceHeight(at: e.plane.x) + 1 {
                e.down = true
                hazardEvent = .enemyDown
            }
            enemy = e
            return
        }
        let input = enemyInput(e)
        e.plane = model.flight.advance(e.plane, input: input, dt: dt)
        e.plane.x = strip.wrap(e.plane.x + model.wind(at: e.plane) * dt)
        // Bursts along its heading, in the courier's gun's rounds.
        e.fireClock += dt
        if e.fireClock >= t.burst + t.pause { e.fireClock = 0 }
        if input.fire, e.fireClock < t.burst, enemyCooldown == 0 {
            let m = e.plane.muzzle(gun)
            enemyBullets.append(
                Bullet(
                    x: m.x, y: m.y,
                    vx: e.plane.vx + cos(e.plane.heading) * gun.muzzleSpeed,
                    vy: e.plane.vy + sin(e.plane.heading) * gun.muzzleSpeed))
            enemyCooldown = gun.fireInterval
        }
        enemyCooldown = max(0, enemyCooldown - dt)
        // The courier's rounds.
        if let hit = bullets.firstIndex(where: {
            dist2($0.x, $0.y, e.plane.x, e.plane.y) < t.hitRadius * t.hitRadius
        }) {
            bullets.remove(at: hit)
            e.health -= 1
            if e.health <= 0 {
                e.falling = true
                hazardEvent = .enemyHit(down: true)
            } else {
                hazardEvent = .enemyHit(down: false)
            }
        }
        // Into a hill, and it is gone too.
        if e.plane.y - model.landing.gearHeight <= strip.surfaceHeight(at: e.plane.x) {
            e.falling = true
        }
        enemy = e
    }

    /// The rival's rounds fly like the courier's and burst on the courier.
    mutating func advanceEnemyBullets(dt: Double) {
        let strip = model.strip
        let plane = self.plane
        let canBeHit = !phase.isOnGround
        let radius = hazardTuning.burstRadius
        var hit = false
        for i in enemyBullets.indices {
            enemyBullets[i].x = strip.wrap(enemyBullets[i].x + enemyBullets[i].vx * dt)
            enemyBullets[i].y += enemyBullets[i].vy * dt
            enemyBullets[i].age += dt
        }
        let life = gun.bulletLife
        enemyBullets.removeAll { b in
            let dx = strip.offset(from: b.x, to: plane.x)
            let dy = b.y - plane.y
            if canBeHit, dx * dx + dy * dy < radius * radius {
                hit = true
                return true
            }
            return b.age >= life || b.y < strip.surfaceHeight(at: b.x)
        }
        if hit {
            hits += 1
            repairDue += hazardTuning.repairPerHit
            hazardEvent = .hit(x: plane.x, y: plane.y)
        }
    }
}
