import Foundation

/// An anti-aircraft gun dug in beside the strip. It fires at a plane in
/// range, leading it, with a little scatter; rounds knock it out after a few
/// hits. Scenery on the ground, not solid.
public struct AAGun: Equatable, Sendable {
    /// Metres along the strip.
    public var x: Double
    /// Hits it can still take; 0 is knocked out.
    public var health: Int
    /// Seconds until it may fire again.
    public var cooldown: Double = 0

    public init(x: Double, health: Int) {
        self.x = x
        self.health = health
    }

    public var isAlive: Bool { health > 0 }
}

/// A gun's shell: flies straight, the way it was aimed, and bursts on the plane.
public struct Shell: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var age: Double = 0

    public init(x: Double, y: Double, vx: Double, vy: Double) {
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
    }
}

/// How the guns shoot and what a hit costs.
public struct HazardTuning: Equatable, Sendable {
    /// Guns on the strip in a courier run.
    public var gunCount: Int = 3
    /// Metres from a gun within which it fires.
    public var range: Double = 220
    /// Seconds between shells.
    public var fireInterval: Double = 2
    /// Metres a second a shell flies.
    public var shellSpeed: Double = 90
    /// Seconds a shell flies before it bursts harmlessly.
    public var shellLife: Double = 3.5
    /// Radians of scatter either side of the aim.
    public var scatter: Double = 0.06
    /// Metres from the plane's centre that count as a hit.
    public var burstRadius: Double = 2.2
    /// Rounds it takes to knock a gun out.
    public var gunHealth: Int = 2
    /// Seconds of repair each hit adds to the next stop.
    public var repairPerHit: Double = 4
    /// Hits that stop the engine until the next repair.
    public var hitsToStopEngine: Int = 3

    public init() {}
}

extension Practice {
    /// Guns for a courier run: `count` of them spread round the strip from the
    /// seed, off every field's shelf and approach, at least 150 m from a
    /// field's middle. The balloon run has none.
    static func guns(seed: UInt64, count: Int, strip: Strip, health: Int) -> [AAGun] {
        var rng = SeededRNG(seed: seed ^ 0xAA9_0000)
        var out: [AAGun] = []
        var tries = 0
        while out.count < count && tries < count * 100 {
            tries += 1
            let x = rng.unit() * strip.length
            let nearField = strip.airfields.contains {
                abs(strip.offset(from: x, to: $0.start + $0.length / 2)) < 150
            }
            let crowded = out.contains { abs(strip.offset(from: $0.x, to: x)) < 200 }
            if nearField || crowded { continue }
            out.append(AAGun(x: x, health: health))
        }
        return out
    }

    /// Whether the plane is too shot up to run the engine.
    public var engineShotOut: Bool { hits >= hazardTuning.hitsToStopEngine }

    /// The guns' step: each live gun in range fires a shell at where the
    /// plane will be, with scatter; shells fly, burst on the plane or the
    /// ground, and expire; rounds knock guns out.
    mutating func advanceHazards(dt: Double) {
        let strip = model.strip
        let t = hazardTuning
        for i in guns.indices where guns[i].isAlive {
            guns[i].cooldown = max(0, guns[i].cooldown - dt)
            let gx = guns[i].x
            let gy = strip.groundHeight(at: gx) + 1
            let dx = strip.offset(from: gx, to: plane.x)
            let dy = plane.y - gy
            let distance = hypot(dx, dy)
            guard distance <= t.range, guns[i].cooldown == 0, !phase.isOnGround else { continue }
            // Lead the plane: aim where it will be when the shell gets there,
            // the flight time re-taken a few times so the lead settles.
            var flight = distance / t.shellSpeed
            var aimX = dx, aimY = dy
            for _ in 0..<3 {
                aimX = dx + plane.vx * flight
                aimY = dy + plane.vy * flight
                flight = hypot(aimX, aimY) / t.shellSpeed
            }
            let scatter = (aimRNG.unit() * 2 - 1) * t.scatter
            let angle = atan2(aimY, aimX) + scatter
            shells.append(
                Shell(
                    x: gx, y: gy, vx: cos(angle) * t.shellSpeed, vy: sin(angle) * t.shellSpeed))
            guns[i].cooldown = t.fireInterval
            lastShotFrom = i
        }
        var burstAt: (Double, Double)?
        let plane = self.plane
        let canBeHit = !phase.isOnGround
        var flown = shells
        for i in flown.indices {
            flown[i].x = strip.wrap(flown[i].x + flown[i].vx * dt)
            flown[i].y += flown[i].vy * dt
            flown[i].age += dt
        }
        flown.removeAll { shell in
            let dx = strip.offset(from: shell.x, to: plane.x)
            let dy = shell.y - plane.y
            if canBeHit, dx * dx + dy * dy < t.burstRadius * t.burstRadius {
                burstAt = (shell.x, shell.y)
                return true
            }
            return shell.age >= t.shellLife || shell.y < strip.surfaceHeight(at: shell.x)
        }
        shells = flown
        if let burst = burstAt {
            hits += 1
            repairDue += t.repairPerHit
            hazardEvent = .hit(x: burst.0, y: burst.1)
        }
        knockOutGuns()
    }

    /// Rounds knock guns out.
    private mutating func knockOutGuns() {
        let strip = model.strip
        for i in guns.indices where guns[i].isAlive {
            let gx = guns[i].x
            let gy = strip.groundHeight(at: gx) + 1.5
            if let hit = bullets.firstIndex(where: { dist2($0.x, $0.y, gx, gy) < 3 * 3 }) {
                bullets.remove(at: hit)
                guns[i].health -= 1
                if !guns[i].isAlive { hazardEvent = .gunKnockedOut(i) }
            }
        }

    }

    /// Parked, the ground crew repairs the damage: the repair due becomes a
    /// parked repair, once, and the hits are mended.
    mutating func settleDamage() {
        guard case .parked(let repair) = phase, repairDue > 0 else { return }
        phase = .parked(repair: repair + repairDue)
        repairDue = 0
        hits = 0
    }
}

/// What the guns did this step.
public enum HazardEvent: Equatable, Sendable {
    case hit(x: Double, y: Double)
    case gunKnockedOut(Int)
}
