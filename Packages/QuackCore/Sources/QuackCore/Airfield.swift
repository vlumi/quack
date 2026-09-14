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
    /// The centre line of the approach cone, degrees above the ground from the
    /// field's end.
    public var approachAngle: Double = 8
    /// The cone's half-width in degrees: its edges rise at the approach angle
    /// ± this. The difficulty dial.
    public var approachBand: Double = 6
    /// Metres the cone reaches out from the end of the field.
    public var coneLength: Double = 50
    /// Past the end the cone keeps a throat this tall, reaching this far over
    /// the field, so a low plane crossing the threshold still counts.
    public var throatHeight: Double = 3
    public var throatLength: Double = 10
    /// Entering the cone, the path may rise this many degrees and still engage:
    /// level flight is enough, a climb is not.
    public var noseUpLimit: Double = 3
    /// …and dive at most this steeply.
    public var diveLimit: Double = 30
    /// Degrees steeper than the band that still only bounce; the same again
    /// breaks the undercarriage; steeper than that is a crash.
    public var bounceMargin: Double = 6
    /// Metres per second squared of braking on the rollout. Far harder than a
    /// real biplane's, so a landing fits on a field that fits on the screen.
    public var braking: Double = 25
    /// Metres per second squared on the takeoff roll, exaggerated the same way.
    public var takeoffAcceleration: Double = 15
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
    /// The assist is flying the approach, down to `aim` on the field.
    case approach(aim: Double)
    /// Hand flown after pulling out of an approach: the assist stays off until
    /// the plane has left the cone.
    case goAround
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
        case .flying, .approach, .goAround, .wrecked: return false
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
        PlaneState(x: airfield.start + 6, y: landing.gearHeight, heading: 0, speed: 0)
    }

    /// Speed at which a plane on the takeoff roll can lift off.
    public var rotateSpeed: Double { flight.tuning.stallSpeed * 1.25 }

    /// One fixed step. Returns what happened, if anything.
    public func advance(
        _ s: inout PlaneState, _ phase: inout FlightPhase, input: PlaneInput,
        dt: Double = FlightModel.dt
    ) -> FlightEvent? {
        switch phase {
        case .flying, .approach, .goAround:
            return advanceInAir(&s, &phase, input: input, dt: dt)
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

    /// Hand flown, assisted, or going around.
    private func advanceInAir(
        _ s: inout PlaneState, _ phase: inout FlightPhase, input: PlaneInput, dt: Double
    ) -> FlightEvent? {
        if case .approach(let aim) = phase {
            guard abs(input.pitch) >= landing.abortPitch else {
                return flyApproach(&s, &phase, aim: aim, dt: dt)
            }
            phase = .goAround
            s = flight.advance(s, input: input, dt: dt)
            return .assistAborted
        }
        s = flight.advance(s, input: input, dt: dt)
        if s.y <= landing.gearHeight { return touchGround(&s, &phase) }
        if phase == .goAround {
            if !inCone(s) { phase = .flying }
            return nil
        }
        if let aim = engagement(s) {
            phase = .approach(aim: aim)
            return .assistEngaged
        }
        return nil
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

    /// Whether the plane is inside the approach cone at the end of the field it
    /// is flying toward: a wedge rising from that end at the approach angle
    /// ± band, `coneLength` long, with a low throat over the threshold.
    public func inCone(_ s: PlaneState) -> Bool {
        let height = s.y - landing.gearHeight
        let outward = s.direction > 0 ? airfield.start - s.x : s.x - airfield.end
        guard height > 0, outward >= -landing.throatLength, outward <= landing.coneLength else {
            return false
        }
        let a = radians(landing.approachAngle)
        let b = radians(landing.approachBand)
        let along = max(0, outward)
        return height <= coneCeiling(along: along, a: a, b: b)
            && height >= coneFloor(outward: outward, a: a, b: b)
    }

    /// The cone's top at `along` metres out from the end.
    public func coneCeiling(along: Double, a: Double, b: Double) -> Double {
        max(landing.throatHeight, along * tan(a + b))
    }

    /// The cone's floor at `outward` metres from the end: the lower edge, or
    /// high enough for a flare to carry the plane onto the field, whichever is
    /// higher. Below it the assist would put the plane down short.
    public func coneFloor(outward: Double, a: Double, b: Double) -> Double {
        let along = max(0, outward)
        let flareFloor = min(flareHeight, max(0, outward + 2) * tan(radians(4)))
        return max(along * tan(max(radians(1.5), a - b)), flareFloor)
    }

    /// The touchdown point the assist will fly to, if it can take over: the plane
    /// is in the cone, upright, not climbing and not diving past the limit. It
    /// aims just past the threshold, or as close to it as it can reach without
    /// diving steeper than the cone, and only if that still leaves room to stop.
    private func engagement(_ s: PlaneState) -> Double? {
        let gamma = s.pathAngle
        guard s.upright, gamma <= radians(landing.noseUpLimit),
            gamma >= -radians(landing.diveLimit), inCone(s)
        else { return nil }
        let dir = s.direction
        let height = s.y - landing.gearHeight
        let near = dir > 0 ? airfield.start : airfield.end
        let earliest = near + dir * 5
        let reachable =
            s.x + dir * (flareLength + max(0, height - flareHeight) / tan(-steepestGlide))
        let aim = dir > 0 ? max(earliest, reachable) : min(earliest, reachable)
        // And its longest float, after pulling out of any dive, gliding at the
        // shallowest and then flaring, must reach the field.
        let outward = dir > 0 ? airfield.start - s.x : s.x - airfield.end
        let usable = height - s.speed * gamma * gamma / (2 * pullOutRate)
        let float =
            max(0, usable - flareHeight) / tan(radians(1)) + max(0, min(usable, flareHeight))
            / tan(radians(4))
        guard outward + 2 <= float else { return nil }
        return aimZone(direction: dir).contains(aim) ? aim : nil
    }

    /// The steepest glide the assist will fly, as a (negative) path angle.
    private var steepestGlide: Double { -radians(landing.approachAngle + landing.approachBand + 2) }

    /// Where a touchdown leaves room to flare and stop before the far end.
    private func aimZone(direction: Double) -> ClosedRange<Double> {
        let room = stoppingDistance + 5
        return direction > 0
            ? (airfield.start + 5)...(airfield.end - room)
            : (airfield.start + room)...(airfield.end - 5)
    }

    private var landingSpeed: Double { flight.tuning.stallSpeed * 1.2 }

    /// Metres to brake to a stop from landing speed.
    private var stoppingDistance: Double { landingSpeed * landingSpeed / (2 * landing.braking) }

    /// Radians per second the assist turns the path: quick, so a plane that dived
    /// into the cone is levelled before it meets the ground.
    private let pullOutRate = 5.0

    /// Metres the flare carries the plane past where the glide would have met the ground.
    private let flareLength = 13.0
    private let flareHeight = 0.8

    /// The assist flies a kinematic glide at the aim point, a flare's length
    /// short of it, then flares in the last metre and eases to landing speed.
    private func flyApproach(
        _ s: inout PlaneState, _ phase: inout FlightPhase, aim: Double, dt: Double
    )
        -> FlightEvent?
    {
        let height = s.y - landing.gearHeight
        let dir = s.direction
        let steepest = steepestGlide
        let target: Double
        if height > flareHeight {
            let togo = dir * (aim - dir * flareLength - s.x)
            target = min(-radians(1), max(steepest, -atan2(height - flareHeight, max(1, togo))))
        } else {
            target = -radians(4)
        }
        var gamma = s.pathAngle
        gamma += max(-pullOutRate * dt, min(pullOutRate * dt, target - gamma))
        // Hard, like the braking: a plane that dived into the cone still lands at landing speed.
        s.speed += max(-20 * dt, min(20 * dt, landingSpeed - s.speed))
        s.heading = FlightModel.wrap(dir > 0 ? gamma : .pi - gamma)
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
        let dir = s.direction
        s.speed = min(flight.tuning.cruiseSpeed, s.speed + landing.takeoffAcceleration * dt)
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
