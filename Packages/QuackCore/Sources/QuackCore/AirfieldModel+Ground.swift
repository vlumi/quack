import Foundation

/// The plane on the ground by itself or by the pilot's choice: parked,
/// swinging round, taxiing to room, the takeoff roll, the rollout after
/// touchdown, and coming back from a wreck.
extension AirfieldModel {
    /// Metres ahead a takeoff roll wants in still air: to rotate speed, and some for a late pull.
    public var takeoffRoom: Double { takeoffRoom(facing: 0) }

    /// Metres ahead a takeoff roll wants facing `direction`: shorter into the
    /// wind, since the plane rotates at a lower speed over the ground.
    public func takeoffRoom(facing direction: Double) -> Double {
        let over = max(0, rotateSpeed + groundWind(facing: direction))
        return over * over / (2 * landing.takeoffAcceleration) + 10
    }

    /// Metres of `airfield` ahead of `x` for a plane facing `direction`.
    func room(on airfield: Airfield, at x: Double, facing direction: Double) -> Double {
        direction > 0 ? airfield.end - x : x - airfield.start
    }

    /// Where a plane facing `direction` has just enough room to take off.
    func takeoffSpot(on airfield: Airfield, facing direction: Double) -> Double {
        let room = takeoffRoom(facing: direction)
        let spot = direction > 0 ? airfield.end - room : airfield.start + room
        return min(max(spot, airfield.start), airfield.end)
    }

    /// The field a plane on the ground is on: the one under it, or failing that
    /// (a fraction of a metre past an end) the nearest.
    func groundField(_ s: PlaneState) -> Airfield {
        strip.airfield(under: s.x) ?? strip.nearestAirfield(to: s.x) ?? home
    }

    /// Parked: wait out any repair. Then a takeoff request names the way to
    /// go: facing it already, the plane rolls, taxiing back and swinging round
    /// first if there is no room; facing the other way, it swings round, after
    /// taxiing forward to room if it needs to.
    func parked(
        _ s: inout PlaneState, _ phase: inout FlightPhase, repair: Double, input: PlaneInput,
        dt: Double
    ) {
        if repair > 0 {
            phase = .parked(repair: max(0, repair - dt))
            return
        }
        guard input.takeOff != 0 else { return }
        let way: Double = input.takeOff > 0 ? 1 : -1
        let facing = s.direction
        let airfield = groundField(s)
        let room = room(on: airfield, at: s.x, facing: way) >= takeoffRoom(facing: way)
        if way == facing {
            if room {
                phase = .takeoffRoll
            } else {
                let steps: [TaxiStep] = [
                    .turn(elapsed: 0), .taxi(to: takeoffSpot(on: airfield, facing: way)),
                    .turn(elapsed: 0),
                ]
                phase = .taxiing(steps: steps, thenTakeoff: true)
            }
        } else if room {
            phase = .taxiing(steps: [.turn(elapsed: 0)], thenTakeoff: true)
        } else {
            phase = .taxiing(
                steps: [.taxi(to: takeoffSpot(on: airfield, facing: way)), .turn(elapsed: 0)],
                thenTakeoff: true)
        }
    }

    /// One tick of a taxi plan. Inputs are ignored until it is done.
    func taxi(
        _ s: inout PlaneState, _ phase: inout FlightPhase, steps: [TaxiStep], thenTakeoff: Bool,
        dt: Double
    ) {
        var rest = steps
        s.y = strip.groundHeight(at: s.x) + landing.gearHeight
        if !rest.isEmpty {
            advance(rest.removeFirst(), &s, rest: &rest, dt: dt)
        }
        // The plan is done when nothing is left, including a plan that was empty to begin with.
        phase =
            rest.isEmpty
            ? (thenTakeoff ? .takeoffRoll : .parked(repair: 0))
            : .taxiing(steps: rest, thenTakeoff: thenTakeoff)
    }

    /// One tick of one taxi step; a step that is not finished goes back on the front of `rest`.
    private func advance(
        _ step: TaxiStep, _ s: inout PlaneState, rest: inout [TaxiStep], dt: Double
    ) {
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
            let togo = dir * strip.offset(from: s.x, to: target)
            if togo <= landing.taxiSpeed * dt {
                // Arrived; a target behind the plane never moves it backwards.
                if togo > 0 { s.x += dir * togo }
                s.speed = 0
            } else {
                s.x += dir * landing.taxiSpeed * dt
                s.speed = landing.taxiSpeed
                rest.insert(step, at: 0)
            }
        }
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
        let airfield = groundField(s)
        let toEnd = max(0.5, dir > 0 ? airfield.end - s.x : s.x - airfield.start)
        // Brake at least hard enough to stop on the field.
        let decel = max(landing.braking, s.speed * s.speed / (2 * toEnd))
        s.speed = max(0, s.speed - decel * dt)
        s.x += dir * s.speed * dt
        s.y = strip.groundHeight(at: s.x) + landing.gearHeight
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
        guard input.power else {
            // The engine has died on the roll: coast to a stop and sit there.
            s.speed = max(0, s.speed - landing.braking * dt)
            s.x += dir * s.speed * dt
            s.y = strip.groundHeight(at: s.x) + landing.gearHeight
            if s.speed == 0 { phase = .parked(repair: 0) }
            return s.speed == 0 ? .parked : nil
        }
        s.speed = min(flight.tuning.cruiseSpeed, s.speed + landing.takeoffAcceleration * dt)
        s.x += dir * s.speed * dt
        s.y = strip.groundHeight(at: s.x) + landing.gearHeight
        if strip.airfield(under: s.x) == nil { return crash(&s, &phase) }
        // Airspeed on the roll: speed over the ground less any wind from behind.
        // At rotate speed the plane lifts off by itself: the roll is the field's.
        let airspeed = s.speed - groundWind(facing: dir)
        if airspeed >= rotateSpeed {
            let climb = 0.12
            s.heading = dir > 0 ? climb : .pi - climb
            s.inverted = dir < 0
            s.y = strip.groundHeight(at: s.x) + landing.gearHeight + 0.05
            // In the air the speed is airspeed; the ground-level wind carries
            // the rest, so the plane leaves the ground at the speed it rolled.
            s.speed = airspeed
            phase = .flying
            return .liftoff
        }
        return nil
    }
}
