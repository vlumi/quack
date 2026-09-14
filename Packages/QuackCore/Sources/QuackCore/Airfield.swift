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
    /// Metres per second a plane taxis at when it moves on the ground to turn around.
    public var taxiSpeed: Double = 8
    /// Seconds to swing round to face the other way on the ground.
    public var turnTime: Double = 1
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
    /// Stopped on the field, facing the way it rolled. Once `repair` has run
    /// down, pull up to take off that way, push to turn around.
    case parked(repair: Double)
    /// Moving on the ground by itself: swinging round and taxiing to where the
    /// takeoff has room, one step at a time; rolls straight into the takeoff
    /// at the end if the pilot asked to go rather than to turn.
    case taxiing(steps: [TaxiStep], thenTakeoff: Bool)
    /// On the ground, throttle open, accelerating to take off.
    case takeoffRoll
    /// Crashed; back on the field when `remaining` runs out.
    case wrecked(remaining: Double)

    public var isOnGround: Bool {
        switch self {
        case .rollout, .parked, .taxiing, .takeoffRoll: return true
        case .flying, .approach, .goAround, .wrecked: return false
        }
    }
}

/// One move of a plane taxiing on its own.
public enum TaxiStep: Equatable, Sendable {
    /// Swinging round to face the other way; `elapsed` of `LandingTuning.turnTime`.
    case turn(elapsed: Double)
    /// Rolling at taxi speed, the way the plane faces, to `x`.
    case taxi(to: Double)
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
