import XCTest

@testable import QuackCore

final class AirfieldTests: XCTestCase {
    let field = Airfield(start: 0, length: 160)
    var model: AirfieldModel { AirfieldModel(airfield: field) }
    var gear: Double { model.landing.gearHeight }

    /// Steps until `stop` returns true or `seconds` run out; returns every event, in order.
    @discardableResult
    func fly(
        _ s: inout PlaneState, _ phase: inout FlightPhase, input: PlaneInput = .idle,
        seconds: Double,
        until stop: (PlaneState, FlightPhase) -> Bool = { _, _ in false }
    ) -> [FlightEvent] {
        var events: [FlightEvent] = []
        for _ in 0..<Int(seconds * 60) {
            if let e = model.advance(&s, &phase, input: input) { events.append(e) }
            if stop(s, phase) { break }
        }
        return events
    }

    /// A plane descending at `degrees` below the horizon, `height` metres above the wheels.
    func descending(
        x: Double, height: Double, degrees: Double, leftward: Bool = false, speed: Double = 30
    )
        -> PlaneState
    {
        let g = degrees * .pi / 180
        return PlaneState(
            x: x, y: gear + height, heading: leftward ? .pi + g : -g, speed: speed,
            inverted: leftward)
    }

    // MARK: Helpers on the plane

    func testUprightDirectionAndPathAngle() {
        let right = PlaneState(heading: -0.1, inverted: false)
        XCTAssertTrue(right.upright)
        XCTAssertEqual(right.direction, 1)
        XCTAssertEqual(right.pathAngle, -0.1, accuracy: 1e-12)
        let left = PlaneState(heading: .pi + 0.1, inverted: true)
        XCTAssertTrue(left.upright)
        XCTAssertEqual(left.direction, -1)
        XCTAssertEqual(left.pathAngle, -0.1, accuracy: 1e-9, "descending, whichever way it flies")
        XCTAssertFalse(PlaneState(heading: 0, inverted: true).upright)
        XCTAssertTrue(field.contains(0) && field.contains(160) && !field.contains(-0.1))
        XCTAssertEqual(field.end, 160)
    }

    // MARK: Taking off

    func testParkedPlaneWaitsThenPullUpRollsAndLiftsOffOnlyWhenFastEnough() {
        var s = model.parkingSpot
        var phase = FlightPhase.parked(repair: 0)
        fly(&s, &phase, input: PlaneInput(power: true, fire: true), seconds: 1)
        XCTAssertEqual(phase, .parked(repair: 0), "the trigger does not start a takeoff")
        XCTAssertEqual(s, model.parkingSpot)

        XCTAssertNil(model.advance(&s, &phase, input: PlaneInput(pitch: 1, power: true)))
        XCTAssertEqual(phase, .takeoffRoll)
        // Rolling with the stick neutral stays on the ground past rotate speed.
        fly(&s, &phase, input: PlaneInput(power: true), seconds: 30) { s, _ in
            s.speed >= self.model.rotateSpeed
        }
        XCTAssertEqual(phase, .takeoffRoll)
        XCTAssertEqual(s.y, gear)
        let events = fly(&s, &phase, input: PlaneInput(pitch: 1, power: true), seconds: 1) { _, p in
            p == .flying
        }
        XCTAssertEqual(events, [.liftoff])
        XCTAssertGreaterThan(s.pathAngle, 0)
        XCTAssertTrue(field.contains(s.x))
    }

    func testRollingOffTheEndOfTheFieldIsACrash() {
        var s = model.parkingSpot
        var phase = FlightPhase.takeoffRoll
        let events = fly(&s, &phase, input: PlaneInput(power: true), seconds: 30) { _, p in
            p != .takeoffRoll
        }
        XCTAssertEqual(events, [.crash])
    }

    func testTakeoffTurnsToFaceTheLongerSideOfTheField() {
        var s = PlaneState(x: 150, y: gear, heading: 0, speed: 0)
        var phase = FlightPhase.parked(repair: 0)
        model.advance(&s, &phase, input: PlaneInput(pitch: 1, power: true))
        XCTAssertEqual(phase, .takeoffRoll)
        XCTAssertEqual(s.direction, -1)
        XCTAssertTrue(s.upright)
    }

    // MARK: Landing with the assist

    func testAnApproachInTheWindowIsLandedByTheAssistAndStopsOnTheField() {
        var s = descending(x: -60, height: 14, degrees: 8)
        var phase = FlightPhase.flying
        let events = fly(&s, &phase, seconds: 20) { _, p in p == .parked(repair: 0) }
        XCTAssertEqual(events, [.assistEngaged, .touchdown, .parked])
        XCTAssertTrue(field.contains(s.x))
        XCTAssertEqual(s.direction, 1)
        XCTAssertEqual(s.y, gear)
        XCTAssertEqual(s.speed, 0)
    }

    func testTheSameFromTheOtherEnd() {
        var s = descending(x: 220, height: 14, degrees: 8, leftward: true)
        var phase = FlightPhase.flying
        let events = fly(&s, &phase, seconds: 20) { _, p in p == .parked(repair: 0) }
        XCTAssertEqual(events, [.assistEngaged, .touchdown, .parked])
        XCTAssertTrue(field.contains(s.x))
        XCTAssertEqual(s.direction, -1)
        XCTAssertTrue(s.upright)
    }

