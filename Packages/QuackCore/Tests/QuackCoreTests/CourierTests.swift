import XCTest

@testable import QuackCore

final class CourierTests: XCTestCase {
    /// A courier's day in calm air, parked at home.
    private func day(seed: UInt64 = 1) -> Practice {
        var p = Practice(seed: seed, mode: .courier)
        p.windTuning.strength = 0
        p.advance(input: .idle)
        return p
    }

    /// Put the plane down parked on field `index`.
    private func park(_ p: inout Practice, at index: Int) {
        let f = p.model.strip.airfields[index]
        p.plane = PlaneState(
            x: f.start + 10, y: f.elevation + p.model.landing.gearHeight, heading: 0, speed: 0)
        p.phase = .rollout(repair: 0)
        p.advance(input: .idle)
        XCTAssertEqual(p.lastEvent, .parked)
    }

    func testFieldsHaveSeededDistinctVillageNames() {
        let names = Practice(seed: 3).model.strip.airfields.map(\.name)
        XCTAssertEqual(names.count, 4)
        XCTAssertEqual(Set(names).count, 4, "no two the same")
        XCTAssertTrue(names.allSatisfy { Strip.villages.contains($0) })
        XCTAssertEqual(names, Practice(seed: 3).model.strip.airfields.map(\.name))
        XCTAssertNotEqual(names, Practice(seed: 4).model.strip.airfields.map(\.name))
        XCTAssertEqual(
            Strip.fieldNames(seed: 1, count: 25).count, 25, "more fields than names still works")
    }

    func testAContractPaysItsFareAtOnceFallingToAQuarterOverItsWindow() {
        let c = Contract(kind: .mail, from: 0, to: 1, fare: 40, window: 60)
        XCTAssertEqual(c.pay(after: 0), 40)
        XCTAssertEqual(c.pay(after: 30), 25, accuracy: 1e-9)
        XCTAssertEqual(c.pay(after: 60), 10, accuracy: 1e-9)
        XCTAssertEqual(c.pay(after: 600), 10, accuracy: 1e-9, "never below the floor")
    }

    func testParkedAtAFieldTheBoardOffersTwoJobsToOtherFieldsPricedByDistance() {
        let p = day()
        XCTAssertEqual(p.offers.count, 2)
        XCTAssertTrue(p.balloons.isEmpty)
        let strip = p.model.strip
        for o in p.offers {
            XCTAssertEqual(o.from, 0)
            XCTAssertNotEqual(o.to, 0)
            XCTAssertEqual(o.kind, .mail)
            let a = strip.airfields[0], b = strip.airfields[o.to]
            let distance = abs(strip.offset(from: a.start + 30, to: b.start + 30))
            XCTAssertEqual(o.fare, (10 + distance * 0.07).rounded())
            XCTAssertEqual(o.window, 4 * distance / 40 + 20, accuracy: 1e-9)
        }
        XCTAssertNotEqual(p.offers[0].to, p.offers[1].to)
        XCTAssertEqual(p.offers, day().offers, "seeded")
        XCTAssertEqual(p.chosen, p.offers[0])
    }

    func testTheTriggerCyclesTheBoardOnTheGroundAndFiresNothing() {
        var p = day()
        p.advance(input: PlaneInput(fire: true))
        XCTAssertEqual(p.chosen, p.offers[1])
        XCTAssertTrue(p.bullets.isEmpty, "the gun stays quiet on the ground")
        XCTAssertEqual(p.ammo, p.capacity)
        p.advance(input: PlaneInput(fire: true))
        XCTAssertEqual(p.chosen, p.offers[1], "held, not pulled again")
        p.advance(input: .idle)
        p.advance(input: PlaneInput(fire: true))
        XCTAssertEqual(p.chosen, p.offers[0], "round again")
    }

    /// Take off, and the pick comes aboard.
    private func takeOff(_ p: inout Practice) -> Contract {
        let pick = p.chosen!
        for _ in 0..<600 where p.contract == nil {
            p.advance(input: PlaneInput(pitch: 1, power: true))
        }
        XCTAssertEqual(p.contract, pick)
        XCTAssertTrue(p.offers.isEmpty)
        return pick
    }

    func testLiftingOffLoadsThePickAndLandingAtItsFieldPaysWhatIsLeftOfTheFare() {
        var p = day()
        let pick = takeOff(&p)
        XCTAssertEqual(p.courierEvent, .loaded(pick))
        XCTAssertEqual(p.destination, p.model.strip.airfields[pick.to])
        let loadedAt = p.acceptedAt!
        XCTAssertEqual(p.payNow!, pick.fare, accuracy: 1e-6)
        // Half a window later, parked at the destination.
        for _ in 0..<Int(pick.window / 2 * 60) { p.advance(input: PlaneInput(power: true)) }
        p.phase = .flying
        park(&p, at: pick.to)
        let expected = pick.pay(after: p.time - loadedAt)
        XCTAssertEqual(p.money, expected, accuracy: 0.1)
        XCTAssertLessThan(expected, pick.fare * 0.7)
        XCTAssertNil(p.contract)
        XCTAssertNil(p.destination)
        XCTAssertEqual(p.deliveries, 1)
        if case .delivered(let c, let pay)? = p.courierEvent {
            XCTAssertEqual(c, pick)
            XCTAssertEqual(pay, expected, accuracy: 0.1)
        } else {
            XCTFail("\(String(describing: p.courierEvent))")
        }
        p.advance(input: .idle)
        XCTAssertEqual(p.offers.count, 2, "a fresh board at the new field")
        XCTAssertTrue(p.offers.allSatisfy { $0.from == pick.to })
    }

    func testLandingElsewhereKeepsTheBagAndPostsNoBoard() {
        var p = day()
        let pick = takeOff(&p)
        let other = (1...3).first { $0 != pick.to }!
        p.phase = .flying
        park(&p, at: other)
        XCTAssertEqual(p.contract, pick)
        XCTAssertEqual(p.money, 0)
        p.advance(input: .idle)
        XCTAssertTrue(p.offers.isEmpty)
    }

    func testACrashLosesTheBag() {
        var p = day()
        let pick = takeOff(&p)
        p.plane = PlaneState(x: p.plane.x + 300, y: 1, heading: -0.9, speed: 40)
        p.phase = .flying
        p.advance(input: .idle)
        XCTAssertEqual(p.lastEvent, .crash)
        XCTAssertEqual(p.courierEvent, .lost(pick))
        XCTAssertNil(p.contract)
        XCTAssertEqual(p.money, 0)
    }

    func testTheBalloonRunHasNoBoardAndTheDefaultRunIsBalloons() {
        var p = Practice(seed: 1)
        XCTAssertEqual(p.mode, .balloons)
        p.advance(input: .idle)
        XCTAssertTrue(p.offers.isEmpty)
        XCTAssertEqual(p.balloons.count, 12)
        XCTAssertFalse(Practice(seed: 1, mode: .courier).needsToLand)
        var t = Tuning()
        XCTAssertEqual(t.mode, .courier)
        t.balloonRun = 1
        XCTAssertEqual(t.mode, .balloons)
    }
}
