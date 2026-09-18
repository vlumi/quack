import XCTest

@testable import QuackCore

final class EnemyTests: XCTestCase {
    /// A courier's day in calm air with no guns, the courier parked at home.
    private func day() -> Practice {
        var p = Practice(seed: 1, mode: .courier)
        p.windTuning.strength = 0
        p.guns = []
        return p
    }

    func testACourierRunHasARivalHalfALapAwayAndTheBalloonRunNone() throws {
        let p = day()
        let e = try XCTUnwrap(p.enemy)
        let strip = p.model.strip
        XCTAssertEqual(
            abs(strip.offset(from: p.model.home.start, to: e.plane.x)), strip.length / 2,
            accuracy: 1)
        XCTAssertTrue(e.isFlying)
        XCTAssertEqual(e.health, 2)
        XCTAssertNil(Practice(seed: 1, mode: .balloons).enemy)
    }

    func testOnPatrolItStaysOnItsStretchAndInItsHeightBand() throws {
        var p = day()
        let strip = p.model.strip
        var lowest = Double.infinity, highest = -Double.infinity
        var turnedBack = false
        var way = p.enemy!.plane.direction
        for _ in 0..<(60 * 60) {
            p.advance(input: .idle)
            let e = try XCTUnwrap(p.enemy)
            XCTAssertTrue(e.isFlying, "no crash on patrol")
            let h = e.plane.y - strip.groundHeight(at: e.plane.x)
            lowest = min(lowest, h)
            highest = max(highest, h)
            if e.plane.direction != way {
                turnedBack = true
                way = e.plane.direction
            }
            let along = strip.offset(from: e.patrol.lowerBound, to: e.plane.x)
            XCTAssertTrue(
                along > -80 && along < 680, "on the stretch, give or take a turn: \(along)")
        }
        XCTAssertTrue(turnedBack)
        XCTAssertGreaterThan(lowest, 10)
        XCTAssertLessThan(highest, 160)
    }

    func testItTurnsOnTheCourierInRangeAndFiresWhenPointed() throws {
        var p = day()
        let e0 = try XCTUnwrap(p.enemy)
        // The courier flying level 150 m ahead of the rival, toward it.
        p.plane = PlaneState(
            x: p.model.strip.wrap(e0.plane.x + 150), y: e0.plane.y, heading: .pi, speed: 40,
            inverted: true)
        p.lastHeading = .pi
        p.phase = .flying
        var fired = false
        for _ in 0..<180 {
            p.plane.x = p.model.strip.wrap(p.enemy!.plane.x + 100)
            p.plane.y = p.enemy!.plane.y
            p.advance(input: PlaneInput(power: true))
            if !p.enemyBullets.isEmpty { fired = true }
        }
        XCTAssertTrue(fired, "pointed at a courier 100 m ahead, it fires")
        XCTAssertGreaterThan(p.hits, 0, "and a straight target gets hit")
    }

    func testTheCouriersRoundsShootItDownAndItFallsToTheGround() throws {
        var p = day()
        let e = try XCTUnwrap(p.enemy)
        p.plane = PlaneState(x: e.plane.x - 40, y: e.plane.y, heading: 0, speed: 40)
        p.phase = .flying
        p.bullets = [Bullet(x: e.plane.x, y: e.plane.y, vx: 0, vy: 0)]
        p.advance(input: PlaneInput(power: true))
        XCTAssertEqual(p.hazardEvent, .enemyHit(down: false))
        XCTAssertEqual(p.enemy?.health, 1)
        p.bullets = [Bullet(x: p.enemy!.plane.x, y: p.enemy!.plane.y, vx: 0, vy: 0)]
        p.advance(input: PlaneInput(power: true))
        XCTAssertEqual(p.hazardEvent, .enemyHit(down: true))
        XCTAssertTrue(p.enemy!.falling)
        var down = false
        for _ in 0..<(60 * 30) {
            p.advance(input: PlaneInput(power: true))
            if p.hazardEvent == .enemyDown { down = true }
        }
        XCTAssertTrue(down)
        XCTAssertTrue(p.enemy!.down)
        XCTAssertFalse(p.enemy!.isFlying)
        let before = p.enemy
        p.advance(input: .idle)
        XCTAssertEqual(p.enemy, before, "and stays down")
    }

    func testARivalFlownIntoAHillGoesDownToo() throws {
        var p = day()
        let strip = p.model.strip
        var top = 0.0
        for x in stride(from: 0.0, to: strip.length, by: 5)
        where strip.groundHeight(at: x) > strip.groundHeight(at: top) {
            top = x
        }
        p.enemy!.plane = PlaneState(
            x: top - 20, y: strip.groundHeight(at: top) - 5, heading: 0, speed: 40)
        p.enemy!.patrol = (top - 300)...(top + 300)
        p.advance(input: .idle)
        XCTAssertTrue(try XCTUnwrap(p.enemy).falling)
    }

    func testDeterministic() {
        var a = day(), b = day()
        for i in 0..<600 {
            let input = PlaneInput(pitch: i % 50 < 10 ? 1 : 0, power: true, fire: i % 9 == 0)
            a.advance(input: input)
            b.advance(input: input)
        }
        XCTAssertEqual(a.enemy, b.enemy)
        XCTAssertEqual(a.enemyBullets, b.enemyBullets)
    }
}
