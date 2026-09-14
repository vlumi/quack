import Foundation

/// A stretch of flat ground you can land on and take off from.
public struct Airfield: Equatable, Sendable {
    /// The x of the left end, in metres.
    public var start: Double
    public var length: Double

    public init(start: Double, length: Double) {
        self.start = start
        self.length = length
    }

    public var end: Double { start + length }

    public func contains(_ x: Double) -> Bool { x >= start && x <= end }
}

/// The dials for landing and taking off. Angles are in degrees below the
/// horizon, because that is how they are tuned and read.
public struct LandingTuning: Equatable, Sendable {
    /// The glide path the assist flies down, degrees below the horizon.
    public var approachAngle: Double = 8
    /// How far off the approach angle, either way, still engages the assist:
    /// the difficulty dial.
    public var approachBand: Double = 5
    /// Metres above the ground below which the assist can take over.
    public var engageHeight: Double = 15
    /// Degrees steeper than the band that still only bounce; the same again
    /// breaks the undercarriage; steeper than that is a crash.
    public var bounceMargin: Double = 6
    /// Metres per second squared of braking on the rollout.
    public var braking: Double = 10
    /// Seconds a broken undercarriage keeps the plane on the ground.
    public var repairTime: Double = 3
    /// Seconds a wreck stays on screen before the plane is back on the field.
    public var wreckTime: Double = 1.5
    /// Metres from the wheels to the plane's centre.
    public var gearHeight: Double = 1.7
    /// Elevator beyond which the pilot takes the landing back from the assist.
    public var abortPitch: Double = 0.6

    public init() {}
}

/// Where the plane is in the business of flying, landing and taking off.
public enum FlightPhase: Equatable, Sendable {
    /// Hand flown, in the air.
    case flying
    /// The assist is flying the approach.
    case approach
    /// On the ground after touchdown, braking to a stop; `repair` is what the
    /// stop will cost if the undercarriage broke.
    case rollout(repair: Double)
    /// Stopped on the field. Pull up to take off once `repair` has run down.
    case parked(repair: Double)
    /// On the ground, throttle open, accelerating to take off.
    case takeoffRoll
    /// Crashed; back on the field when `remaining` runs out.
    case wrecked(remaining: Double)

    public var isOnGround: Bool {
        switch self {
        case .rollout, .parked, .takeoffRoll: return true
        case .flying, .approach, .wrecked: return false
        }
    }
}

/// Something that happened this tick, for the scene to show.
public enum FlightEvent: Equatable, Sendable {
    case assistEngaged
    case assistAborted
    case touchdown
    case bounce
    case brokenUndercarriage
    case crash
    case parked
    case liftoff
    case backOnField
}

extension PlaneState {
    /// Cockpit up on screen: right way up for the direction of flight.
    public var upright: Bool { inverted == (cos(heading) < 0) }

    /// +1 flying (or facing) right, -1 left.
    public var direction: Double { cos(heading) < 0 ? -1 : 1 }

    /// The angle of the path above the horizon, whichever way the plane is going.
    public var pathAngle: Double { atan2(sin(heading), abs(cos(heading))) }
}

/// Landing, rollout, takeoff and crashing: everything that happens where the
/// plane meets the ground. Wraps `FlightModel`, which only knows the air.
/// Deterministic like it.
public struct AirfieldModel: Equatable, Sendable {
    public var flight: FlightModel
    public var landing: LandingTuning
    public var airfield: Airfield

    public init(
        flight: FlightModel = FlightModel(), landing: LandingTuning = LandingTuning(),
        airfield: Airfield
    ) {
        self.flight = flight
        self.landing = landing
        self.airfield = airfield
    }

    /// Where a plane waits at the start and comes back to after a crash.
    public var parkingSpot: PlaneState {
        PlaneState(x: airfield.start + 12, y: landing.gearHeight, heading: 0, speed: 0)
    }

    /// Speed at which a plane on the takeoff roll can lift off.
    public var rotateSpeed: Double { flight.tuning.stallSpeed * 1.25 }

    /// One fixed step. Returns what happened, if anything.
    public func advance(
        _ s: inout PlaneState, _ phase: inout FlightPhase, input: PlaneInput,
        dt: Double = FlightModel.dt
    ) -> FlightEvent? {
        switch phase {
        case .flying:
            s = flight.advance(s, input: input, dt: dt)
            if s.y <= landing.gearHeight { return touchGround(&s, &phase) }
            if shouldEngage(s) {
                phase = .approach
                return .assistEngaged
            }
            return nil
        case .approach:
            if abs(input.pitch) >= landing.abortPitch {
                phase = .flying
                s = flight.advance(s, input: input, dt: dt)
                return .assistAborted
            }
            return flyApproach(&s, &phase, dt: dt)
        case .rollout(let repair):
            return roll(&s, &phase, repair: repair, dt: dt)
        case .parked(let repair):
            startTakeoff(&s, &phase, repair: repair, input: input, dt: dt)
            return nil
        case .takeoffRoll:
            return takeoffRoll(&s, &phase, input: input, dt: dt)
        case .wrecked(let remaining):
            return recover(&s, &phase, remaining: remaining, dt: dt)
        }
    }

    /// Parked: wait out any repair, then a pull on the stick starts the roll,
    /// turned to face the longer side of the field.
    private func startTakeoff(
        _ s: inout PlaneState, _ phase: inout FlightPhase, repair: Double, input: PlaneInput,
        dt: Double
    ) {
        if repair > 0 {
            phase = .parked(repair: max(0, repair - dt))
        } else if input.pitch > 0 {
            let dir: Double = airfield.end - s.x >= s.x - airfield.start ? 1 : -1
            s.heading = dir > 0 ? 0 : .pi
            s.inverted = dir < 0
            phase = .takeoffRoll
        }
    }

