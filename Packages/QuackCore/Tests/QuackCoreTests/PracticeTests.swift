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

    /// A run already in the air, level at cruise, for tests about the gun and the balloons.
    private func airborne(seed: UInt64 = 1, balloons: Int = 1) -> Practice {
        var p = Practice(seed: seed, balloons: balloons)
        p.plane = PlaneState(x: 0, y: 40, heading: 0, speed: 40)
        p.phase = .flying
        return p
    }

    func testRunStartsParkedOnTheField() {
        let p = Practice(seed: 1)
        XCTAssertEqual(p.phase, .parked(repair: 0))
        XCTAssertTrue(Practice.airfield.contains(p.plane.x))
        XCTAssertEqual(p.plane.y, p.model.landing.gearHeight)
        XCTAssertEqual(p.plane.speed, 0)
    }

    func testClockStartsOnFirstInputAndStopsOnlyWhenParkedAfterTheLastPop() {
        var p = airborne()
        // Just under the line of fire, so the plane rams it rather than a round.
        p.balloons[0] = Balloon(x: 60, y: 37, radius: 3)
        for _ in 0..<30 { p.advance(input: .idle) }
        XCTAssertNil(p.startedAt)
        XCTAssertEqual(p.elapsed, 0)
        p.advance(input: PlaneInput(power: true, fire: true))
        XCTAssertNotNil(p.startedAt)
        for _ in 0..<120 { p.advance(input: PlaneInput(power: true)) }
        XCTAssertEqual(p.remaining, 0)
        XCTAssertFalse(p.isFinished, "popping the last balloon is not the finish; landing is")
        XCTAssertTrue(p.needsToLand)
        p.phase = .parked(repair: 0)
        p.plane = p.model.parkingSpot
        p.advance(input: .idle)
        XCTAssertTrue(p.isFinished)
        XCTAssertFalse(p.needsToLand)
        let frozen = p.elapsed
        for _ in 0..<60 { p.advance(input: .idle) }
        XCTAssertEqual(p.elapsed, frozen)
    }

    func testTriggerFiresAtTheIntervalAndRoundsLeaveTheMuzzle() throws {
        var p = airborne(balloons: 0)
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
        var p = airborne()
        p.balloons[0] = Balloon(x: 90, y: 40, radius: 3)
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

    func testACrashPutsThePlaneBackOnTheFieldAndKeepsTheBalloonsAndTheClock() {
        var p = Practice(seed: 3)
        p.advance(input: PlaneInput(pitch: 1, power: true, fire: true))
        let started = p.startedAt
        p.plane = PlaneState(x: -300, y: 2, heading: -0.5, speed: 40)
        p.phase = .flying
        p.advance(input: .idle)
        XCTAssertEqual(p.lastEvent, .crash)
        XCTAssertTrue(p.bullets.isEmpty)
        for _ in 0..<Int(p.model.landing.wreckTime * 60) + 2 { p.advance(input: .idle) }
        XCTAssertEqual(p.phase, .parked(repair: 0))
        XCTAssertEqual(p.plane, p.model.parkingSpot)
        XCTAssertEqual(p.startedAt, started)
        XCTAssertEqual(p.balloons.count, 12)
    }

    // MARK: Ammunition

    func testARunStartsWithAFullBeltAndEachRoundCostsOne() {
        var p = airborne(balloons: 0)
        p.balloons = []
        XCTAssertEqual(p.ammo, 40)
        XCTAssertEqual(p.ammo, p.capacity)
        for _ in 0..<30 { p.advance(input: PlaneInput(power: true, fire: true)) }
        XCTAssertEqual(p.ammo, 40 - p.bullets.count, "one round per shot")
    }

    func testAnEmptyBeltFiresNothing() {
        var p = airborne(balloons: 0)
        p.balloons = []
        p.ammo = 0
        for _ in 0..<60 { p.advance(input: PlaneInput(power: true, fire: true)) }
        XCTAssertTrue(p.bullets.isEmpty)
        XCTAssertEqual(p.ammo, 0, "no rearming in the air")
    }

    func testParkedTheBeltFillsARoundAtATimeUpToCapacity() {
        var p = Practice(seed: 1, balloons: 0)
        p.ammo = 0
        XCTAssertTrue(p.isRearming)
        // Half a second at 20 rounds a second: ten rounds, not a full belt.
        for _ in 0..<30 { p.advance(input: .idle) }
        XCTAssertEqual(p.ammo, 10)
        for _ in 0..<600 { p.advance(input: .idle) }
        XCTAssertEqual(p.ammo, p.capacity)
        XCTAssertFalse(p.isRearming)
    }

    func testTakingOffPartWayKeepsWhatWasLoaded() {
        var p = Practice(seed: 1, balloons: 0)
        p.ammo = 0
        for _ in 0..<15 { p.advance(input: .idle) }
        let loaded = p.ammo
        XCTAssertEqual(loaded, 5)
        p.advance(input: PlaneInput(pitch: 1, power: true))
        XCTAssertEqual(p.phase, .takeoffRoll)
        for _ in 0..<60 { p.advance(input: PlaneInput(pitch: 1, power: true)) }
        XCTAssertEqual(p.ammo, loaded, "nothing more loads once the plane is moving")
        XCTAssertFalse(p.isRearming)
        XCTAssertEqual(p.rearmProgress, 0)
    }

    func testLoweringTheCapacityCutsTheBeltDown() {
        var p = airborne(balloons: 0)
        p.balloons = []
        p.gun.capacity = 10
        p.advance(input: .idle)
        XCTAssertEqual(p.capacity, 10)
        XCTAssertEqual(p.ammo, 10)
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
