import XCTest

@testable import QuackCore

final class PracticeTests: XCTestCase {
    func testFieldIsSeededSpacedAndInBounds() {
        let a = Practice.field(seed: 7, count: 12)
        let b = Practice.field(seed: 7, count: 12)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, Practice.field(seed: 8, count: 12))
        XCTAssertEqual(a.count, 12)
        for (i, p) in a.enumerated() {
            XCTAssertTrue((50...610).contains(p.x) && (18...118).contains(p.y))
            for q in a[(i + 1)...] {
                XCTAssertGreaterThanOrEqual(hypot(p.x - q.x, p.y - q.y), 28)
            }
        }
    }

    func testClockStartsOnFirstInputAndStopsOnLastPop() {
        var p = Practice(seed: 1, balloons: 1)
        // Just under the line of fire, so the first round misses and the plane rams it.
        p.balloons[0] = Balloon(x: 60, y: 57, radius: 3)
        for _ in 0..<30 { p.advance(input: .idle) }
        XCTAssertNil(p.startedAt)
        XCTAssertEqual(p.elapsed, 0)
        p.advance(input: PlaneInput(power: true, fire: true))
        XCTAssertNotNil(p.startedAt)
        // Flying level at about 40 m/s, the plane rams the balloon at x = 60 in about a second.
        for _ in 0..<120 { p.advance(input: PlaneInput(power: true)) }
        XCTAssertTrue(p.isFinished)
        XCTAssertEqual(p.remaining, 0)
        let frozen = p.elapsed
        for _ in 0..<60 { p.advance(input: PlaneInput(power: true)) }
        XCTAssertEqual(p.elapsed, frozen)
        XCTAssertGreaterThan(frozen, 0.5)
        XCTAssertLessThan(frozen, 1.5)
    }

    func testTriggerFiresAtTheIntervalAndRoundsLeaveTheMuzzle() throws {
        var p = Practice(seed: 1, balloons: 0)
        p.balloons = []
        let held = PlaneInput(power: true, fire: true)
        for _ in 0..<30 { p.advance(input: held) }
        // Half a second at 0.1 s per round: five or six in the air, all young.
        XCTAssertTrue((5...6).contains(p.bullets.count), "\(p.bullets.count) bullets")
        XCTAssertTrue(p.bullets.allSatisfy { $0.age < p.gun.bulletLife })
        let newest = try XCTUnwrap(p.bullets.last)
        XCTAssertGreaterThan(newest.vx, p.plane.vx + 100, "rounds fly faster than the plane")
        for _ in 0..<120 { p.advance(input: PlaneInput(power: true)) }
        XCTAssertTrue(p.bullets.isEmpty, "rounds expire")
    }

    func testBulletPopsBalloonAhead() {
        var p = Practice(seed: 1, balloons: 1)
        p.balloons[0] = Balloon(x: 90, y: 60, radius: 3)
        let held = PlaneInput(power: true, fire: true)
        var ticks = 0
        while p.remaining == 1 && ticks < 90 {
            p.advance(input: held)
            ticks += 1
        }
        XCTAssertEqual(p.remaining, 0)
        XCTAssertLessThan(p.plane.x, 87 - 3, "popped by a round, before the plane got there")
    }

    func testMuzzleFollowsHeadingAndFlipsWhenInverted() {
        let g = GunTuning()
        let level = PlaneState(x: 0, y: 0, heading: 0, speed: 40).muzzle(g)
        XCTAssertEqual(level.x, g.muzzleAhead, accuracy: 1e-9)
        XCTAssertEqual(level.y, g.muzzleUp, accuracy: 1e-9)
        let left = PlaneState(x: 0, y: 0, heading: .pi, speed: 40, inverted: true).muzzle(g)
        XCTAssertEqual(left.x, -g.muzzleAhead, accuracy: 1e-9)
        XCTAssertEqual(
            left.y, g.muzzleUp, accuracy: 1e-9, "flying left upright, the gun is still on top")
    }

    func testDeterministic() {
        var a = Practice(seed: 42)
        var b = Practice(seed: 42)
        for i in 0..<300 {
            let input = PlaneInput(pitch: i % 40 < 10 ? 0.6 : 0, power: true, fire: i % 7 == 0)
            a.advance(input: input)
            b.advance(input: input)
        }
        XCTAssertEqual(a, b)
    }

    func testResetKeepsTheFieldAndTheClock() {
        var p = Practice(seed: 3)
        p.advance(input: PlaneInput(pitch: 1, power: true, fire: true))
        let started = p.startedAt
        p.plane.y = -1
        p.resetPlane()
        XCTAssertEqual(p.plane.y, Practice.start.y)
        XCTAssertEqual(p.startedAt, started)
        XCTAssertEqual(p.balloons.count, 12)
        XCTAssertTrue(p.bullets.isEmpty)
    }

    func testSeededRNGIsReproducibleAndInUnitRange() {
        var a = SeededRNG(seed: 99)
        var b = SeededRNG(seed: 99)
        for _ in 0..<50 {
            let u = a.unit()
            XCTAssertEqual(u, b.unit())
            XCTAssertTrue(u >= 0 && u < 1)
        }
    }
}
