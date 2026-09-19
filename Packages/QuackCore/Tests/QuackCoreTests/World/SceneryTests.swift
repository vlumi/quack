import XCTest

@testable import QuackCore

final class SceneryTests: XCTestCase {
    private let tree = Obstacle(kind: .tree, x: 100)

    func testTheSolidBoxIsSmallerThanADrawingAndScalesWithSize() {
        let big = Obstacle(kind: .house, x: 0, size: 1.1)
        XCTAssertEqual(big.halfWidth, 3.4 * 1.1, accuracy: 1e-9)
        XCTAssertEqual(big.height, 7 * 1.1, accuracy: 1e-9)
        for kind in Obstacle.Kind.allCases {
            let o = Obstacle(kind: kind, x: 0)
            XCTAssertTrue((1...4).contains(o.halfWidth), "\(kind)")
            XCTAssertTrue((6...8).contains(o.height), "\(kind)")
        }
    }

    func testTheSurfaceIsTheGroundOrTheTopOfWhatStandsOnIt() {
        let strip = Strip(
            length: 400, airfields: [], heights: [10, 10, 10, 10], spacing: 100,
            scenery: [tree, Obstacle(kind: .pine, x: 399)])
        XCTAssertEqual(strip.surfaceHeight(at: 50), 10, accuracy: 1e-9)
        XCTAssertEqual(strip.surfaceHeight(at: 101), 17, accuracy: 1e-9)
        XCTAssertNil(strip.obstacle(at: 102))
        XCTAssertEqual(strip.obstacle(at: 0.1)?.kind, .pine, "measured across the seam")
    }

    func testGeneratedSceneryIsSeededAndLeavesEveryApproachClear() {
        let slope = tan(8 * Double.pi / 180)
        let strip = Strip.generate(seed: 4, length: 2400, fields: 4, fieldLength: 60)
        XCTAssertEqual(
            strip.scenery, Strip.generate(seed: 4, length: 2400, fields: 4, fieldLength: 60).scenery
        )
        XCTAssertNotEqual(
            strip.scenery, Strip.generate(seed: 5, length: 2400, fields: 4, fieldLength: 60).scenery
        )
        XCTAssertGreaterThan(strip.scenery.count, 10)
        XCTAssertEqual(Set(strip.scenery.map(\.kind)), Set(Obstacle.Kind.allCases))
        for o in strip.scenery {
            let top = strip.groundHeight(at: o.x) + o.height
            for f in strip.airfields {
                let beyond =
                    abs(strip.offset(from: f.start + f.length / 2, to: o.x)) - f.length / 2
                    - o.halfWidth
                XCTAssertGreaterThan(beyond, 70, "off the shelf")
                XCTAssertLessThanOrEqual(top, f.elevation + beyond * slope, "under the approach")
            }
        }
    }

    func testFlyingIntoATreeIsACrash() {
        let strip = Strip(
            length: 10_000, airfields: [Airfield(start: 5000, length: 60)], scenery: [tree])
        let m = AirfieldModel(strip: strip)
        var s = PlaneState(x: 60, y: 4 + m.landing.gearHeight, heading: 0, speed: 35)
        var phase = FlightPhase.flying
        var events: [FlightEvent] = []
        for _ in 0..<120 {
            if let e = m.advance(&s, &phase, input: PlaneInput(power: true)) { events.append(e) }
            if case .wrecked = phase { break }
        }
        XCTAssertEqual(events, [.crash])
        XCTAssertEqual(s.x, 100 - tree.halfWidth, accuracy: 1)
    }

    func testRoundsStopInScenery() {
        var p = Run(seed: 1, balloons: 0)
        p.model.strip.scenery = [Obstacle(kind: .house, x: 30)]
        p.plane = PlaneState(x: 0, y: p.model.strip.groundHeight(at: 0) + 5, heading: 0, speed: 40)
        p.phase = .flying
        p.advance(input: PlaneInput(power: true, fire: true))
        XCTAssertEqual(p.bullets.count, 1)
        for _ in 0..<20 { p.advance(input: PlaneInput(power: true)) }
        XCTAssertTrue(p.bullets.isEmpty, "stopped in the house, well before it expired")
    }

    // MARK: The hour

    func testTheHourIsSeededAndEveryHourComesUp() {
        XCTAssertEqual(TimeOfDay(seed: 9), TimeOfDay(seed: 9))
        XCTAssertEqual(Run(seed: 9).hour, TimeOfDay(seed: 9))
        XCTAssertEqual(Set((0..<40).map { TimeOfDay(seed: $0) }), Set(TimeOfDay.allCases))
    }

    func testTheHourDialForcesAnHourOrLeavesTheSeeds() {
        var t = Tuning()
        XCTAssertEqual(t.timeOfDay(seeded: .evening), .evening)
        t.hour = 4
        XCTAssertEqual(t.timeOfDay(seeded: .evening), .night)
        t.hour = 1
        XCTAssertEqual(t.timeOfDay(seeded: .evening), .dawn)
    }
}