    func testPullingHardHandsTheLandingBack() {
        var s = descending(x: -60, height: 14, degrees: 8)
        var phase = FlightPhase.flying
        fly(&s, &phase, seconds: 1) { _, p in
            if case .approach = p { return true }
            return false
        }
        guard case .approach = phase else { return XCTFail("the assist did not engage") }
        XCTAssertEqual(
            model.advance(&s, &phase, input: PlaneInput(pitch: 1, power: true)), .assistAborted)
        XCTAssertEqual(phase, .flying)
    }

    func testTheAssistDoesNotEngageOutsideTheWindow() {
        // Too shallow, too high, overshooting the field, or upside down. Upside
        // down needs the elevator held, or the plane rights itself on release.
        let held = PlaneInput(pitch: -0.1, power: true)
        let inverted = PlaneState(x: -60, y: gear + 14, heading: -0.14, speed: 30, inverted: true)
        struct Case {
            let name: String
            let plane: PlaneState
            var input = PlaneInput.idle
        }
        let cases = [
            Case(name: "shallow", plane: descending(x: -60, height: 14, degrees: 1)),
            Case(name: "high", plane: descending(x: -200, height: 40, degrees: 8)),
            Case(name: "long", plane: descending(x: 100, height: 14, degrees: 8)),
            Case(name: "inverted", plane: inverted, input: held),
        ]
        for c in cases {
            var s = c.plane
            var phase = FlightPhase.flying
            XCTAssertNil(model.advance(&s, &phase, input: c.input), c.name)
            XCTAssertEqual(phase, .flying, c.name)
        }
    }

    func testTheAssistTouchesDownWhereItAimed() {
        var s = descending(x: -40, height: 12, degrees: 9)
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

    func testTheAssistDoesNotEngageWhenTheAimNeedsADive() {
        // Low and close to the far part of the field: the aim is on the field,
        // but reaching it would need a far steeper glide than the assist flies.
        var s = descending(x: 130, height: 5, degrees: 13)
        var phase = FlightPhase.flying
        XCTAssertNil(model.advance(&s, &phase, input: .idle))
        XCTAssertEqual(phase, .flying)
    }

    func testTheRunsShortFieldTakesATakeoffAndALandingFromEitherEnd() {
        let short = AirfieldModel(airfield: Practice.airfield)
        let field = short.airfield
        XCTAssertLessThanOrEqual(
            field.length, 62, "fits in half the screen's width, seen from its middle")

        var s = short.parkingSpot
        var phase = FlightPhase.parked(repair: 0)
        var events: [FlightEvent] = []
        for _ in 0..<600 {
            if let e = short.advance(&s, &phase, input: PlaneInput(pitch: 1, power: true)) {
                events.append(e)
            }
            if phase == .flying { break }
        }
        XCTAssertEqual(events, [.liftoff])
        XCTAssertLessThan(s.x, field.end - 10, "lifts off with field to spare")

        for leftward in [false, true] {
            let g = 8 * Double.pi / 180
            let meet = leftward ? field.end - 20 : field.start + 20
            let dir: Double = leftward ? -1 : 1
            var p = PlaneState(
                x: meet - dir * 12 / tan(g), y: gear + 12, heading: leftward ? .pi + g : -g,
                speed: 30,
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

    func testABrokenUndercarriageKeepsThePlaneDownUntilRepaired() {
        var s = PlaneState(x: 60, y: gear, heading: 0, speed: 0)
        var phase = FlightPhase.parked(repair: 1)
        fly(&s, &phase, input: PlaneInput(pitch: 1, power: true), seconds: 0.5)
        XCTAssertNotEqual(phase, .takeoffRoll, "still under repair")
        fly(&s, &phase, input: PlaneInput(pitch: 1, power: true), seconds: 1) { _, p in
            p == .takeoffRoll
        }
        XCTAssertEqual(phase, .takeoffRoll)
    }

    func testRolloutAlwaysStopsOnTheField() {
        var s = PlaneState(x: 140, y: gear, heading: 0, speed: 40)
        var phase = FlightPhase.rollout(repair: 0)
        fly(&s, &phase, seconds: 10) { _, p in p == .parked(repair: 0) }
        XCTAssertEqual(phase, .parked(repair: 0))
        XCTAssertLessThanOrEqual(s.x, field.end)
    }

    // MARK: Crashing

    func testAWreckReturnsToTheParkingSpotAfterItsTime() {
        var s = PlaneState(x: -50, y: gear + 0.05, heading: -0.3, speed: 30)
        var phase = FlightPhase.flying
        XCTAssertEqual(model.advance(&s, &phase, input: .idle), .crash)
        let events = fly(&s, &phase, seconds: model.landing.wreckTime + 0.1) { _, p in
            p == .parked(repair: 0)
        }
        XCTAssertEqual(events, [.backOnField])
        XCTAssertEqual(s, model.parkingSpot)
        XCTAssertFalse(FlightPhase.wrecked(remaining: 1).isOnGround)
        XCTAssertTrue(
            FlightPhase.takeoffRoll.isOnGround && FlightPhase.parked(repair: 0).isOnGround)
        XCTAssertFalse(FlightPhase.approach(aim: 0).isOnGround)
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
