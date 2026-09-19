import XCTest

@testable import QuackCore

final class AirfieldLandingTests: AirfieldTestCase {
    // MARK: Landing with the assist

    func testTheConeIsAWedgeOverEachEndWithAThroat() {
        let right = { (x: Double, h: Double) in
            PlaneState(x: x, y: self.gear + h, heading: 0, speed: 30)
        }
        let left = { (x: Double, h: Double) in
            PlaneState(x: x, y: self.gear + h, heading: .pi, speed: 30, inverted: true)
        }
        XCTAssertTrue(model.inCone(right(-30, 5)), "out 30 m, between floor and ceiling")
        XCTAssertFalse(model.inCone(right(-30, 12)), "above the ceiling")
        XCTAssertFalse(model.inCone(right(-30, 0.5)), "below the floor")
        XCTAssertFalse(model.inCone(right(-60, 5)), "beyond the cone's length")
        XCTAssertTrue(model.inCone(right(5, 2)), "in the throat over the threshold")
        XCTAssertFalse(model.inCone(right(20, 2)), "past the throat")
        XCTAssertTrue(model.inCone(left(190, 5)), "the other end, flying the other way")
        XCTAssertFalse(model.inCone(left(-30, 5)), "the right place, flying away from the field")
    }

    func testAPlaneThatEntersTheConeIsLandedByTheAssistAndStopsOnTheField() {
        var s = descending(x: -40, height: 6, degrees: 8)
        var phase = FlightPhase.flying
        let events = fly(&s, &phase, seconds: 20) { _, p in p == .parked(repair: 0) }
        XCTAssertEqual(events, [.assistEngaged, .touchdown, .parked])
        XCTAssertTrue(field.contains(s.x))
        XCTAssertEqual(s.direction, 1)
        XCTAssertEqual(s.y, gear)
        XCTAssertEqual(s.speed, 0)
    }

    func testTheSameFromTheOtherEnd() {
        var s = descending(x: 200, height: 6, degrees: 8, leftward: true)
        var phase = FlightPhase.flying
        let events = fly(&s, &phase, seconds: 20) { _, p in p == .parked(repair: 0) }
        XCTAssertEqual(events, [.assistEngaged, .touchdown, .parked])
        XCTAssertTrue(field.contains(s.x))
        XCTAssertEqual(s.direction, -1)
        XCTAssertTrue(s.upright)
    }

    func testEnteringLevelOrDivingIsEnough() {
        for degrees in [0.0, 3, 20] {
            var s = descending(x: -30, height: 4, degrees: degrees)
            var phase = FlightPhase.flying
            XCTAssertEqual(
                model.advance(&s, &phase, input: .idle), .assistEngaged, "\(degrees)° down")
            let events = fly(&s, &phase, seconds: 20) { _, p in p == .parked(repair: 0) }
            XCTAssertEqual(events, [.touchdown, .parked], "\(degrees)° down")
            XCTAssertTrue(field.contains(s.x), "\(degrees)° down")
        }
    }

    func testTheAssistTouchesDownWhereItAimed() {
        var s = descending(x: -40, height: 6, degrees: 9)
        var phase = FlightPhase.flying
        var aim = Double.nan
        var touchdown = Double.nan
        fly(&s, &phase, seconds: 20) { s, p in
            if case .approach(let a) = p, aim.isNaN { aim = a }
            if case .rollout = p, touchdown.isNaN { touchdown = s.x }
            return p == .parked(repair: 0)
        }
        XCTAssertFalse(aim.isNaN, "engaged")
        XCTAssertEqual(touchdown, aim, accuracy: 3)
    }

    func testPullingHardHandsTheLandingBackUntilThePlaneLeavesTheCone() {
        var s = descending(x: -40, height: 6, degrees: 8)
        var phase = FlightPhase.flying
        XCTAssertEqual(model.advance(&s, &phase, input: .idle), .assistEngaged)
        XCTAssertEqual(
            model.advance(&s, &phase, input: PlaneInput(pitch: 1, power: true)), .assistAborted)
        XCTAssertEqual(phase, .goAround)
        // Level again, still in the cone: the assist stays off.
        s.heading = 0
        XCTAssertNil(model.advance(&s, &phase, input: .idle))
        XCTAssertEqual(phase, .goAround)
        // Out of the cone, it is armed again.
        s = PlaneState(x: -100, y: gear + 30, heading: 0, speed: 30)
        XCTAssertNil(model.advance(&s, &phase, input: .idle))
        XCTAssertEqual(phase, .flying)
        XCTAssertFalse(FlightPhase.goAround.isOnGround)
    }

