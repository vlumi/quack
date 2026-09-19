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

/// The balloon run: take off from the home field, pop every balloon round the
/// strip by gun or by collision, and land at any field. The clock starts at
/// the first input and stops when the plane is parked after the last pop.
/// Deterministic: the strip and the balloons come from the seed and the sim is
/// fixed-step, so the same inputs give the same run.
public struct Run: Equatable, Sendable {
    /// What a run is for: popping balloons, or carrying contracts between fields.
    public enum Mode: String, CaseIterable, Sendable {
        case courier
        case balloons
        /// Planes against planes: humans and rivals, downed and back, most kills wins.
        case duckfight
    }

    public let mode: Mode
    /// Every seat in the run. The first is the local player's in single player;
    /// the rest are rivals, or in a Duckfight the other players.
    public var pilots: [Pilot] = []
    public var balloons: [Balloon]
    public var time: Double = 0
    public var startedAt: Double?
    public var finishedAt: Double?

    // MARK: The first seat, which single-player code and the scene address directly.

    public var plane: PlaneState {
        get { pilots[0].plane }
        set { pilots[0].plane = newValue }
    }
    public var phase: FlightPhase {
        get { pilots[0].phase }
        set { pilots[0].phase = newValue }
    }
    /// What happened on the last tick, for the scene to show.
    public var lastEvent: FlightEvent? {
        get { pilots[0].lastEvent }
        set { pilots[0].lastEvent = newValue }
    }
    public var bullets: [Bullet] {
        get { pilots[0].bullets }
        set { pilots[0].bullets = newValue }
    }
    public var gunCooldown: Double {
        get { pilots[0].gunCooldown }
        set { pilots[0].gunCooldown = newValue }
    }
    /// Rounds left in the belt.
    public var ammo: Int {
        get { pilots[0].ammo }
        set { pilots[0].ammo = newValue }
    }
    /// Part of the next round loaded while parked.
    public var rearmProgress: Double {
        get { pilots[0].rearmProgress }
        set { pilots[0].rearmProgress = newValue }
    }
    /// Seconds of engine left in the tank.
    public var fuel: Double {
        get { pilots[0].fuel }
        set { pilots[0].fuel = newValue }
    }
    /// Hits taken since the last repair, and the repair they have earned.
    public var hits: Int {
        get { pilots[0].hits }
        set { pilots[0].hits = newValue }
    }
    public var repairDue: Double {
        get { pilots[0].repairDue }
        set { pilots[0].repairDue = newValue }
    }
    /// The company the run flies for: its upgrades, and where its money starts.
    public let career: Career
    /// The courier's day: money in the till, the contract aboard, and the offers at the field.
    public var money: Double = 0
    public var contract: Contract?
    public var acceptedAt: Double?
    public var offers: [Contract] = []
    public var chosenOffer = 0
    public var deliveries = 0
    /// How much a passenger aboard has minded the flight so far, 0 to 0.75.
    public var discomfort: Double = 0
    var lastHeading: Double = 0
    /// What happened to the courier this step, for the scene to show.
    public var courierEvent: CourierEvent?
    public let seed: UInt64
    /// The hour the run is flown at, from the seed.
    public let hour: TimeOfDay
    /// How hard this run's wind blows and which way, from the seed.
    public let windStep: WindStep
    public let windDirection: Double
    /// Clouds at the plane's depth, drifting with the wind.
    public var clouds: [Cloud]
    /// Metres the air has moved since the start.
    public var airDrift: Double = 0

    public var model: AirfieldModel
    public var gun = GunTuning()
    public var courierTuning = CourierTuning()
    public var fuelTuning = FuelTuning()
    public var hazardTuning = HazardTuning()
    /// The guns on the strip, their shells in the air, and the damage they have done.
    public var guns: [AAGun]
    public var shells: [Shell] = []
    public var hazardEvent: HazardEvent?
    /// Which gun fired last, for the scene's muzzle flash.
    public var lastShotFrom: Int?
    public var rivalTuning = RivalTuning()
    public var duckfight = DuckfightOptions()
    var aimRNG: SeededRNG
    /// Metres from the plane's centre that count as a ram.
    public var planeRadius: Double = 1.6
    /// Metres of field: short enough to see end to end from its middle.
    /// `Tuning.fieldLength` resizes the fields.
    public static let fieldLength: Double = 60
    /// Metres round the strip, and the fields along it.
    public static let stripLength: Double = 2400
    public static let fieldCount = 4

