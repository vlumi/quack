import Foundation

/// The aeroplane's physics, hand-written and deterministic: same inputs at a
/// fixed timestep give the same state, bit for bit. Thrust pushes, drag grows
/// with the square of speed, gravity trades speed for height, and the wing
/// stops flying below the stall speed. Milestone 1 is about replacing these
/// numbers with what feels right on a device. See ARCHITECTURE.md.
public struct FlightModel: Sendable {
    public static let tickRate: Double = 60
    public static let dt: Double = 1 / tickRate

    public var tuning: FlightTuning

    public init(tuning: FlightTuning = FlightTuning()) {
        self.tuning = tuning
    }

    /// One fixed step. Pitch rotates the heading; thrust and drag settle at
    /// cruise in level flight; climbing bleeds speed and diving gains it;
    /// below stall the nose drops; with the elevator released the plane rolls
    /// to the nearer way up.
    public func advance(
        _ s: PlaneState, input: PlaneInput, dt: Double = FlightModel.dt
    ) -> PlaneState {
        var p = s
        let t = tuning

        // Elevator: positive input pulls the nose up relative to the cockpit,
        // so an inverted plane pulls the other way round the circle.
        let sense: Double = p.inverted ? -1 : 1
        p.heading += input.pitch * t.pitchRate * sense * dt
        p.heading = FlightModel.wrap(p.heading)

        // Energy: thrust minus drag minus the vertical component of gravity.
        var accel = -t.drag * p.speed * p.speed - sin(p.heading) * t.gravity
        if input.power { accel += t.thrust }
        p.speed = max(0, p.speed + accel * dt)

        // Stall: too slow to fly, the nose falls toward straight down.
        if p.speed < t.stallSpeed {
            let down = -Double.pi / 2
            let toward = FlightModel.shortestTurn(from: p.heading, to: down)
            let fall = (1 - p.speed / t.stallSpeed) * t.pitchRate * dt
            p.heading = FlightModel.wrap(p.heading + min(abs(toward), fall) * (toward < 0 ? -1 : 1))
        }

        // Auto-upright: hands off the elevator and the plane rights itself.
        // Which way is "up" is decided by the direction of flight — flying
        // left with the cockpit up means inverted relative to a right-flying
        // plane, so a half loop and release completes the turn.
        if input.pitch == 0 {
            let flyingLeft = cos(p.heading) < 0
            p.inverted = flyingLeft
        }

        // Lift deficit: slower than cruise, the wing carries less and the plane
        // sinks, so a glide loses height even with the nose level.
        let deficit = 1 - min(1, p.speed / t.cruiseSpeed)
        p.x += p.vx * dt
        p.y += p.vy * dt - deficit * t.liftDeficitSink * dt
        return p
    }

    /// A heading wrapped into (-π, π].
    public static func wrap(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if a <= -.pi { a += 2 * .pi }
        if a > .pi { a -= 2 * .pi }
        return a
    }

    /// The signed shortest rotation from one heading to another.
    public static func shortestTurn(from: Double, to: Double) -> Double {
        wrap(to - from)
    }
}
