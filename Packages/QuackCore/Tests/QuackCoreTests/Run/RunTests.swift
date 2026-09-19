import XCTest

@testable import QuackCore

final class RunTests: XCTestCase {
    func testBalloonsAreSeededSpreadRoundTheStripAndClearOfTheFields() {
        let strip = Run(seed: 7).model.strip
        let a = Run.balloons(seed: 7, count: 12, strip: strip)
        XCTAssertEqual(a, Run.balloons(seed: 7, count: 12, strip: strip))
        XCTAssertNotEqual(a, Run.balloons(seed: 8, count: 12, strip: strip))
        XCTAssertEqual(a.count, 12)
        XCTAssertGreaterThan(
            (a.map(\.x).max() ?? 0) - (a.map(\.x).min() ?? 0), strip.length / 2, "spread round")
        for (i, p) in a.enumerated() {
            XCTAssertTrue((0..<strip.length).contains(p.x))
            let above = p.y - strip.groundHeight(at: p.x)
            XCTAssertTrue((18...118).contains(above), "\(above) m above the ground")
            XCTAssertTrue(p.y <= 150 || above == 18, "out of the thinning air")
            for f in strip.airfields {
                XCTAssertGreaterThanOrEqual(
                    abs(strip.offset(from: p.x, to: f.start + f.length / 2)), 100)
            }
            for q in a[(i + 1)...] {
                XCTAssertGreaterThanOrEqual(hypot(strip.offset(from: p.x, to: q.x), p.y - q.y), 28)
            }
        }
    }

    /// A run already in the air, level at cruise, for tests about the gun and the balloons.
    private func airborne(seed: UInt64 = 1, balloons: Int = 1) -> Run {
        var p = Run(seed: seed, balloons: balloons)
        // Calm, so the gun and balloon tests do not hang on a seed's wind.
        p.windTuning.strength = 0
        p.plane = PlaneState(x: 0, y: 40, heading: 0, speed: 40)
        p.phase = .flying
        return p
    }

    func testRunStartsParkedOnTheField() {
        let p = Run(seed: 1)
        XCTAssertEqual(p.phase, .parked(repair: 0))
        XCTAssertNotNil(p.model.strip.airfield(under: p.plane.x))
        XCTAssertEqual(
            p.model.strip.airfield(under: p.plane.x)?.start ?? .nan, p.model.home.start,
            accuracy: 1e-9)
        XCTAssertEqual(
            p.plane.y, p.model.home.elevation + p.model.landing.gearHeight, accuracy: 1e-9)
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
        var a = Run(seed: 42)
        var b = Run(seed: 42)
        for i in 0..<300 {
            let input = PlaneInput(pitch: i % 40 < 10 ? 0.6 : 0, power: true, fire: i % 7 == 0)
            a.advance(input: input)
            b.advance(input: input)
        }
        XCTAssertEqual(a, b)
    }

    func testACrashPutsThePlaneBackOnTheFieldAndKeepsTheBalloonsAndTheClock() {
        var p = Run(seed: 3)
        p.advance(input: PlaneInput(power: true, fire: true, takeOff: 1))
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

    // MARK: The strip

    func testFlyingOffTheEndComesBackFromTheStart() {
        var p = airborne(balloons: 0)
        p.balloons = []
        let length = p.model.strip.length
        p.plane = PlaneState(x: length - 5, y: 60, heading: 0, speed: 40)
        for _ in 0..<30 { p.advance(input: PlaneInput(power: true)) }
        XCTAssertTrue((0..<length).contains(p.plane.x))
        XCTAssertLessThan(p.plane.x, 30, "just past the start")
    }

    func testRoundsAndRamsReachBalloonsAcrossTheSeam() {
        var p = airborne(balloons: 2)
        let length = p.model.strip.length
        p.plane = PlaneState(x: length - 30, y: 60, heading: 0, speed: 40)
        p.balloons[0] = Balloon(x: 10, y: 60, radius: 3)
        p.balloons[1] = Balloon(x: length - 20, y: 20, radius: 3)
        for _ in 0..<60 where p.balloons[0].popped == false {
            p.advance(input: PlaneInput(power: true, fire: true))
        }
        XCTAssertTrue(p.balloons[0].popped, "a round crossed the seam")
        var ram = airborne(balloons: 1)
        ram.balloons[0] = Balloon(x: 2, y: 40, radius: 3)
        ram.plane = PlaneState(x: length - 1, y: 40, heading: 0, speed: 40)
        ram.advance(input: PlaneInput(power: true))
        XCTAssertTrue(ram.balloons[0].popped, "rammed across the seam")
    }

    func testTheRunFinishesParkedAtAnyField() {
        var p = airborne(balloons: 1)
        p.advance(input: PlaneInput(power: true, fire: true))
        p.balloons[0].popped = true
        let other = p.model.strip.airfields[2]
        p.plane = PlaneState(
            x: other.start + 30, y: p.model.landing.gearHeight, heading: 0, speed: 0)
        p.phase = .parked(repair: 0)
        p.advance(input: .idle)
        XCTAssertTrue(p.isFinished)
    }

    func testHillsStopRounds() {
        var p = airborne(balloons: 0)
        p.balloons = []
        // A wall of ground 60 m high everywhere: a level round at 40 m ends at once.
        p.model.strip.heights = [60, 60, 60, 60]
        p.model.strip.spacing = p.model.strip.length / 4
        p.advance(input: PlaneInput(power: true, fire: true))
        XCTAssertTrue(p.bullets.isEmpty)
    }

    func testResizingTheFieldsDigsEachANewShelfAndKeepsBalloonsAboveGround() {
        var p = Run(seed: 5)
        p.plane.x += 10
        p.resizeFields(to: 180)
        let strip = p.model.strip
        XCTAssertEqual(strip, Run(seed: 5, fieldLength: 180).model.strip)
        for f in strip.airfields {
            XCTAssertEqual(f.length, 180)
            for x in stride(from: f.start, through: f.end, by: 5) {
                XCTAssertEqual(strip.groundHeight(at: x), f.elevation, accuracy: 1e-3)
            }
        }
        XCTAssertTrue(p.balloons.allSatisfy { $0.y >= strip.groundHeight(at: $0.x) + 18 - 1e-9 })
        XCTAssertEqual(p.plane, p.model.parkingSpot, "off the moved ground, back to parking")
        let before = p
        p.resizeFields(to: 180)
        XCTAssertEqual(p, before, "the same length changes nothing")
        var flying = airborne(balloons: 0)
        flying.resizeFields(to: 40)
        XCTAssertEqual(flying.phase, .flying)
        XCTAssertEqual(flying.plane.x, 0)
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
        var p = Run(seed: 1, balloons: 0)
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
        var p = Run(seed: 1, balloons: 0)
        p.ammo = 0
        for _ in 0..<15 { p.advance(input: .idle) }
        let loaded = p.ammo
        XCTAssertEqual(loaded, 5)
        p.advance(input: PlaneInput(power: true, takeOff: 1))
        XCTAssertEqual(p.phase, .takeoffRoll)
        for _ in 0..<60 { p.advance(input: PlaneInput(power: true, takeOff: 1)) }
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
