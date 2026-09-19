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
        let height = e.plane.y - model.strip.groundHeight(at: e.plane.x)
        let t = rivalTuning
        var pointed = false
        let wanted: Double
        if let target = nearestHuman(to: e), height > t.minHeight * 0.5,
            let pursuit = pursuitHeading(of: e, at: target)
        {
            wanted = pursuit.heading
            pointed = pursuit.inRange
        } else {
            wanted = patrolHeading(of: e, height: height)
        }
        return PlaneInput(pitch: elevator(of: e, toward: wanted), power: true, fire: pointed)
    }

    /// The heading at a human within engage range, led a little, and whether
    /// it is close and dead ahead enough to fire at.
    private func pursuitHeading(of e: Pilot, at target: Pilot) -> (heading: Double, inRange: Bool)?
    {
        let t = rivalTuning
        let dx = model.strip.offset(from: e.plane.x, to: target.plane.x)
        let dy = target.plane.y - e.plane.y
        let distance = hypot(dx, dy)
        guard distance <= t.engageRange else { return nil }
        let lead = distance / max(1, e.plane.speed + 60)
        let heading = atan2(dy + target.plane.vy * lead, dx + target.plane.vx * lead)
        let turn = FlightModel.shortestTurn(from: e.plane.heading, to: heading)
        return (heading, distance <= t.fireRange && abs(turn) <= t.fireCone)
    }

    /// Along the stretch, turning back at its ends, climbing or descending
    /// back into the height band.
    private func patrolHeading(of e: Pilot, height: Double) -> Double {
        let t = rivalTuning
        let along = model.strip.offset(from: e.patrol.lowerBound, to: e.plane.x)
        let span = e.patrol.upperBound - e.patrol.lowerBound
        let way: Double = along <= 0 ? 1 : (along >= span ? -1 : e.plane.direction)
        let climb: Double = height < t.minHeight ? 0.35 : (height > t.maxHeight ? -0.25 : 0)
        return way > 0 ? climb : .pi - climb
    }

    /// The elevator that turns the plane toward `wanted`, in the plane's own
    /// sense: inverted, a pull turns the heading the other way.
    private func elevator(of e: Pilot, toward wanted: Double) -> Double {
        let turn = FlightModel.shortestTurn(from: e.plane.heading, to: wanted)
        guard abs(turn) >= 0.03 else { return 0 }
        let sense: Double = e.plane.inverted ? -1 : 1
        return min(1, max(-1, turn * 4)) * sense
    }

    /// Every rival's step: fly by its own mind in the same air, fire bursts,
    /// take the humans' rounds, and fall when shot down.
    mutating func advanceRivals(dt: Double) {
        for i in pilots.indices where pilots[i].brain == .rival {
            advanceRival(at: i, dt: dt)
        }
    }

    private mutating func advanceRival(at i: Int, dt: Double) {
        if pilots[i].falling || pilots[i].down {
            fall(at: i, dt: dt)
            return
        }
        var e = pilots[i]
        let input = rivalInput(e)
        e.plane = model.flight.advance(e.plane, input: input, dt: dt)
        e.plane.x = model.strip.wrap(e.plane.x + model.wind(at: e.plane) * dt)
        fireBurst(&e, wanting: input.fire, dt: dt)
        takeHumansRounds(&e)
        if e.plane.y - model.landing.gearHeight <= model.strip.surfaceHeight(at: e.plane.x) {
            e.falling = true
        }
        pilots[i] = e
    }

    /// Bursts along its heading, in the same rounds as the humans' guns.
    private func fireBurst(_ e: inout Pilot, wanting fire: Bool, dt: Double) {
        let t = rivalTuning
        e.fireClock += dt
        if e.fireClock >= t.burst + t.pause { e.fireClock = 0 }
        if fire, e.fireClock < t.burst, e.gunCooldown == 0 {
            let m = e.plane.muzzle(gun)
            e.bullets.append(
                Bullet(
                    x: m.x, y: m.y,
                    vx: e.plane.vx + cos(e.plane.heading) * gun.muzzleSpeed,
                    vy: e.plane.vy + sin(e.plane.heading) * gun.muzzleSpeed))
            e.gunCooldown = gun.fireInterval
        }
        e.gunCooldown = max(0, e.gunCooldown - dt)
    }

    /// Any human's round on the rival takes its health; the last one drops it
    /// and credits the shooter.
    private mutating func takeHumansRounds(_ e: inout Pilot) {
        let radius = rivalTuning.hitRadius
        for j in pilots.indices where pilots[j].brain == .human {
            guard
                let hit = pilots[j].bullets.firstIndex(where: {
                    dist2($0.x, $0.y, e.plane.x, e.plane.y) < radius * radius
                })
            else { continue }
            pilots[j].bullets.remove(at: hit)
            e.health -= 1
            if e.health <= 0 {
                e.falling = true
                e.downs += 1
                pilots[j].kills += 1
            }
            hazardEvent = .rivalHit(down: e.health <= 0)
        }
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
