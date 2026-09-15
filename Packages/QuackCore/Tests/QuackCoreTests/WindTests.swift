import XCTest

@testable import QuackCore

final class WindTests: AirfieldTestCase {
    /// The test model in a wind of `share` of 16 m/s toward increasing x.
    private func windy(_ wind: Double) -> AirfieldModel {
        var m = model
        m.wind = wind
        return m
    }

    func testEachSeedGetsOneOfFiveStepsEitherWay() {
        let seeds = (0..<80).map { ($0, Wind.step(seed: $0), Wind.direction(seed: $0)) }
        XCTAssertEqual(Wind.step(seed: 7), Wind.step(seed: 7))
        XCTAssertEqual(Set(seeds.map(\.1)), Set(WindStep.allCases), "every step comes up")
        XCTAssertEqual(Set(seeds.map(\.2)), [-1, 1], "both ways come up")
        XCTAssertEqual(WindStep.allCases.map(\.share), [0, 0.25, 0.5, 0.75, 1])
        var p = Practice(seed: 7)
        XCTAssertEqual(p.windStep, Wind.step(seed: 7))
        XCTAssertEqual(p.windShare, Wind.share(seed: 7))
        p.windTuning.strength = 10
        XCTAssertEqual(p.wind, 10 * p.windShare, accuracy: 1e-12)
    }

    func testTheWindFadesTowardTheGround() {
        let t = WindTuning()
        XCTAssertEqual(t.share(atHeight: 0), 0.5)
        XCTAssertEqual(t.share(atHeight: 15), 0.75)
        XCTAssertEqual(t.share(atHeight: 30), 1)
        XCTAssertEqual(t.share(atHeight: 200), 1)
        let m = windy(16)
        XCTAssertEqual(m.wind(at: PlaneState(x: 0, y: gear, heading: 0, speed: 0)), 8)
        XCTAssertEqual(m.wind(at: PlaneState(x: 0, y: gear + 60, heading: 0, speed: 0)), 16)
    }

    func testUpInTheAirAPlaneFlownByHandDriftsWithTheWholeWind() {
        let calm = model
        let gale = windy(16)
        var a = PlaneState(x: -500, y: 60, heading: 0, speed: 40)
        var b = a
        var pa = FlightPhase.flying
        var pb = FlightPhase.flying
        for _ in 0..<60 {
            _ = calm.advance(&a, &pa, input: PlaneInput(power: true))
            _ = gale.advance(&b, &pb, input: PlaneInput(power: true))
        }
        XCTAssertEqual(b.x - a.x, 16, accuracy: 1e-6, "a second of 16 m/s tailwind")
        XCTAssertEqual(b.y, a.y, accuracy: 1e-9)
        XCTAssertEqual(b.speed, a.speed, accuracy: 1e-9, "level, no shear: airspeed as in calm")
    }

    func testClimbingThroughTheShearChangesAirspeedByTheWindMet() {
        // One step of a climb at 15 m, where the wind is three quarters of full
        // and growing: the airspeed changes by the wind the plane climbed into.
        let climbing = PlaneState(x: -500, y: gear + 15, heading: 0.4, speed: 35)
        var calm = climbing
        var head = climbing
        var tail = climbing
        var p = FlightPhase.flying
        _ = model.advance(&calm, &p, input: PlaneInput(power: true))
        _ = windy(-16).advance(&head, &p, input: PlaneInput(power: true))
        _ = windy(16).advance(&tail, &p, input: PlaneInput(power: true))
        let rise = calm.y - climbing.y
        let met = 16 * (1 - 0.5) * rise / 30
        XCTAssertGreaterThan(met, 0.05)
        XCTAssertEqual(head.speed, calm.speed + met * cos(calm.heading), accuracy: 1e-3)
        XCTAssertEqual(tail.speed, calm.speed - met * cos(calm.heading), accuracy: 1e-3)
        XCTAssertLessThan(head.pathAngle, calm.pathAngle, "the extra airspeed is along the ground")
        // Over a whole climb-out the drag eats a headwind's gain, but a tailwind's
        // loss compounds: less airspeed, a steeper path, more height to pay for.
        var results: [Double: PlaneState] = [:]
        for wind in [-16.0, 0, 16] {
            var s = PlaneState(x: -500, y: gear + 5, heading: 0.3, speed: 38)
            var phase = FlightPhase.flying
            for _ in 0..<180 { _ = windy(wind).advance(&s, &phase, input: PlaneInput(power: true)) }
            results[wind] = s
        }
        XCTAssertGreaterThan(results[0]!.y - gear, 30, "through the layer")
        XCTAssertLessThan(results[16]!.speed, results[0]!.speed - 3, "a downwind climb-out is slow")
        XCTAssertGreaterThan(results[-16]!.speed, results[0]!.speed - 1)
        XCTAssertLessThan(results[-16]!.x, results[0]!.x, "and made less ground into the wind")
    }