    public init(
        seed: UInt64, mode: Mode = .balloons, balloons count: Int = 12,
        fieldLength: Double = Run.fieldLength, career: Career = Career(),
        duckfight options: DuckfightOptions = DuckfightOptions()
    ) {
        self.seed = seed
        self.mode = mode
        duckfight = options
        self.career = career
        money = mode == .courier ? career.money : 0
        hour = TimeOfDay(seed: seed)
        windStep = Wind.step(seed: seed)
        windDirection = Wind.direction(seed: seed)
        let strip = Run.strip(seed: seed, fieldLength: fieldLength)
        model = AirfieldModel(strip: strip)
        balloons =
            mode == .balloons ? Run.balloons(seed: seed, count: count, strip: strip) : []
        aimRNG = SeededRNG(seed: seed ^ 0x5C47_7E12)
        guns =
            mode == .courier || (mode == .duckfight && options.guns)
            ? Run.guns(seed: seed, count: 3, strip: strip, health: 2) : []
        clouds = Wind.clouds(seed: seed, count: 7, strip: strip)
        // Every stored property is set before `capacity` reads the gun.
        pilots = [
            Pilot(
                brain: .human, plane: model.parkingSpot, phase: .parked(repair: 0),
                ammo: 0, fuel: 0)
        ]
        ammo = capacity
        fuel = fuelTuning.tank + career.tankBonus
        fuelTuning.tank = fuel
        model.flight.tuning.thrust += career.thrustBonus
        if mode == .courier {
            pilots.append(Run.makeRival(strip: strip, tuning: RivalTuning(), health: 2))
        }
        if mode == .duckfight { seatTheDuckfight() }
    }

    private static func strip(seed: UInt64, fieldLength: Double) -> Strip {
        Strip.generate(
            seed: seed, length: Run.stripLength, fields: Run.fieldCount,
            fieldLength: fieldLength)
    }

    /// Fields of a new length, each on a shelf dug for it. Balloons the new
    /// ground would bury rise clear of it, and a plane on the ground goes back
    /// to the parking spot, since the ground under it has moved.
    public mutating func resizeFields(to fieldLength: Double) {
        guard model.home.length != fieldLength else { return }
        model.strip = Run.strip(seed: seed, fieldLength: fieldLength)
        for i in balloons.indices {
            balloons[i].y = max(balloons[i].y, model.strip.groundHeight(at: balloons[i].x) + 18)
        }
        switch phase {
        case .flying, .approach, .goAround: break
        default:
            phase = .parked(repair: 0)
            plane = model.parkingSpot
        }
    }

    /// Rounds in a full belt, from the gun's dial.
    public var capacity: Int { max(1, Int(gun.capacity.rounded())) }

    /// Loading a round at a time while parked, and not yet full.
    public var isRearming: Bool { isRearming(at: 0) }

