import XCTest

@testable import QuackCore

final class FlightModelTests: XCTestCase {
    let model = FlightModel()

    func run(_ state: PlaneState, _ input: PlaneInput, ticks: Int) -> PlaneState {
        var s = state
        for _ in 0..<ticks { s = model.advance(s, input: input) }
        return s
    }

    func testDeterministic() {
        let start = PlaneState(x: 0, y: 100, heading: 0, speed: 40)
        let a = run(start, PlaneInput(pitch: 0.4, power: true), ticks: 600)
        let b = run(start, PlaneInput(pitch: 0.4, power: true), ticks: 600)
        XCTAssertEqual(a, b)
    }

    func testLevelPoweredFlightHoldsCruise() {
        let start = PlaneState(x: 0, y: 100, heading: 0, speed: 40)
        let s = run(start, PlaneInput(pitch: 0, power: true), ticks: 600)
        XCTAssertEqual(s.speed, model.tuning.cruiseSpeed, accuracy: 0.5)
        XCTAssertEqual(s.y, 100, accuracy: 0.01)
        XCTAssertGreaterThan(s.x, 350)
    }

    func testEngineAcceleratesToCruiseFromSlow() {
        let start = PlaneState(x: 0, y: 100, heading: 0, speed: 20)
        let s = run(start, PlaneInput(pitch: 0, power: true), ticks: 1200)
        XCTAssertEqual(s.speed, model.tuning.cruiseSpeed, accuracy: 1)
    }

    func testDiveGainsSpeedPastCruise() {
        let start = PlaneState(x: 0, y: 100, heading: -0.5, speed: 40)
        let s = run(start, PlaneInput(pitch: 0, power: true), ticks: 300)
        XCTAssertGreaterThan(s.speed, model.tuning.cruiseSpeed + 5)
    }

    func testShallowClimbIsSustained() {
        let start = PlaneState(x: 0, y: 100, heading: 0.2, speed: 40)
        let s = run(start, PlaneInput(pitch: 0, power: true), ticks: 900)
        XCTAssertGreaterThan(s.speed, model.tuning.stallSpeed + 5)
        XCTAssertEqual(s.heading, 0.2, accuracy: 1e-9, "no stall, so the heading holds")
        XCTAssertGreaterThan(s.y, 150)
    }

    func testVerticalClimbStallsAndFlipsOverSoon() {
        // Pull up from cruise to straight up, let go, and hold it there: the
        // plane must run out of speed, break, and be pointing below level
        // within two and a half seconds and well inside a screen height (70 m).
        var s = PlaneState(x: 0, y: 0, heading: 0, speed: 40)
        while s.heading < .pi / 2 { s = model.advance(s, input: PlaneInput(pitch: 1, power: true)) }
        let top = s.y
        var ticks = 0
        while s.heading > 0 && ticks < 150 {
            s = model.advance(s, input: PlaneInput(pitch: 0, power: true))
            ticks += 1
        }
        XCTAssertLessThan(s.heading, 0, "should have flipped nose down within 2.5 s")
        XCTAssertLessThan(s.y - top, 40, "should not climb far past vertical")
        XCTAssertLessThan(s.speed, model.tuning.stallSpeed, "it flipped because it stalled")
    }

    func testStallSinksBeforeTheNoseGoesAndStopsWhenSpeedReturns() {
        let t = model.tuning
        // Level and fully stalled: one second later the plane is well below
        // where it started, more than the slow-glide lift deficit accounts for.
        let stalled = PlaneState(x: 0, y: 100, heading: 0, speed: t.stallSpeed - t.stallBand)
        let after = model.advance(stalled, input: .idle)
        XCTAssertLessThan(
            after.y - stalled.y, -0.8 * t.stallSink * FlightModel.dt, "sinks on tick one")
        XCTAssertEqual(
            after.heading, stalled.heading, accuracy: 0.1, "before the nose has gone far")
        let s = run(stalled, .idle, ticks: 60)
        XCTAssertLessThan(s.y, 100 - 10)
        // Just above stall speed the only sink is the lift deficit.
        let flying = PlaneState(x: 0, y: 100, heading: 0, speed: t.stallSpeed + 1)
        let f = run(flying, PlaneInput(pitch: 0, power: true), ticks: 60)
        XCTAssertGreaterThan(f.y, 100 - 5)
        XCTAssertEqual(f.heading, 0, accuracy: 1e-9)
    }

    func testStallBreakIsDecisiveBelowTheBand() {
        let t = model.tuning
        let start = PlaneState(x: 0, y: 100, heading: .pi / 2, speed: t.stallSpeed - t.stallBand)
        let s = run(start, .idle, ticks: 30)
        // Half a second at the full drop rate: the nose has moved by about that much.
        XCTAssertEqual(.pi / 2 - s.heading, t.stallDropRate * 0.5, accuracy: 0.15)
    }

