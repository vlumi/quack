import Foundation

/// Landing, rollout, takeoff and crashing: everything that happens where the
/// plane meets the ground. Wraps `FlightModel`, which only knows the air.
/// Deterministic like it.
///
/// The world is a `Strip` that wraps. Each step works on an image of the field
/// that matters, moved by whole laps to sit near the plane, so the arithmetic
/// below reads as if the strip were straight; distances that must survive the
/// plane's position being wrapped between steps go through `strip.offset`.
public struct AirfieldModel: Equatable, Sendable {
    public var flight: FlightModel
    public var landing: LandingTuning
    public var strip: Strip

    public init(
        flight: FlightModel = FlightModel(), landing: LandingTuning = LandingTuning(), strip: Strip
    ) {
        self.flight = flight
        self.landing = landing
        self.strip = strip
    }

    /// One field on a strip far too long to wrap in a test.
    public init(
        flight: FlightModel = FlightModel(), landing: LandingTuning = LandingTuning(),
        airfield: Airfield
    ) {
        self.init(
            flight: flight, landing: landing, strip: Strip(length: 1_000_000, airfields: [airfield])
        )
    }

    /// The home field: where a run starts.
    public var home: Airfield { strip.airfields[0] }

    /// Where a plane waits at the start and comes back to after a crash.
    public var parkingSpot: PlaneState {
        PlaneState(x: home.start + 6, y: home.elevation + landing.gearHeight, heading: 0, speed: 0)
    }

    /// Metres from the plane's wheels down to the ground under it.
    public func clearance(_ s: PlaneState) -> Double {
        s.y - landing.gearHeight - strip.groundHeight(at: s.x)
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
            parked(&s, &phase, repair: repair, input: input, dt: dt)
            return nil
        case .taxiing(let steps, let thenTakeoff):
            taxi(&s, &phase, steps: steps, thenTakeoff: thenTakeoff, dt: dt)
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
        if clearance(s) <= 0 { return touchGround(&s, &phase) }
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

    // MARK: The approach

    /// Whether the plane is inside the approach cone at the end of the field it
    /// is flying toward: a wedge rising from that end at the approach angle
    /// ± band, `coneLength` long, with a low throat over the threshold.
    public func inCone(_ s: PlaneState) -> Bool {
        guard let airfield = fieldAhead(s) else { return false }
        let height = s.y - landing.gearHeight - airfield.elevation
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

    /// The field whose approach end is ahead of the plane within the cone's reach,
    /// as an image near the plane.
    func fieldAhead(_ s: PlaneState) -> Airfield? {
        strip.airfields.lazy.map { strip.image(of: $0, near: s.x) }.first { field in
            let outward = s.direction > 0 ? field.start - s.x : s.x - field.end
            return outward >= -landing.throatLength && outward <= landing.coneLength
        }
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
        guard let airfield = fieldAhead(s) else { return nil }
        let dir = s.direction
        let height = s.y - landing.gearHeight - airfield.elevation
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
        return aimZone(airfield, direction: dir).contains(aim) ? aim : nil
    }

    /// The steepest glide the assist will fly, as a (negative) path angle.
    private var steepestGlide: Double { -radians(landing.approachAngle + landing.approachBand + 2) }

    /// Where a touchdown leaves room to flare and stop before the far end.
    private func aimZone(_ airfield: Airfield, direction: Double) -> ClosedRange<Double> {
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
        let elevation = strip.nearestAirfield(to: aim)?.elevation ?? 0
        let height = s.y - landing.gearHeight - elevation
        let dir = s.direction
        let steepest = steepestGlide
        let target: Double
        if height > flareHeight {
            let togo = dir * strip.offset(from: s.x, to: aim - dir * flareLength)
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
        if s.y <= landing.gearHeight + elevation {
            level(&s)
            phase = .rollout(repair: 0)
            return .touchdown
        }
        return nil
    }

    // MARK: The ground

    /// The plane has reached the ground without the assist: graded by how steep.
    func touchGround(_ s: inout PlaneState, _ phase: inout FlightPhase) -> FlightEvent {
        let steepness = degrees(-s.pathAngle)
        let window = landing.approachAngle + landing.approachBand
        guard strip.airfield(under: s.x) != nil, s.upright else { return crash(&s, &phase) }
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
            s.y = strip.groundHeight(at: s.x) + landing.gearHeight + 0.05
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

    func level(_ s: inout PlaneState) {
        let dir = s.direction
        s.heading = dir > 0 ? 0 : .pi
        s.inverted = dir < 0
        s.y = strip.groundHeight(at: s.x) + landing.gearHeight
    }

    func crash(_ s: inout PlaneState, _ phase: inout FlightPhase) -> FlightEvent {
        s.speed = 0
        s.y = max(s.y, strip.groundHeight(at: s.x) + landing.gearHeight)
        phase = .wrecked(remaining: landing.wreckTime)
        return .crash
    }

    func radians(_ d: Double) -> Double { d * .pi / 180 }
    func degrees(_ r: Double) -> Double { r * 180 / .pi }
}