    /// Balloons scattered round the whole strip, 18 to 118 m above the ground
    /// under them but no higher than 150 m unless the hill is, no two closer than `spacing` and none within `clearance` of a
    /// field's middle, so approaches stay open.
    public static func balloons(
        seed: UInt64, count: Int, strip: Strip, spacing: Double = 28, clearance: Double = 100
    ) -> [Balloon] {
        var rng = SeededRNG(seed: seed)
        var out: [Balloon] = []
        var tries = 0
        while out.count < count && tries < count * 200 {
            tries += 1
            let x = rng.unit() * strip.length
            let ground = strip.groundHeight(at: x)
            // Out of the thinning air: no higher than 150 m unless the hill itself is.
            let y = min(ground + 18 + rng.unit() * 100, max(ground + 18, 150))
            let nearField = strip.airfields.contains {
                abs(strip.offset(from: x, to: $0.start + $0.length / 2)) < clearance
            }
            let crowded = out.contains {
                let dx = strip.offset(from: $0.x, to: x)
                return dx * dx + ($0.y - y) * ($0.y - y) < spacing * spacing
            }
            if nearField || crowded {
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

    /// One fixed step with one human at the stick: the single-player runs.
    public mutating func advance(input: PlaneInput, dt: Double = FlightModel.dt) {
        advance(inputs: [input], dt: dt)
    }

    /// One fixed step. `inputs` are the human seats' in order; a seat with no
    /// input flies idle. Every device in a lockstep game calls this with the
    /// same inputs and gets the same run.
    public mutating func advance(inputs: [PlaneInput], dt: Double = FlightModel.dt) {
        time += dt
        if startedAt == nil && inputs.contains(where: \.isActive) && !isFinished {
            startedAt = time
        }
        model.wind = wind
        advanceWeather(dt: dt)
        hazardEvent = nil
        lastShotFrom = nil
        var k = 0
        for i in pilots.indices where pilots[i].brain == .human {
            let input = k < inputs.count ? inputs[k] : .idle
            k += 1
            flyHuman(at: i, input: input, dt: dt)
        }
        advanceCourier(input: inputs.first ?? .idle)
        popBalloons()
        advanceHazards(dt: dt)
        advanceRivals(dt: dt)
        advanceRivalBullets(dt: dt)
        advanceDuels(dt: dt)
        finishTheRun()
    }

    /// Balloons the plane rams or a round hits pop; the round is spent.
    private mutating func popBalloons() {
        for b in balloons.indices where !balloons[b].popped {
            let bl = balloons[b]
            let r2 = bl.radius * bl.radius
            let planeHit =
                dist2(plane.x, plane.y, bl.x, bl.y) < (bl.radius + planeRadius)
                * (bl.radius + planeRadius)
            if planeHit {
                balloons[b].popped = true
                continue
            }
            if let hit = bullets.firstIndex(where: { dist2($0.x, $0.y, bl.x, bl.y) < r2 }) {
                balloons[b].popped = true
                bullets.remove(at: hit)
            }
        }
    }

    /// The first seat's gun: a round on the trigger when the belt and the
    /// cooldown allow, in the air only, and every round of its flown a step.
    mutating func fireAndFlyRounds(at i: Int, input: PlaneInput, dt: Double) {
        var p = pilots[i]
        p.gunCooldown = max(0, p.gunCooldown - dt)
        // The gun is for the air: parked, the trigger does nothing.
        let gunFree = !p.phase.isOnGround
        if input.fire && gunFree && p.gunCooldown == 0 && p.ammo > 0 {
            p.ammo -= 1
            let m = p.plane.muzzle(gun)
            p.bullets.append(
                Bullet(
                    x: m.x, y: m.y,
                    // Rounds fly in the moving air, as the plane does.
                    vx: p.plane.vx + wind + cos(p.plane.heading) * gun.muzzleSpeed,
                    vy: p.plane.vy + sin(p.plane.heading) * gun.muzzleSpeed))
            p.gunCooldown = gun.fireInterval
        }
        let strip = model.strip
        for k in p.bullets.indices {
            p.bullets[k].x = strip.wrap(p.bullets[k].x + p.bullets[k].vx * dt)
            p.bullets[k].y += p.bullets[k].vy * dt
            p.bullets[k].age += dt
        }
        pilots[i] = p
    }

    /// Popped everything and still to land.
    public var needsToLand: Bool {
        guard mode == .balloons, remaining == 0, !isFinished else { return false }
        if case .parked = phase { return false }
        return true
    }

    /// Squared distance, measured the shorter way round the strip.
    func dist2(_ ax: Double, _ ay: Double, _ bx: Double, _ by: Double) -> Double {
        let dx = model.strip.offset(from: ax, to: bx)
        return dx * dx + (ay - by) * (ay - by)
    }
}