    func testSteepClimbBleedsToAStall() {
        let start = PlaneState(x: 0, y: 100, heading: 1.2, speed: 40)
        let s = run(start, PlaneInput(pitch: 0, power: true), ticks: 1200)
        XCTAssertLessThan(s.heading, 0.5, "the nose should have dropped")
    }

    func testPullingUpTurnsAndBleedsSpeed() {
        let start = PlaneState(x: 0, y: 100, heading: 0, speed: 40)
        let s = run(start, PlaneInput(pitch: 1, power: true), ticks: 20)
        XCTAssertGreaterThan(s.heading, 0.5)
        XCTAssertLessThan(s.speed, 40)
        XCTAssertGreaterThan(s.y, 100)
    }

    func testGlidingLosesSpeedAndHeight() {
        let start = PlaneState(x: 0, y: 100, heading: 0, speed: 40)
        let s = run(start, .idle, ticks: 120)
        XCTAssertLessThan(s.speed, 40)
        XCTAssertLessThan(s.y, 200)
    }

    func testStallDropsTheNose() {
        let start = PlaneState(x: 0, y: 100, heading: 0.3, speed: 5)
        let s = run(start, .idle, ticks: 120)
        XCTAssertLessThan(s.heading, -0.5, "a stalled plane should be pointing well below level")
    }

    func testHalfLoopAndReleaseIsATurn() {
        // Pull a half loop flying right, then let go: the plane should be
        // flying left, and reading as upright (inverted relative to a
        // right-flying plane), which is the Sopwith turn.
        let start = PlaneState(x: 0, y: 100, heading: 0, speed: 40)
        var s = start
        let pull = PlaneInput(pitch: 1, power: true)
        while abs(FlightModel.shortestTurn(from: s.heading, to: .pi)) > 0.1 {
            s = model.advance(s, input: pull)
        }
        XCTAssertGreaterThan(s.speed, model.tuning.stallSpeed, "a loop from cruise must not stall")
        s = run(s, PlaneInput(pitch: 0, power: true), ticks: 5)
        XCTAssertLessThan(cos(s.heading), 0, "flying left")
        XCTAssertTrue(s.inverted)
    }

    func testDragIsSetSoThrustBalancesAtCruise() {
        let t = model.tuning
        XCTAssertEqual(t.drag * t.cruiseSpeed * t.cruiseSpeed, t.thrust, accuracy: 1e-12)
    }

    func testInputClamps() {
        XCTAssertEqual(PlaneInput(pitch: 3).pitch, 1)
        XCTAssertEqual(PlaneInput(pitch: -3).pitch, -1)
    }

    func testWrap() {
        XCTAssertEqual(FlightModel.wrap(3 * .pi), .pi, accuracy: 1e-12)
        XCTAssertEqual(FlightModel.wrap(-3 * .pi), .pi, accuracy: 1e-12)
        XCTAssertEqual(FlightModel.wrap(0.5), 0.5, accuracy: 1e-12)
    }

    // MARK: Thin air

    func testTheAirIsFullBelowWhereItThinsAndJustHoldsLevelAtTheCeiling() {
        let t = model.tuning
        XCTAssertEqual(t.airDensity(at: t.thinAirFrom), 1)
        XCTAssertEqual(t.airDensity(at: -10), 1)
        XCTAssertEqual(t.airDensity(at: t.ceiling), t.stallSpeed / t.cruiseSpeed, accuracy: 1e-9)
        // At the ceiling the fastest level speed, cruise × √density, is the stall speed there.
        let d = t.airDensity(at: t.ceiling)
        XCTAssertEqual(
            t.cruiseSpeed * d.squareRoot(), t.stallSpeed / d.squareRoot(), accuracy: 1e-9)
        XCTAssertEqual(t.airDensity(at: 10_000), 0.2, "never thinner than a fifth")
    }

    func testAClimbFlattensOutBelowTheCeiling() {
        let t = model.tuning
        let s = run(
            PlaneState(x: 0, y: 50, heading: 20 * .pi / 180, speed: 40), PlaneInput(power: true),
            ticks: 60 * 120)
        XCTAssertGreaterThan(s.y, t.thinAirFrom, "climbs into the thin air")
        XCTAssertLessThan(s.y, t.ceiling, "but levels off under the ceiling")
    }

    func testAboveTheCeilingThePlaneCannotHoldLevel() {
        let t = model.tuning
        let start = PlaneState(x: 0, y: t.ceiling + 40, heading: 0, speed: 40)
        let s = run(start, PlaneInput(power: true), ticks: 60 * 10)
        XCTAssertLessThan(s.y, start.y - 20)
    }

}