    func testATakeoffIntoTheWindIsShortAndDownwindLongWithNoJumpAtLiftoff() {
        struct Roll {
            let roll: Double
            let groundBefore: Double
            let groundAfter: Double
        }
        var rolls: [Double: Roll] = [:]
        for wind in [-16.0, 0, 16] {
            let m = windy(wind)
            var s = PlaneState(x: 5, y: gear, heading: 0, speed: 0)
            var phase = FlightPhase.takeoffRoll
            for _ in 0..<600 {
                let before = s.x
                let event = m.advance(&s, &phase, input: PlaneInput(pitch: 1, power: true))
                if event == .liftoff {
                    // The speed over the ground on the lifting step and the first flying one.
                    let liftX = s.x
                    _ = m.advance(&s, &phase, input: PlaneInput(pitch: 1, power: true))
                    rolls[wind] = Roll(
                        roll: liftX - 5, groundBefore: (liftX - before) * 60,
                        groundAfter: (s.x - liftX) * 60)
                    break
                }
            }
        }
        let head = rolls[-16]!, calm = rolls[0]!, tail = rolls[16]!
        XCTAssertLessThan(head.roll, calm.roll * 0.5, "rotates 8 m/s slower over the ground")
        XCTAssertGreaterThan(tail.roll, calm.roll * 1.5)
        for (wind, r) in rolls {
            XCTAssertEqual(r.groundAfter, r.groundBefore, accuracy: 1.5, "wind \(wind): no jump")
            XCTAssertGreaterThan(r.groundAfter, 10, "wind \(wind): never blown backwards")
        }
        XCTAssertEqual(model.takeoffRoom(facing: 0), model.takeoffRoom)
        XCTAssertLessThan(windy(-16).takeoffRoom(facing: 1), model.takeoffRoom)
        XCTAssertGreaterThan(windy(16).takeoffRoom(facing: 1), model.takeoffRoom)
    }

    func testTheAssistLandsAndStopsOnTheFieldInAGaleEitherWayWithoutALurch() {
        for wind in [-16.0, 16] {
            let m = windy(wind)
            var s = descending(x: -30, height: 30 * tan(8 * Double.pi / 180), degrees: 8)
            var phase = FlightPhase.flying
            var engagedAt: (before: Double, after: Double)?
            for _ in 0..<(60 * 30) {
                let speedBefore = s.speed
                let event = m.advance(&s, &phase, input: .idle)
                if event == .assistEngaged { engagedAt = (speedBefore, s.speed) }
                if case .parked = phase { break }
            }
            XCTAssertEqual(phase, .parked(repair: 0), "wind \(wind): landed and stopped")
            XCTAssertTrue(field.contains(s.x), "wind \(wind): on the field")
            guard let engaged = engagedAt else {
                return XCTFail("wind \(wind): the assist engaged")
            }
            XCTAssertEqual(engaged.after, engaged.before, accuracy: 2, "wind \(wind): no lurch")
        }
    }

    func testTouchingDownIntoTheWindRollsOutSlowOverTheGround() {
        let calm = model
        let head = windy(-16)
        var a = descending(x: 20, height: 0.3, degrees: 3, speed: 30)
        var b = a
        var pa = FlightPhase.flying
        var pb = FlightPhase.flying
        for _ in 0..<60 where pa == .flying { _ = calm.advance(&a, &pa, input: .idle) }
        for _ in 0..<60 where pb == .flying { _ = head.advance(&b, &pb, input: .idle) }
        XCTAssertEqual(pa, .rollout(repair: 0))
        XCTAssertEqual(pb, .rollout(repair: 0))
        XCTAssertEqual(a.speed - b.speed, 8, accuracy: 0.2, "8 m/s of ground-level headwind")
    }

    func testCloudsDriftAtTheWindAndBalloonsAtAShare() throws {
        var p = Practice(seed: 2, balloons: 1)
        p.windTuning.strength = 10
        p.windTuning.balloonDrift = 0.5
        let wind = p.wind
        let cloud = try XCTUnwrap(p.clouds.first)
        p.balloons[0].y = p.model.strip.groundHeight(at: p.balloons[0].x) + 100
        let balloon = p.balloons[0]
        for _ in 0..<60 { p.advance(input: .idle) }
        XCTAssertEqual(p.clouds.count, 7)
        XCTAssertEqual(p.model.strip.offset(from: cloud.x, to: p.clouds[0].x), wind, accuracy: 1e-6)
        XCTAssertEqual(
            p.model.strip.offset(from: balloon.x, to: p.balloons[0].x), wind * 0.5, accuracy: 1e-6)
        XCTAssertEqual(p.airDrift, wind, accuracy: 1e-6)
        XCTAssertEqual(Practice(seed: 2).clouds, Practice(seed: 2).clouds)
        XCTAssertNotEqual(Practice(seed: 2).clouds, Practice(seed: 3).clouds)
        for c in Practice(seed: 2).clouds {
            XCTAssertTrue((60...220).contains(c.y) && (25...60).contains(c.width))
        }
    }

    func testABalloonDriftingOverAHillRisesClearOfIt() {
        var p = Practice(seed: 2, balloons: 1)
        p.windTuning.strength = 0
        p.model.strip.heights = [40, 40, 40, 40]
        p.model.strip.spacing = p.model.strip.length / 4
        p.model.strip.scenery = []
        p.balloons[0] = Balloon(x: 500, y: 30, radius: 3)
        p.advance(input: .idle)
        XCTAssertEqual(p.balloons[0].y, 30 + p.windTuning.balloonRise / 60, accuracy: 1e-9)
        for _ in 0..<600 { p.advance(input: .idle) }
        XCTAssertEqual(p.balloons[0].y, 58, accuracy: 1e-9, "18 m clear, and no higher")
    }

    func testRoundsFlyInTheMovingAir() {
        var p = Practice(seed: 1, balloons: 0)
        p.windTuning.strength = 10
        p.plane = PlaneState(x: 0, y: 60, heading: 0, speed: 40)
        p.phase = .flying
        p.advance(input: PlaneInput(power: true, fire: true))
        let round = p.bullets[0]
        XCTAssertEqual(round.vx, 40 + p.wind + p.gun.muzzleSpeed, accuracy: 1e-6)
    }
}