    private func recover(
        _ s: inout PlaneState, _ phase: inout FlightPhase, remaining: Double, dt: Double
    )
        -> FlightEvent?
    {
        if remaining - dt > 0 {
            phase = .wrecked(remaining: remaining - dt)
            return nil
        }
        s = parkingSpot
        phase = .parked(repair: 0)
        return .backOnField
    }

    // MARK: The approach

    private func shouldEngage(_ s: PlaneState) -> Bool {
        let height = s.y - landing.gearHeight
        let gamma = s.pathAngle
        let wanted = -radians(landing.approachAngle)
        guard s.upright, height > 0, height <= landing.engageHeight, gamma < 0,
            abs(gamma - wanted) <= radians(landing.approachBand)
        else { return false }
        // Where the path meets the ground must leave room to stop on the field.
        let touchdown = s.x + s.direction * height / tan(-gamma)
        let room = rolloutRoom
        return s.direction > 0
            ? touchdown >= airfield.start && touchdown <= airfield.end - room
            : touchdown <= airfield.end && touchdown >= airfield.start + room
    }

    /// Metres a plane needs to stop from a touchdown at landing speed.
    private var rolloutRoom: Double {
        let v = landingSpeed
        return v * v / (2 * landing.braking) + 5
    }

    private var landingSpeed: Double { flight.tuning.stallSpeed * 1.2 }

    /// The assist flies a kinematic glide down the approach angle, easing the
    /// speed toward landing speed and flaring in the last few metres.
    private func flyApproach(_ s: inout PlaneState, _ phase: inout FlightPhase, dt: Double)
        -> FlightEvent?
    {
        let height = s.y - landing.gearHeight
        let flareHeight = 3.0
        let approach = radians(landing.approachAngle)
        let target = -approach * max(0.3, min(1, height / flareHeight))
        var gamma = s.pathAngle
        gamma += max(-dt, min(dt, target - gamma))
        s.speed += max(-4 * dt, min(4 * dt, landingSpeed - s.speed))
        let dir = s.direction
        s.heading = dir > 0 ? gamma : .pi - gamma
        s.heading = FlightModel.wrap(s.heading)
        s.inverted = dir < 0
        s.x += dir * cos(gamma) * s.speed * dt
        s.y += sin(gamma) * s.speed * dt
        if s.y <= landing.gearHeight {
            level(&s)
            phase = .rollout(repair: 0)
            return .touchdown
        }
        return nil
    }

    // MARK: The ground

    /// The plane has reached the ground without the assist: graded by how steep.
    private func touchGround(_ s: inout PlaneState, _ phase: inout FlightPhase) -> FlightEvent {
        let steepness = degrees(-s.pathAngle)
        let window = landing.approachAngle + landing.approachBand
        guard airfield.contains(s.x), s.upright else { return crash(&s, &phase) }
        if steepness <= window {
            level(&s)
            phase = .rollout(repair: 0)
            return .touchdown
        }
        if steepness <= window + landing.bounceMargin {
            let vx = s.vx * 0.85
            let vy = -s.vy * 0.35
            s.speed = hypot(vx, vy)
            s.heading = atan2(vy, vx)
            s.y = landing.gearHeight + 0.05
            phase = .flying
            return .bounce
        }
        if steepness <= window + 2 * landing.bounceMargin {
            level(&s)
            s.speed *= 0.6
            phase = .rollout(repair: landing.repairTime)
            return .brokenUndercarriage
        }
        return crash(&s, &phase)
    }

    private func roll(_ s: inout PlaneState, _ phase: inout FlightPhase, repair: Double, dt: Double)
        -> FlightEvent?
    {
        let dir = s.direction
        let toEnd = max(0.5, dir > 0 ? airfield.end - s.x : s.x - airfield.start)
        // Brake at least hard enough to stop on the field.
        let decel = max(landing.braking, s.speed * s.speed / (2 * toEnd))
        s.speed = max(0, s.speed - decel * dt)
        s.x += dir * s.speed * dt
        s.y = landing.gearHeight
        // The fixed step can overshoot the braking arithmetic by a fraction of a metre.
        if !airfield.contains(s.x) {
            s.x = min(max(s.x, airfield.start), airfield.end)
            s.speed = 0
        }
        if s.speed == 0 {
            phase = .parked(repair: repair)
            return .parked
        }
        return nil
    }

    private func takeoffRoll(
        _ s: inout PlaneState, _ phase: inout FlightPhase, input: PlaneInput, dt: Double
    ) -> FlightEvent? {
        let t = flight.tuning
        let dir = s.direction
        s.speed = max(0, s.speed + (t.thrust - t.drag * s.speed * s.speed) * dt)
        s.x += dir * s.speed * dt
        s.y = landing.gearHeight
        if !airfield.contains(s.x) { return crash(&s, &phase) }
        if s.speed >= rotateSpeed && input.pitch > 0 {
            let climb = 0.12
            s.heading = dir > 0 ? climb : .pi - climb
            s.inverted = dir < 0
            s.y = landing.gearHeight + 0.05
            phase = .flying
            return .liftoff
        }
        return nil
    }

    private func level(_ s: inout PlaneState) {
        let dir = s.direction
        s.heading = dir > 0 ? 0 : .pi
        s.inverted = dir < 0
        s.y = landing.gearHeight
    }

    private func crash(_ s: inout PlaneState, _ phase: inout FlightPhase) -> FlightEvent {
        s.speed = 0
        s.y = max(s.y, landing.gearHeight)
        phase = .wrecked(remaining: landing.wreckTime)
        return .crash
    }

    private func radians(_ d: Double) -> Double { d * .pi / 180 }
    private func degrees(_ r: Double) -> Double { r * 180 / .pi }
}
