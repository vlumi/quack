import XCTest

@testable import QuackCore

final class DuckfightTests: XCTestCase {
    private func fight(humans: Int = 2, rivals: Int = 0, guns: Bool = false) -> Practice {
        var o = DuckfightOptions()
        o.humans = humans
        o.rivals = rivals
        o.guns = guns
        var p = Practice(seed: 3, mode: .duckfight, duckfight: o)
        p.windTuning.strength = 0
        return p
    }

    /// Both humans level in the air, seat 1 flying left 60 m ahead of seat 0.
    private func airborne() -> Practice {
        var p = fight()
        p.pilots[0].plane = PlaneState(x: 500, y: 80, heading: 0, speed: 40)
        p.pilots[0].phase = .flying
        p.pilots[1].plane = PlaneState(x: 560, y: 80, heading: .pi, speed: 40, inverted: true)
        p.pilots[1].phase = .flying
        return p
    }

    func testSeatsStartParkedAtTheirOwnFieldsRivalsOnTheirStretchesAndGunsOnlyIfAsked() {
        let p = fight(humans: 2, rivals: 2)
        XCTAssertEqual(p.pilots.count, 4)
        XCTAssertEqual(p.pilots.map(\.brain), [.human, .human, .rival, .rival])
        let fields = p.model.strip.airfields
        for k in 0..<2 {
            XCTAssertEqual(p.pilots[k].phase, .parked(repair: 0))
            XCTAssertTrue(fields[k].contains(p.pilots[k].plane.x))
            XCTAssertEqual(p.pilots[k].health, 2)
            XCTAssertEqual(p.pilots[k].ammo, p.capacity)
        }
        XCTAssertNotEqual(p.pilots[2].patrol, p.pilots[3].patrol)
        XCTAssertTrue(p.guns.isEmpty)
        XCTAssertFalse(fight(guns: true).guns.isEmpty)
        XCTAssertNil(p.contract)
        XCTAssertTrue(p.balloons.isEmpty)
    }

    func testEachHumanSeatFliesByItsOwnInput() {
        var p = airborne()
        for _ in 0..<60 {
            p.advance(inputs: [PlaneInput(power: true), PlaneInput(pitch: 1, power: true)])
        }
        XCTAssertEqual(p.pilots[0].plane.heading, 0, accuracy: 1e-9, "seat 0 flew level")
        XCTAssertNotEqual(p.pilots[1].plane.heading, .pi, "seat 1 pulled up")
        XCTAssertLessThan(p.pilots[0].fuel, p.fuelTuning.tank, "both tanks burn")
        XCTAssertLessThan(p.pilots[1].fuel, p.fuelTuning.tank)
        var short = airborne()
        short.advance(inputs: [PlaneInput(power: true)])
        XCTAssertEqual(
            short.pilots[1].plane.heading, .pi, accuracy: 1e-9, "a seat with no input flies idle")
    }

    func testTwoRoundsDownAPlaneItFallsAndComesBackAtItsFieldAndTheKillIsCredited() {
        var p = airborne()
        // Seat 0's rounds sitting on seat 1's plane.
        p.pilots[0].bullets = [Bullet(x: 560, y: 80, vx: 0, vy: 0)]
        p.advance(inputs: [.idle, .idle])
        XCTAssertEqual(p.pilots[1].health, 1)
        guard case .hit? = p.hazardEvent else {
            return XCTFail("\(String(describing: p.hazardEvent))")
        }
        p.pilots[0].bullets = [Bullet(x: p.pilots[1].plane.x, y: p.pilots[1].plane.y, vx: 0, vy: 0)]
        p.advance(inputs: [.idle, .idle])
        XCTAssertEqual(p.hazardEvent, .downed(seat: 1, by: 0))
        XCTAssertTrue(p.pilots[1].falling)
        XCTAssertEqual(p.pilots[0].kills, 1)
        XCTAssertEqual(p.pilots[1].downs, 1)
        var landed = false
        for _ in 0..<(60 * 30) where !landed {
            p.advance(inputs: [.idle, PlaneInput(pitch: 1, power: true, fire: true)])
            if p.pilots[1].down { landed = true }
        }
        XCTAssertTrue(landed, "fell to the ground, deaf to the stick")
        XCTAssertEqual(p.pilots[1].respawnIn ?? 0, 5, accuracy: 1e-6)
        for _ in 0..<(60 * 5 + 2) { p.advance(inputs: [.idle, .idle]) }
        let back = p.pilots[1]
        XCTAssertTrue(back.isFlying)
        XCTAssertEqual(back.phase, .parked(repair: 0))
        XCTAssertTrue(p.model.strip.airfields[1].contains(back.plane.x))
        XCTAssertEqual(back.health, 2)
        XCTAssertEqual(back.ammo, p.capacity)
        XCTAssertEqual(back.fuel, p.fuelTuning.tank)
        XCTAssertEqual(back.downs, 1, "the tally stays")
    }

    func testARivalSeatIsShotDownAndComesBackToo() {
        var p = fight(humans: 1, rivals: 1)
        let r = p.pilots[1]
        p.pilots[0].plane = PlaneState(x: r.plane.x - 50, y: r.plane.y, heading: 0, speed: 40)
        p.pilots[0].phase = .flying
        p.pilots[0].bullets = [
            Bullet(x: r.plane.x, y: r.plane.y, vx: 0, vy: 0),
            Bullet(x: r.plane.x, y: r.plane.y, vx: 0, vy: 0),
        ]
        p.advance(inputs: [PlaneInput(power: true)])
        p.pilots[0].bullets = [Bullet(x: p.pilots[1].plane.x, y: p.pilots[1].plane.y, vx: 0, vy: 0)]
        p.advance(inputs: [PlaneInput(power: true)])
        XCTAssertTrue(p.pilots[1].falling)
        XCTAssertEqual(p.pilots[0].kills, 1)
        var ticks = 0
        while !p.pilots[1].isFlying && ticks < 60 * 60 {
            p.advance(inputs: [PlaneInput(power: true)])
            ticks += 1
        }
        XCTAssertTrue(p.pilots[1].isFlying, "back on its stretch")
        XCTAssertEqual(p.pilots[1].phase, .flying)
        XCTAssertEqual(p.pilots[1].health, 2)
    }

    func testTheFightEndsWhenItsTimeIsUpAndTheStandingsOrderByKills() {
        var p = airborne()
        p.duckfight.duration = 2
        p.pilots[1].kills = 3
        p.advance(inputs: [PlaneInput(power: true, fire: true), .idle])
        XCTAssertNotNil(p.startedAt)
        for _ in 0..<(60 * 2 + 2) { p.advance(inputs: [PlaneInput(power: true), .idle]) }
        XCTAssertTrue(p.isFinished)
        XCTAssertEqual(p.standings.map(\.seat), [1, 0])
    }

    func testTwoCopiesWithTheSameInputsStayIdentical() {
        var a = fight(humans: 2, rivals: 1, guns: true), b = fight(humans: 2, rivals: 1, guns: true)
        for i in 0..<900 {
            let inputs = [
                PlaneInput(
                    pitch: i % 40 < 8 ? 1 : 0, power: true, fire: i % 5 == 0,
                    takeOff: i == 0 ? 1 : 0),
                PlaneInput(
                    pitch: i % 70 < 12 ? -0.5 : 0, power: true, fire: i % 7 == 0,
                    takeOff: i == 0 ? -1 : 0),
            ]
            a.advance(inputs: inputs)
            b.advance(inputs: inputs)
        }
        XCTAssertEqual(a, b)
    }
}
