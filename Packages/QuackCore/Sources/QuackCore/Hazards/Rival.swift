import Foundation

/// How a rival pilot flies and fights: a seat with the rival's mind, in the
/// same kind of plane, flown by the same model with only the elevator. It
/// patrols a stretch of the strip, turns on a human in range, fires short
/// bursts along its heading, and goes down to rounds.
public struct RivalTuning: Equatable, Sendable {
    /// Metres within which it turns on a human.
    public var engageRange: Double = 300
    /// Metres within which it fires, when pointed at its target.
    public var fireRange: Double = 120
    /// Radians off its heading the target may be for it to fire.
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

extension Run {
    /// A rival seat: half a lap from home, flying right, high.
    static func makeRival(strip: Strip, tuning: RivalTuning, health: Int) -> Pilot {
        let home = strip.airfields[0]
        let centre = strip.wrap(home.start + strip.length / 2)
        let y = strip.groundHeight(at: centre) + 70
        var pilot = Pilot(
            brain: .rival, plane: PlaneState(x: centre, y: y, heading: 0, speed: 40),
            phase: .flying, ammo: 0, fuel: 0)
        pilot.patrol = (centre - tuning.patrolHalf)...(centre + tuning.patrolHalf)
        pilot.health = health
        return pilot
    }

    /// The rival seat, if the run has one. Setting it to nil takes every rival out.
    public var rival: Pilot? {
        get { pilots.first { $0.brain == .rival } }
        set {
            pilots.removeAll { $0.brain == .rival }
            if let newValue { pilots.append(newValue) }
        }
    }

    /// The rival's rounds in the air.
    public var rivalBullets: [Bullet] { pilots.first { $0.brain == .rival }?.bullets ?? [] }

    /// The nearest human seat in the air, for a rival to go for.
    func nearestHuman(to e: Pilot) -> Pilot? {
        let strip = model.strip
        return pilots.filter { $0.brain == .human && !$0.phase.isOnGround }.min {
            hypot(strip.offset(from: e.plane.x, to: $0.plane.x), $0.plane.y - e.plane.y)
                < hypot(strip.offset(from: e.plane.x, to: $1.plane.x), $1.plane.y - e.plane.y)
        }
    }

    /// The rival's mind for one step: pursue a human in range, else patrol
    /// the stretch, always keeping to the height band. The elevator is all it has.
    func rivalInput(_ e: Pilot) -> PlaneInput {
        let strip = model.strip
        let t = rivalTuning
        let height = e.plane.y - strip.groundHeight(at: e.plane.x)
        let heading = e.plane.heading
        var wanted: Double
        var pointed = false
        let target = nearestHuman(to: e)
        let dx = target.map { strip.offset(from: e.plane.x, to: $0.plane.x) } ?? .infinity
        let dy = target.map { $0.plane.y - e.plane.y } ?? 0
        let distance = hypot(dx, dy)
        if let target, distance <= t.engageRange, height > t.minHeight * 0.5 {
            // Lead the target a little and fly at it.
            let lead = distance / max(1, e.plane.speed + 60)
            wanted = atan2(dy + target.plane.vy * lead, dx + target.plane.vx * lead)
            let turn = FlightModel.shortestTurn(from: heading, to: wanted)
            pointed = distance <= t.fireRange && abs(turn) <= t.fireCone
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
        return PlaneInput(pitch: pitch, power: true, fire: pointed)
    }

    /// Every rival's step: fly by its own mind in the same air, fire bursts,
    /// take the humans' rounds, and fall when shot down.
    mutating func advanceRivals(dt: Double) {
        for i in pilots.indices where pilots[i].brain == .rival {
            advanceRival(at: i, dt: dt)
        }
    }

    private mutating func advanceRival(at i: Int, dt: Double) {
        var e = pilots[i]
        let strip = model.strip
        let t = rivalTuning
        if e.falling || e.down {
            fall(at: i, dt: dt)
            return
        }
        let input = rivalInput(e)
        e.plane = model.flight.advance(e.plane, input: input, dt: dt)
        e.plane.x = strip.wrap(e.plane.x + model.wind(at: e.plane) * dt)
        // Bursts along its heading, in the same rounds as the humans' guns.
        e.fireClock += dt
        if e.fireClock >= t.burst + t.pause { e.fireClock = 0 }
        if input.fire, e.fireClock < t.burst, e.gunCooldown == 0 {
            let m = e.plane.muzzle(gun)
            e.bullets.append(
                Bullet(
                    x: m.x, y: m.y,
                    vx: e.plane.vx + cos(e.plane.heading) * gun.muzzleSpeed,
                    vy: e.plane.vy + sin(e.plane.heading) * gun.muzzleSpeed))
            e.gunCooldown = gun.fireInterval
        }
        e.gunCooldown = max(0, e.gunCooldown - dt)
        // The humans' rounds.
        for j in pilots.indices where pilots[j].brain == .human {
            if let hit = pilots[j].bullets.firstIndex(where: {
                dist2($0.x, $0.y, e.plane.x, e.plane.y) < t.hitRadius * t.hitRadius
            }) {
                pilots[j].bullets.remove(at: hit)
                e.health -= 1
                if e.health <= 0 {
                    e.falling = true
                    e.downs += 1
                    pilots[j].kills += 1
                    hazardEvent = .rivalHit(down: true)
                } else {
                    hazardEvent = .rivalHit(down: false)
                }
            }
        }
        // Into a hill, and it is gone too.
        if e.plane.y - model.landing.gearHeight <= strip.surfaceHeight(at: e.plane.x) {
            e.falling = true
        }
        pilots[i] = e
    }

    /// Every rival's rounds fly like the humans' and burst on a human as a hit.
    mutating func advanceRivalBullets(dt: Double) {
        let strip = model.strip
        let radius = hazardTuning.burstRadius
        let life = gun.bulletLife
        let humans = targets
        for i in pilots.indices where pilots[i].brain == .rival {
            var rounds = pilots[i].bullets
            for k in rounds.indices {
                rounds[k].x = strip.wrap(rounds[k].x + rounds[k].vx * dt)
                rounds[k].y += rounds[k].vy * dt
                rounds[k].age += dt
            }
            var hitHumans: [Int] = []
            let planes = pilots.map(\.plane)
            rounds.removeAll { b in
                for j in humans {
                    let dx = strip.offset(from: b.x, to: planes[j].x)
                    let dy = b.y - planes[j].y
                    if dx * dx + dy * dy < radius * radius {
                        hitHumans.append(j)
                        return true
                    }
                }
                return b.age >= life || b.y < strip.surfaceHeight(at: b.x)
            }
            pilots[i].bullets = rounds
            for j in hitHumans {
                damage(seat: j, by: i, at: (planes[j].x, planes[j].y))
            }
        }
    }
}
