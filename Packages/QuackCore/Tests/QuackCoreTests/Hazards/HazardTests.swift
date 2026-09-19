import XCTest

@testable import QuackCore

final class HazardTests: XCTestCase {
    /// A courier's day in calm air, level at 40 m right over the first gun.
    private func overGun(seed: UInt64 = 1) -> Run {
        var p = Run(seed: seed, mode: .courier)
        p.windTuning.strength = 0
        p.rival = nil
        let gun = p.guns[0]
        p.plane = PlaneState(
            x: gun.x - 30, y: p.model.strip.groundHeight(at: gun.x) + 40, heading: 0, speed: 40)
        p.lastHeading = 0
        p.phase = .flying
        return p
    }

    func testACourierRunHasThreeGunsClearOfTheFieldsAndTheBalloonRunNone() {
        let p = Run(seed: 1, mode: .courier)
        XCTAssertEqual(p.guns.count, 3)
        let strip = p.model.strip
        for g in p.guns {
            XCTAssertTrue(g.isAlive)
            for f in strip.airfields {
                XCTAssertGreaterThanOrEqual(
                    abs(strip.offset(from: g.x, to: f.start + f.length / 2)), 150)
            }
        }
        XCTAssertEqual(p.guns, Run(seed: 1, mode: .courier).guns, "seeded")
        XCTAssertNotEqual(p.guns, Run(seed: 2, mode: .courier).guns)
        XCTAssertTrue(Run(seed: 1, mode: .balloons).guns.isEmpty)
    }

    func testAGunInRangeFiresAtIntervalsLeadingThePlaneAndAShellCanHit() {
        var p = overGun()
        p.hazardTuning.scatter = 0
        p.advance(input: PlaneInput(power: true))
        XCTAssertEqual(p.shells.count, 1, "fires at once when in range")
        XCTAssertEqual(p.lastShotFrom, 0)
        let shell = p.shells[0]
        XCTAssertGreaterThan(shell.vy, 0, "aimed up at the plane")
        XCTAssertGreaterThan(
            shell.vx, -40, "and ahead of where it is, which is still left of the gun")
        for _ in 0..<60 { p.advance(input: PlaneInput(power: true)) }
        XCTAssertLessThanOrEqual(p.shells.count, 1, "one every two seconds")
        XCTAssertEqual(p.hits, 1, "a straight flight into a leading shot is a hit")
        XCTAssertEqual(p.repairDue, 4)
    }

    func testOutOfRangeOrOnTheGroundNothingFires() {
        var p = overGun()
        p.plane.x = p.model.strip.wrap(p.guns[0].x + 500)
        p.advance(input: PlaneInput(power: true))
        XCTAssertTrue(p.shells.isEmpty)
        var parked = Run(seed: 1, mode: .courier)
        parked.guns[0].x = parked.plane.x + 20
        parked.advance(input: .idle)
        XCTAssertTrue(parked.shells.isEmpty)
    }

    func testDodgingWorks() {
        // The shell is aimed at where straight flight would be; a dive as it
        // comes puts the plane under it.
        var p = overGun()
        p.hazardTuning.scatter = 0
        p.advance(input: PlaneInput(power: true))
        for _ in 0..<60 { p.advance(input: PlaneInput(pitch: -1, power: true)) }
        XCTAssertEqual(p.phase, .flying)
        XCTAssertEqual(p.hits, 0, "the shell went where the plane was going to be")
    }

    func testThreeHitsStopTheEngineAndTheNextStopRepairsAll() {
        var p = overGun()
        p.guns = []
        p.rival = nil
        p.hits = 3
        p.repairDue = 12
        XCTAssertTrue(p.engineShotOut)
        let before = p.plane.speed
        for _ in 0..<60 { p.advance(input: PlaneInput(power: true)) }
        XCTAssertLessThan(p.plane.speed, before, "no thrust")
        let f = p.model.strip.airfields[1]
        p.plane = PlaneState(
            x: f.start + 10, y: f.elevation + p.model.landing.gearHeight, heading: 0, speed: 0)
        p.phase = .rollout(repair: 0)
        p.advance(input: .idle)
        XCTAssertEqual(p.phase, .parked(repair: 12), "the hits' repair, on top of none")
        XCTAssertEqual(p.hits, 0)
        XCTAssertFalse(p.engineShotOut)
        XCTAssertEqual(p.repairDue, 0)
    }

    func testRoundsKnockAGunOutAndItStopsFiring() {
        var p = overGun()
        let gun = p.guns[0]
        let gy = p.model.strip.groundHeight(at: gun.x) + 1.5
        p.bullets = [Bullet(x: gun.x, y: gy, vx: 0, vy: 0), Bullet(x: gun.x, y: gy, vx: 0, vy: 0)]
        p.advance(input: PlaneInput(power: true))
        XCTAssertEqual(p.guns[0].health, 1, "one round per step counts")
        p.advance(input: PlaneInput(power: true))
        XCTAssertFalse(p.guns[0].isAlive)
        XCTAssertEqual(p.hazardEvent, .gunKnockedOut(0))
        let shells = p.shells.count
        for _ in 0..<180 { p.advance(input: PlaneInput(power: true)) }
        XCTAssertLessThanOrEqual(p.shells.count, shells, "no more from a dead gun")
    }

    func testACrashClearsTheShellsAndTheDamage() {
        var p = overGun()
        p.hits = 2
        p.repairDue = 8
        p.shells = [Shell(x: 0, y: 50, vx: 0, vy: 0)]
        p.plane = PlaneState(x: 300, y: 1, heading: -0.9, speed: 40)
        p.advance(input: .idle)
        XCTAssertEqual(p.lastEvent, .crash)
        XCTAssertTrue(p.shells.isEmpty)
        XCTAssertEqual(p.hits, 0)
        XCTAssertEqual(p.repairDue, 0)
    }
}
