import Foundation

/// How a Duckfight is set up: who is in it, what else is on the strip, and
/// how it ends.
public struct DuckfightOptions: Equatable, Sendable {
    /// Human seats, each at its own field.
    public var humans: Int = 2
    /// Rival seats to fill the lobby, each on its own stretch.
    public var rivals: Int = 0
    /// Whether the anti-aircraft guns are dug in.
    public var guns: Bool = false
    /// Rounds a plane takes before it falls.
    public var health: Int = 2
    /// Seconds a downed seat waits before it is back at its field.
    public var respawnDelay: Double = 5
    /// Seconds the fight lasts; most kills wins.
    public var duration: Double = 300

    public init() {}
}

extension Run {
    /// Seat the fight: humans parked at their own fields round the strip,
    /// rivals patrolling the stretches between, everyone with the fight's
    /// health. The guns stay only if asked for.
    mutating func seatTheDuckfight() {
        let strip = model.strip
        let fields = strip.airfields
        let o = duckfight
        pilots = (0..<max(1, o.humans)).map { k in
            let field = fields[k % fields.count]
            var p = Pilot(
                brain: .human,
                plane: PlaneState(
                    x: field.start + 6, y: field.elevation + model.landing.gearHeight,
                    heading: 0, speed: 0),
                phase: .parked(repair: 0), ammo: capacity, fuel: fuelTuning.tank)
            p.spawnField = k % fields.count
            p.health = o.health
            return p
        }
        for k in 0..<o.rivals {
            let field = fields[k % fields.count]
            let centre = strip.wrap(field.start + strip.length / Double(fields.count) / 2)
            var r = Run.makeRival(strip: strip, tuning: rivalTuning, health: o.health)
            r.plane.x = centre
            r.plane.y = strip.groundHeight(at: centre) + 70
            r.patrol = (centre - rivalTuning.patrolHalf)...(centre + rivalTuning.patrolHalf)
            r.spawnField = k % fields.count
            pilots.append(r)
        }
        if !o.guns { guns = [] }
    }

    /// A downed seat's plane falls, nose dropping, to the ground; then it is
    /// down, and in a Duckfight the clock to come back starts.
    mutating func fall(at i: Int, dt: Double) {
        let strip = model.strip
        var e = pilots[i]
        if e.down {
            guard var wait = e.respawnIn else { return }
            wait -= dt
            if wait <= 0 {
                respawn(at: i)
            } else {
                pilots[i].respawnIn = wait
            }
            return
        }
        e.plane.speed = max(0, e.plane.speed - 8 * dt)
        e.plane.heading = FlightModel.wrap(e.plane.heading - 2 * dt * e.plane.direction)
        e.plane.x = strip.wrap(e.plane.x + e.plane.vx * dt)
        e.plane.y += e.plane.vy * dt - 12 * dt
        e.bullets.removeAll()
        if e.plane.y <= strip.surfaceHeight(at: e.plane.x) + 1 {
            e.down = true
            e.respawnIn = mode == .duckfight ? duckfight.respawnDelay : nil
            hazardEvent = e.brain == .rival ? .rivalDown : .downed(seat: i, by: nil)
        }
        pilots[i] = e
    }

    /// Back at the seat's field with everything full: a human parked, a
    /// rival flying its stretch again.
    private mutating func respawn(at i: Int) {
        let strip = model.strip
        let field = strip.airfields[pilots[i].spawnField % strip.airfields.count]
        var p = pilots[i]
        p.falling = false
        p.down = false
        p.respawnIn = nil
        p.health = duckfight.health
        p.hits = 0
        p.repairDue = 0
        p.ammo = capacity
        p.fuel = fuelTuning.tank
        p.bullets = []
        p.gunCooldown = 0
        switch p.brain {
        case .human:
            p.plane = PlaneState(
                x: field.start + 6, y: field.elevation + model.landing.gearHeight, heading: 0,
                speed: 0)
            p.phase = .parked(repair: 0)
        case .rival:
            let centre = strip.wrap(field.start + strip.length / Double(strip.airfields.count) / 2)
            p.plane = PlaneState(
                x: centre, y: strip.groundHeight(at: centre) + 70, heading: 0, speed: 40)
            p.phase = .flying
        }
        pilots[i] = p
    }

    /// Humans' rounds against every other plane in a Duckfight: a hit takes
    /// health, and the shooter is credited when the plane falls.
    mutating func advanceDuels(dt: Double) {
        guard mode == .duckfight else { return }
        let strip = model.strip
        let radius = hazardTuning.burstRadius
        let planes = pilots.map(\.plane)
        let canBeHit = pilots.indices.filter { pilots[$0].isFlying && !pilots[$0].phase.isOnGround }
        for i in pilots.indices where pilots[i].brain == .human {
            var rounds = pilots[i].bullets
            var hit: [Int] = []
            rounds.removeAll { b in
                for j in canBeHit where j != i {
                    let dx = strip.offset(from: b.x, to: planes[j].x)
                    let dy = b.y - planes[j].y
                    if dx * dx + dy * dy < radius * radius {
                        hit.append(j)
                        return true
                    }
                }
                return false
            }
            pilots[i].bullets = rounds
            for j in hit { damage(seat: j, by: i, at: (planes[j].x, planes[j].y)) }
        }
    }

    /// The Duckfight's standing: kills per seat, most first.
    public var standings: [Standing] {
        pilots.indices.map { Standing(seat: $0, kills: pilots[$0].kills, downs: pilots[$0].downs) }
            .sorted { $0.kills > $1.kills }
    }
}

/// One line of a Duckfight's standings.
public struct Standing: Equatable, Sendable {
    public let seat: Int
    public let kills: Int
    public let downs: Int
}
