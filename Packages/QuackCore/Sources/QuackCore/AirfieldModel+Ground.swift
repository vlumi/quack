import Foundation

/// The plane on the ground by itself or by the pilot's choice: parked,
/// swinging round, taxiing to room, the takeoff roll, the rollout after
/// touchdown, and coming back from a wreck.
extension AirfieldModel {
    /// Metres ahead a takeoff roll wants: to rotate speed, and some for a late pull.
    public var takeoffRoom: Double {
        rotateSpeed * rotateSpeed / (2 * landing.takeoffAcceleration) + 10
    }

    /// Metres of field ahead of `x` for a plane facing `direction`.
    func room(at x: Double, facing direction: Double) -> Double {
        direction > 0 ? airfield.end - x : x - airfield.start
    }

    /// Where a plane facing `direction` has just enough room to take off.
    func takeoffSpot(facing direction: Double) -> Double {
        let spot = direction > 0 ? airfield.end - takeoffRoom : airfield.start + takeoffRoom
        return min(max(spot, airfield.start), airfield.end)
    }

    /// Parked: wait out any repair. Then a pull takes off the way the plane
    /// faces, taxiing back first if there is no room; a push turns it around,
    /// taxiing forward first if there would be no room the other way.
    func parked(
        _ s: inout PlaneState, _ phase: inout FlightPhase, repair: Double, input: PlaneInput,
        dt: Double
    ) {
        if repair > 0 {
            phase = .parked(repair: max(0, repair - dt))
            return
        }
        let facing = s.direction
        if input.pitch > 0 {
            if room(at: s.x, facing: facing) >= takeoffRoom {
                phase = .takeoffRoll
            } else {
                let steps: [TaxiStep] = [
                    .turn(elapsed: 0), .taxi(to: takeoffSpot(facing: facing)), .turn(elapsed: 0),
                ]
                phase = .taxiing(steps: steps, thenTakeoff: true)
            }
        } else if input.pitch < 0 {
            if room(at: s.x, facing: -facing) >= takeoffRoom {
                phase = .taxiing(steps: [.turn(elapsed: 0)], thenTakeoff: false)
            } else {
                phase = .taxiing(
                    steps: [.taxi(to: takeoffSpot(facing: -facing)), .turn(elapsed: 0)],
                    thenTakeoff: false)
            }
        }
    }

    /// One tick of a taxi plan. Inputs are ignored until it is done.
    func taxi(
        _ s: inout PlaneState, _ phase: inout FlightPhase, steps: [TaxiStep], thenTakeoff: Bool,
        dt: Double
    ) {
        guard let step = steps.first else {
            phase = thenTakeoff ? .takeoffRoll : .parked(repair: 0)
            return
        }
        var rest = Array(steps.dropFirst())
        s.y = landing.gearHeight
        switch step {
        case .turn(let elapsed):
            s.speed = 0
            if elapsed + dt >= landing.turnTime {
                let dir = -s.direction
                s.heading = dir > 0 ? 0 : .pi
                s.inverted = dir < 0
            } else {
                rest.insert(.turn(elapsed: elapsed + dt), at: 0)
            }
        case .taxi(let target):
            let dir = s.direction
            let togo = dir * (target - s.x)
            if togo <= landing.taxiSpeed * dt {
                // Arrived; a target behind the plane never moves it backwards.
                if togo > 0 { s.x = target }
                s.speed = 0
            } else {
                s.x += dir * landing.taxiSpeed * dt
                s.speed = landing.taxiSpeed
                rest.insert(step, at: 0)
            }
        }
        phase =
            rest.isEmpty
            ? (thenTakeoff ? .takeoffRoll : .parked(repair: 0))
            : .taxiing(steps: rest, thenTakeoff: thenTakeoff)
    }

    func recover(
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

    // MARK: Rollout and takeoff

    func roll(_ s: inout PlaneState, _ phase: inout FlightPhase, repair: Double, dt: Double)
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

    func takeoffRoll(
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
}