    func testTheAssistStaysOffOutsideTheConeOrItsAttitude() {
        // Climbing, diving past the limit, or upside down (held, or it rights itself).
        let held = PlaneInput(pitch: -0.1, power: true)
        struct Case {
            let name: String
            let plane: PlaneState
            var input = PlaneInput.idle
        }
        let cases = [
            Case(name: "above the cone", plane: descending(x: -30, height: 20, degrees: 8)),
            Case(name: "beyond the cone", plane: descending(x: -80, height: 5, degrees: 8)),
            Case(name: "climbing", plane: descending(x: -30, height: 5, degrees: -10)),
            Case(name: "diving past the limit", plane: descending(x: -30, height: 5, degrees: 45)),
            Case(
                name: "inverted",
                plane: PlaneState(x: -30, y: gear + 5, heading: -0.1, speed: 30, inverted: true),
                input: held),
        ]
        for c in cases {
            var s = c.plane
            var phase = FlightPhase.flying
            XCTAssertNil(model.advance(&s, &phase, input: c.input), c.name)
            XCTAssertEqual(phase, .flying, c.name)
        }
    }

    func testTheAssistStaysOffWhenItWouldPutThePlaneDownShort() {
        // Skimming the grass just short of the field: a flare could not carry it on.
        var s = PlaneState(x: -9, y: gear + 0.9, heading: -0.3, speed: 45)
        var phase = FlightPhase.flying
        XCTAssertNotEqual(model.advance(&s, &phase, input: .idle), .assistEngaged)
    }

    func testTheRunsShortFieldTakesATakeoffAndALandingFromEitherEnd() {
        let short = AirfieldModel(airfield: Airfield(start: -20, length: Run.fieldLength))
        let field = short.home
        XCTAssertLessThanOrEqual(
            field.length, 62, "fits in half the screen's width, seen from its middle")

        var s = short.parkingSpot
        var phase = FlightPhase.parked(repair: 0)
        var events: [FlightEvent] = []
        for _ in 0..<600 {
            if let e = short.advance(&s, &phase, input: PlaneInput(power: true, takeOff: 1)) {
                events.append(e)
            }
            if phase == .flying { break }
        }
        XCTAssertEqual(events, [.liftoff])
        XCTAssertLessThan(s.x, field.end - 10, "lifts off with field to spare")

        for leftward in [false, true] {
            let dir: Double = leftward ? -1 : 1
            let near = leftward ? field.end : field.start
            // Level, 4 m up, 30 m out: in the cone.
            var p = PlaneState(
                x: near - dir * 30, y: gear + 4, heading: leftward ? .pi : 0, speed: 35,
                inverted: leftward)
            var ph = FlightPhase.flying
            var ev: [FlightEvent] = []
            var touchdown = Double.nan
            for _ in 0..<1200 {
                if let e = short.advance(&p, &ph, input: .idle) {
                    ev.append(e)
                    if e == .touchdown { touchdown = p.x }
                }
                if ph == .parked(repair: 0) { break }
            }
            XCTAssertEqual(ev, [.assistEngaged, .touchdown, .parked], "leftward \(leftward)")
            XCTAssertTrue(field.contains(touchdown) && field.contains(p.x), "leftward \(leftward)")
        }
    }

    func testALandingAcrossTheSeamWithThePositionWrappedEveryStep() {
        // The field starts just past the seam; the plane comes in from the end of
        // the strip, and its position is wrapped every step as the run does.
        let strip = Strip(length: 2400, airfields: [Airfield(start: 10, length: 60)])
        let m = AirfieldModel(strip: strip)
        var s = PlaneState(x: 2400 - 25, y: gear + 4, heading: 0, speed: 35)
        var phase = FlightPhase.flying
        var events: [FlightEvent] = []
        for _ in 0..<1200 {
            if let e = m.advance(&s, &phase, input: .idle) { events.append(e) }
            s.x = strip.wrap(s.x)
            if phase == .parked(repair: 0) { break }
        }
        XCTAssertEqual(events, [.assistEngaged, .touchdown, .parked])
        XCTAssertNotNil(strip.airfield(under: s.x))
        XCTAssertTrue((10...70).contains(s.x))
    }

