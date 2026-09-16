import XCTest

@testable import QuackCore

final class PassengerTests: XCTestCase {
    /// A courier's day in calm air with a passenger aboard, level at 60 m.
    private func flying() -> (Practice, Contract) {
        var p = Practice(seed: 1, mode: .courier)
        p.windTuning.strength = 0
        p.advance(input: .idle)
        p.pick(1)
        let pick = p.chosen!
        XCTAssertEqual(pick.kind, .passenger)
        for _ in 0..<600 where p.contract == nil {
            p.advance(input: PlaneInput(power: true, takeOff: 1))
        }
        p.plane = PlaneState(x: 300, y: 60, heading: 0, speed: 40)
        p.lastHeading = 0
        p.phase = .flying
        p.advance(input: PlaneInput(power: true))
        return (p, pick)
    }

    func testTheBoardOffersMailThenAPassengerAtAPremium() {
        var p = Practice(seed: 1, mode: .courier)
        p.advance(input: .idle)
        XCTAssertEqual(p.offers.map(\.kind), [.mail, .passenger])
        let mail = p.offers[0], passenger = p.offers[1]
        let strip = p.model.strip
        let a = strip.airfields[0], b = strip.airfields[passenger.to]
        let distance = abs(strip.offset(from: a.start + 30, to: b.start + 30))
        XCTAssertEqual(passenger.fare, ((10 + distance * 0.07).rounded() * 1.6).rounded())
        XCTAssertGreaterThan(
            passenger.fare / passenger.window, 0, "priced like the mail, times the premium")
        XCTAssertEqual(mail.kind, .mail)
    }

    func testLevelFlightKeepsAPassengerHappyAndMailNeverMinds() {
        var (p, pick) = flying()
        for _ in 0..<300 { p.advance(input: PlaneInput(power: true)) }
        XCTAssertEqual(p.comfort, 1)
        XCTAssertEqual(p.payNow!, pick.pay(after: p.time - p.acceptedAt!), accuracy: 1e-9)
        var mail = Practice(seed: 1, mode: .courier)
        mail.windTuning.strength = 0
        mail.advance(input: .idle)
        for _ in 0..<600 where mail.contract == nil {
            mail.advance(input: PlaneInput(power: true, takeOff: 1))
        }
        XCTAssertEqual(mail.contract?.kind, .mail)
        mail.plane = PlaneState(x: 300, y: 80, heading: 0, speed: 40)
        for _ in 0..<240 { mail.advance(input: PlaneInput(pitch: 1, power: true)) }
        XCTAssertEqual(mail.comfort, 1, "mail has no opinion of a loop")
    }

    func testALoopCutsAPassengersPayAndTheyComplainAtEachQuarter() {
        var (p, _) = flying()
        var complaints = 0
        let before = p.payNow!
        for _ in 0..<240 {
            p.advance(input: PlaneInput(pitch: 1, power: true))
            if p.courierEvent == .complaint { complaints += 1 }
        }
        XCTAssertLessThan(p.comfort, 0.8, "a few seconds of full stick and inverted flight")
        XCTAssertGreaterThanOrEqual(complaints, 1)
        XCTAssertLessThan(p.payNow!, before * p.comfort + 0.01)
        // Looping on, held at height so the loop never meets the ground.
        for _ in 0..<1200 {
            p.plane.y = 60
            p.advance(input: PlaneInput(pitch: 1, power: true))
        }
        XCTAssertEqual(p.comfort, 0.25, accuracy: 1e-9, "never below the floor")
    }

    func testAStallAndABounceCostComfortToo() {
        var (p, _) = flying()
        p.plane.speed = 10
        p.advance(input: PlaneInput(power: true))
        // The stall itself, plus the nose falling, which is a turn.
        XCTAssertGreaterThanOrEqual(p.discomfort, p.courierTuning.stallCost / 60 - 1e-9)
        var q = flying().0
        q.lastEvent = .bounce
        q.advanceCourier(input: .idle)
        XCTAssertEqual(q.discomfort, q.courierTuning.bumpCost, accuracy: 1e-9)
    }

    func testDeliveryPaysTheCutFareAndTheNextRideStartsFresh() {
        var (p, pick) = flying()
        for _ in 0..<120 { p.advance(input: PlaneInput(pitch: 1, power: true)) }
        let comfort = p.comfort
        XCTAssertLessThan(comfort, 1)
        let f = p.model.strip.airfields[pick.to]
        p.plane = PlaneState(
            x: f.start + 10, y: f.elevation + p.model.landing.gearHeight, heading: 0, speed: 0)
        p.phase = .rollout(repair: 0)
        let acceptedAt = p.acceptedAt!
        p.advance(input: .idle)
        XCTAssertEqual(p.money, pick.pay(after: p.time - acceptedAt) * comfort, accuracy: 0.05)
        XCTAssertEqual(p.discomfort, 0)
        XCTAssertEqual(p.comfort, 1)
    }
}
