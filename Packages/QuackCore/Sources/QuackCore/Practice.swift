import Foundation

/// A balloon to shoot or ram.
public struct Balloon: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var radius: Double
    public var popped = false

    public init(x: Double, y: Double, radius: Double) {
        self.x = x
        self.y = y
        self.radius = radius
    }
}

/// The balloon run: take off from the field, pop every balloon by gun or by
/// collision, and land again. The clock starts at the first input and stops
/// when the plane is parked after the last pop. Deterministic: the balloons
/// come from the seed and the sim is fixed-step, so the same inputs give the
/// same run.
public struct Practice: Equatable, Sendable {
    public var plane: PlaneState
    public var phase: FlightPhase
    /// What happened on the last tick, for the scene to show.
    public var lastEvent: FlightEvent?
    public var bullets: [Bullet] = []
    public var balloons: [Balloon]
    public var time: Double = 0
    public var startedAt: Double?
    public var finishedAt: Double?
    public var gunCooldown: Double = 0
    /// Rounds left in the belt.
    public var ammo: Int
    /// Part of the next round loaded while parked.
    public var rearmProgress: Double = 0
    public let seed: UInt64

    public var model = AirfieldModel(airfield: Practice.airfield)
    public var gun = GunTuning()
    /// Metres from the plane's centre that count as a ram.
    public var planeRadius: Double = 1.6
    /// The field the run starts and ends on, just behind the balloons: short
    /// enough to see end to end from its middle. `Tuning.fieldLength` resizes it.
    public static let airfield = Airfield(start: -20, length: 60)

    public init(seed: UInt64, balloons count: Int = 12) {
        self.seed = seed
        plane = model.parkingSpot
        phase = .parked(repair: 0)
        balloons = Practice.field(seed: seed, count: count)
        // Every stored property is set before `capacity` reads the gun.
        ammo = 0
        ammo = capacity
    }

    /// Rounds in a full belt, from the gun's dial.
    public var capacity: Int { max(1, Int(gun.capacity.rounded())) }

    /// Loading a round at a time while parked, and not yet full.
    public var isRearming: Bool {
        guard case .parked = phase else { return false }
        return ammo < capacity
    }

    /// Balloons scattered ahead of the start, no two closer than `spacing`.
    public static func field(seed: UInt64, count: Int, spacing: Double = 28) -> [Balloon] {
        var rng = SeededRNG(seed: seed)
        var out: [Balloon] = []
        var tries = 0
        while out.count < count && tries < count * 200 {
            tries += 1
            let x = 50 + rng.unit() * 560
            let y = 18 + rng.unit() * 100
            if out.contains(where: {
                ($0.x - x) * ($0.x - x) + ($0.y - y) * ($0.y - y) < spacing * spacing
            }) {
                continue
            }
            out.append(Balloon(x: x, y: y, radius: 3))
        }
        return out
    }

    public var remaining: Int { balloons.filter { !$0.popped }.count }
    public var isFinished: Bool { finishedAt != nil }
    /// Seconds on the clock: zero before the first input, frozen at the finish.
    public var elapsed: Double {
        guard let start = startedAt else { return 0 }
        return (finishedAt ?? time) - start
    }

    /// One fixed step.
    public mutating func advance(input: PlaneInput, dt: Double = FlightModel.dt) {
        time += dt
        if startedAt == nil && input.isActive && !isFinished { startedAt = time }
        lastEvent = model.advance(&plane, &phase, input: input, dt: dt)
        if case .wrecked = phase {
            bullets.removeAll()
            return
        }

        rearm(dt: dt)
        gunCooldown = max(0, gunCooldown - dt)
        if input.fire && gunCooldown == 0 && ammo > 0 {
            ammo -= 1
            let m = plane.muzzle(gun)
            bullets.append(
                Bullet(
                    x: m.x, y: m.y,
                    vx: plane.vx + cos(plane.heading) * gun.muzzleSpeed,
                    vy: plane.vy + sin(plane.heading) * gun.muzzleSpeed))
            gunCooldown = gun.fireInterval
        }
        for i in bullets.indices {
            bullets[i].x += bullets[i].vx * dt
            bullets[i].y += bullets[i].vy * dt
            bullets[i].age += dt
        }

        for b in balloons.indices where !balloons[b].popped {
            let bl = balloons[b]
            let r2 = bl.radius * bl.radius
            let planeHit =
                Practice.dist2(plane.x, plane.y, bl.x, bl.y) < (bl.radius + planeRadius)
                * (bl.radius + planeRadius)
            if planeHit {
                balloons[b].popped = true
                continue
            }
            if let hit = bullets.firstIndex(where: { Practice.dist2($0.x, $0.y, bl.x, bl.y) < r2 })
            {
                balloons[b].popped = true
                bullets.remove(at: hit)
            }
        }
        bullets.removeAll { $0.age >= gun.bulletLife || $0.y < 0 }

        if finishedAt == nil, startedAt != nil, remaining == 0, case .parked = phase {
            finishedAt = time
        }
    }

    /// Parked on the field, the belt fills a round at a time; anywhere else the
    /// part-loaded round is lost. A belt over a lowered capacity is cut down.
    private mutating func rearm(dt: Double) {
        ammo = min(ammo, capacity)
        guard isRearming else {
            rearmProgress = 0
            return
        }
        rearmProgress += gun.rearmRate * dt
        let loaded = min(Int(rearmProgress), capacity - ammo)
        ammo += loaded
        rearmProgress -= Double(loaded)
        if ammo == capacity { rearmProgress = 0 }
    }

    /// Popped everything and still to land.
    public var needsToLand: Bool {
        guard remaining == 0, !isFinished else { return false }
        if case .parked = phase { return false }
        return true
    }

    private static func dist2(_ ax: Double, _ ay: Double, _ bx: Double, _ by: Double) -> Double {
        (ax - bx) * (ax - bx) + (ay - by) * (ay - by)
    }
}
