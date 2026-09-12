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

    func testPullingUpTurnsAndBleedsSpeed() {
        let start = PlaneState(x: 0, y: 100, heading: 0, speed: 40)
        let s = run(start, PlaneInput(pitch: 1, power: true), ticks: 20)
        XCTAssertGreaterThan(s.heading, 0.5)
        XCTAssertLessThan(s.speed, 40)
        XCTAssertGreaterThan(s.y, 100)
    }

    func testGlidingLosesSpeedAndHeight() {
        let start = PlaneState(x: 0, y: 200, heading: 0, speed: 40)
        let s = run(start, .idle, ticks: 120)
        XCTAssertLessThan(s.speed, 40)
        XCTAssertLessThan(s.y, 200)
    }

    func testStallDropsTheNose() {
        let start = PlaneState(x: 0, y: 200, heading: 0.3, speed: 5)
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
        s = run(s, PlaneInput(pitch: 0, power: true), ticks: 5)
        XCTAssertLessThan(cos(s.heading), 0, "flying left")
        XCTAssertTrue(s.inverted)
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
}
