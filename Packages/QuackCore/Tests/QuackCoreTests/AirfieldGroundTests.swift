import XCTest

@testable import QuackCore

final class AirfieldGroundTests: AirfieldTestCase {
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

    func testParkedPlaneWaitsForTheTakeoffButtonThenRollsAndLiftsOffAtRotateSpeed() {
        var s = model.parkingSpot
        var phase = FlightPhase.parked(repair: 0)
        fly(&s, &phase, input: PlaneInput(pitch: 1, power: true, fire: true), seconds: 1)
        XCTAssertEqual(phase, .parked(repair: 0), "the stick and the trigger do nothing parked")
        XCTAssertEqual(s, model.parkingSpot)

        XCTAssertNil(model.advance(&s, &phase, input: PlaneInput(power: true, takeOff: 1)))
        XCTAssertEqual(phase, .takeoffRoll)
        // The roll is the field's: the plane lifts off by itself at rotate speed.
        let events = fly(&s, &phase, input: PlaneInput(power: true), seconds: 30) { _, p in
            p == .flying
        }
        XCTAssertEqual(events, [.liftoff])
        XCTAssertGreaterThanOrEqual(s.speed, model.rotateSpeed - 0.5)
        XCTAssertGreaterThan(s.pathAngle, 0)
        XCTAssertTrue(field.contains(s.x))
    }

    func testRollingOffTheEndOfTheFieldIsACrash() {
        // Rolling from too near the end to reach rotate speed before it.
        var s = PlaneState(x: field.end - 8, y: gear, heading: 0, speed: 0)
        var phase = FlightPhase.takeoffRoll
        let events = fly(&s, &phase, input: PlaneInput(power: true), seconds: 30) { _, p in
            p != .takeoffRoll
        }
        XCTAssertEqual(events, [.crash])
    }

    // MARK: Choosing the direction

    /// Steps a parked or taxiing plane with `input` held until `stop`, returning seconds taken.
    @discardableResult
    func ground(
        _ m: AirfieldModel, _ s: inout PlaneState, _ phase: inout FlightPhase, input: PlaneInput,
        seconds: Double = 20, until stop: (FlightPhase) -> Bool
    ) -> Double {
        for tick in 0..<Int(seconds * 60) {
            m.advance(&s, &phase, input: input)
            if stop(phase) { return Double(tick + 1) / 60 }
        }
        return .infinity
    }

    func testTakingOffTheWayThePlaneFacesRollsAtOnce() {
        var s = PlaneState(x: 20, y: gear, heading: 0, speed: 0)
        var phase = FlightPhase.parked(repair: 0)
        model.advance(&s, &phase, input: PlaneInput(power: true, takeOff: 1))
        XCTAssertEqual(phase, .takeoffRoll)
        XCTAssertEqual(s.direction, 1)
        var left = PlaneState(x: 140, y: gear, heading: .pi, speed: 0, inverted: true)
        phase = .parked(repair: 0)
        model.advance(&left, &phase, input: PlaneInput(power: true, takeOff: -1))
        XCTAssertEqual(phase, .takeoffRoll)
        XCTAssertEqual(left.direction, -1)
    }

    func testTakingOffTheOtherWayTurnsOnTheSpotWhenThereIsRoomBehindThenRolls() {
        var s = PlaneState(x: 80, y: gear, heading: 0, speed: 0)
        var phase = FlightPhase.parked(repair: 0)
        model.advance(&s, &phase, input: PlaneInput(power: true, takeOff: -1))
        guard case .taxiing(let steps, true) = phase, steps.count == 1, case .turn = steps[0]
        else {
            return XCTFail("expected a turn, got \(phase)")
        }
        let seconds = ground(model, &s, &phase, input: .idle) { $0 == .takeoffRoll }
        XCTAssertEqual(seconds, model.landing.turnTime, accuracy: 0.05)
        XCTAssertEqual(s.x, 80)
        XCTAssertEqual(s.direction, -1)
        XCTAssertTrue(s.upright)
    }

    func testTakingOffTheOtherWayNearAnEndTaxisOutToRoomFirst() {
        let short = AirfieldModel(airfield: Airfield(start: -20, length: Practice.fieldLength))
        var s = short.parkingSpot
        var phase = FlightPhase.parked(repair: 0)
        short.advance(&s, &phase, input: PlaneInput(power: true, takeOff: -1))
        // The pilot lets go at once: the plan runs by itself.
        let seconds = ground(short, &s, &phase, input: .idle) { $0 == .takeoffRoll }
        XCTAssertEqual(s.direction, -1)
        XCTAssertEqual(s.x - short.home.start, short.takeoffRoom, accuracy: 0.01)
        let distance = short.takeoffRoom - (short.parkingSpot.x - short.home.start)
        XCTAssertEqual(
            seconds, distance / short.landing.taxiSpeed + short.landing.turnTime, accuracy: 0.1)
        var events: [FlightEvent] = []
        for _ in 0..<600 {
            if let e = short.advance(&s, &phase, input: PlaneInput(power: true)) {
                events.append(e)
            }
            if phase == .flying { break }
        }
        XCTAssertEqual(events, [.liftoff])
    }

    func testTakingOffTowardAShortEndTaxisBackTurnsAndRolls() {
        let short = AirfieldModel(airfield: Airfield(start: -20, length: Practice.fieldLength))
        let end = short.home.end
        var s = PlaneState(x: end - 5, y: gear, heading: 0, speed: 0)
        var phase = FlightPhase.parked(repair: 0)
        let pull = PlaneInput(power: true, takeOff: 1)
        short.advance(&s, &phase, input: pull)
        guard case .taxiing(let steps, true) = phase else {
            return XCTFail("expected a taxi, got \(phase)")
        }
        XCTAssertEqual(steps.count, 3)
        ground(short, &s, &phase, input: pull) { $0 == .takeoffRoll }
        XCTAssertEqual(s.direction, 1, "facing the way the pilot asked to go")
        XCTAssertEqual(end - s.x, short.takeoffRoom, accuracy: 0.2)
        var events: [FlightEvent] = []
        for _ in 0..<600 {
            if let e = short.advance(&s, &phase, input: pull) { events.append(e) }
            if phase == .flying { break }
        }
        XCTAssertEqual(events, [.liftoff])
    }

    func testTaxiingIgnoresTheStickAndTheButtonsAndIsOnTheGround() {
        var s = PlaneState(x: 80, y: gear, heading: 0, speed: 0)
        var phase = FlightPhase.parked(repair: 0)
        model.advance(&s, &phase, input: PlaneInput(power: true, takeOff: -1))
        XCTAssertTrue(phase.isOnGround)
        model.advance(&s, &phase, input: PlaneInput(pitch: 1, power: true, fire: true, takeOff: 1))
        guard case .taxiing = phase else {
            return XCTFail("a button mid-turn should not start another plan")
        }
        XCTAssertEqual(s.y, gear)
    }

    // MARK: Repair, rollout and wrecks

    func testABrokenUndercarriageKeepsThePlaneDownUntilRepaired() {
        var s = PlaneState(x: 60, y: gear, heading: 0, speed: 0)
        var phase = FlightPhase.parked(repair: 1)
        fly(&s, &phase, input: PlaneInput(power: true, takeOff: 1), seconds: 0.5)
        XCTAssertNotEqual(phase, .takeoffRoll, "still under repair")
        fly(&s, &phase, input: PlaneInput(power: true, takeOff: 1), seconds: 1) { _, p in
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
}