    func testALandingOnARaisedFieldStopsAtItsElevation() {
        // The whole strip 30 m up: the field and its approaches with it.
        let strip = Strip(
            length: 10_000, airfields: [Airfield(start: 0, length: 60, elevation: 30)],
            heights: [30, 30, 30, 30],
            spacing: 2500)
        let m = AirfieldModel(strip: strip)
        var s = PlaneState(x: -40, y: 30 + gear + 6, heading: -8 * .pi / 180, speed: 30)
        var phase = FlightPhase.flying
        var events: [FlightEvent] = []
        for _ in 0..<1200 {
            if let e = m.advance(&s, &phase, input: .idle) { events.append(e) }
            if phase == .parked(repair: 0) { break }
        }
        XCTAssertEqual(events, [.assistEngaged, .touchdown, .parked])
        XCTAssertEqual(s.y, 30 + gear, accuracy: 1e-9)
        XCTAssertEqual(m.parkingSpot.y, 30 + gear, accuracy: 1e-9)
    }

    func testFlyingIntoAHillsideIsACrash() {
        // Ground rising to 40 m ahead of a plane flying level at 20 m.
        let strip = Strip(
            length: 10_000, airfields: [Airfield(start: 5000, length: 60)],
            heights: [0, 0, 40, 40, 0, 0, 0, 0],
            spacing: 50)
        let m = AirfieldModel(strip: strip)
        var s = PlaneState(x: 0, y: 20 + gear, heading: 0, speed: 35)
        var phase = FlightPhase.flying
        var events: [FlightEvent] = []
        for _ in 0..<600 {
            if let e = m.advance(&s, &phase, input: PlaneInput(power: true)) { events.append(e) }
            if case .wrecked = phase { break }
        }
        XCTAssertEqual(events, [.crash])
        XCTAssertGreaterThan(
            m.clearance(PlaneState(x: s.x, y: s.y + 0.01)), -1e-6, "left standing on the hill")
    }

    // MARK: Touching down by hand

    struct Graded {
        let event: FlightEvent?
        let phase: FlightPhase
        let plane: PlaneState
    }

    func grade(degrees: Double, x: Double = 80) -> Graded {
        var s = descending(x: x, height: 0.05, degrees: degrees)
        var phase = FlightPhase.flying
        let e = model.advance(&s, &phase, input: .idle)
        return Graded(event: e, phase: phase, plane: s)
    }

    func testGentleTouchdownBouncesBreaksOrCrashesByHowSteep() {
        let window = model.landing.approachAngle + model.landing.approachBand
        let margin = model.landing.bounceMargin
        XCTAssertEqual(grade(degrees: window - 2).event, .touchdown)

        let bounced = grade(degrees: window + margin / 2)
        XCTAssertEqual(bounced.event, .bounce)
        XCTAssertEqual(bounced.phase, .flying)
        XCTAssertGreaterThan(bounced.plane.pathAngle, 0, "bounced back up")

        let broke = grade(degrees: window + margin * 1.5)
        XCTAssertEqual(broke.event, .brokenUndercarriage)
        XCTAssertEqual(broke.phase, .rollout(repair: model.landing.repairTime))

        XCTAssertEqual(grade(degrees: window + margin * 3).event, .crash)
        XCTAssertEqual(grade(degrees: window - 2, x: -20).event, .crash, "off the field")
    }

    func testTouchingDownUpsideDownIsACrash() {
        // Held upside down: released, the plane would right itself first.
        var s = PlaneState(x: 80, y: gear + 0.5, heading: -0.1, speed: 30, inverted: true)
        var phase = FlightPhase.flying
        let held = PlaneInput(pitch: -0.1, power: true)
        let events = fly(&s, &phase, input: held, seconds: 2) { _, p in p != .flying }
        XCTAssertEqual(events, [.crash])
    }

    func testLandingIsDeterministic() {
        func run() -> (PlaneState, FlightPhase) {
            var s = descending(x: -60, height: 14, degrees: 9)
            var phase = FlightPhase.flying
            fly(&s, &phase, seconds: 6)
            return (s, phase)
        }
        XCTAssertEqual(run().0, run().0)
        XCTAssertEqual(run().1, run().1)
    }
}
