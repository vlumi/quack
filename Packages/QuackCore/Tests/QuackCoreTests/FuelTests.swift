import XCTest

@testable import QuackCore

final class FuelTests: XCTestCase {
    private func airborne(mode: Practice.Mode = .courier) -> Practice {
        var p = Practice(seed: 1, mode: mode)
        p.windTuning.strength = 0
        p.plane = PlaneState(x: 300, y: 80, heading: 0, speed: 40)
        p.lastHeading = 0
        p.phase = .flying
        return p
    }

    func testARunStartsWithAFullTankThatBurnsASecondASecondInTheAir() {
        var p = airborne()
        XCTAssertEqual(p.fuel, 150)
        XCTAssertTrue(p.engineRunning)
        for _ in 0..<60 { p.advance(input: PlaneInput(power: true)) }
        XCTAssertEqual(p.fuel, 149, accuracy: 1e-6)
        XCTAssertEqual(p.fuelShare, 149.0 / 150, accuracy: 1e-9)
        p.phase = .takeoffRoll
        p.advance(input: PlaneInput(pitch: 1, power: true))
        XCTAssertEqual(p.fuel, 149 - 1.0 / 60, accuracy: 1e-6, "the engine runs on the ground too")
    }

    func testParkedTheTankFillsForMoneyAndTimeAndStopsWhenFull() {
        var p = Practice(seed: 1, mode: .courier)
        p.money = 100
        p.fuel = 100
        XCTAssertTrue(p.isRefuelling)
        for _ in 0..<60 { p.advance(input: .idle) }
        XCTAssertEqual(p.fuel, 110, accuracy: 1e-6, "ten seconds of fuel a second")
        XCTAssertEqual(p.money, 99, accuracy: 1e-6, "a tenth of a franc a second of fuel")
        for _ in 0..<600 { p.advance(input: .idle) }
        XCTAssertEqual(p.fuel, 150, accuracy: 1e-9)
        XCTAssertEqual(p.money, 95, accuracy: 1e-6, "paid for what went in and no more")
        XCTAssertFalse(p.isRefuelling)
    }

    func testABrokeCourierIsFilledOnCreditAndTheBalloonRunPaysNothing() {
        var p = Practice(seed: 1, mode: .courier)
        p.money = 0.5
        p.fuel = 0
        for _ in 0..<120 { p.advance(input: .idle) }
        XCTAssertEqual(p.fuel, 20, accuracy: 1e-6)
        XCTAssertEqual(p.money, 0)
        var b = Practice(seed: 1, mode: .balloons)
        b.fuel = 0
        for _ in 0..<60 { b.advance(input: .idle) }
        XCTAssertEqual(b.fuel, 10, accuracy: 1e-6)
        XCTAssertEqual(b.money, 0)
    }

    func testAnEmptyTankStopsTheEngineAndThePlaneGlides() {
        var running = airborne()
        var dead = airborne()
        dead.fuel = 0
        XCTAssertFalse(dead.engineRunning)
        for _ in 0..<120 {
            running.advance(input: PlaneInput(power: true))
            dead.advance(input: PlaneInput(power: true))
        }
        XCTAssertEqual(running.plane.speed, 40, accuracy: 0.5, "at cruise, thrust holds speed")
        XCTAssertLessThan(dead.plane.speed, 30, "no thrust: drag slows it")
        XCTAssertLessThan(dead.plane.y, running.plane.y, "and it sinks")
        XCTAssertEqual(dead.fuel, 0)
    }

    func testAnEngineDyingOnTheTakeoffRollCoastsToAStopAndRefuels() {
        var p = Practice(seed: 1, mode: .courier)
        p.windTuning.strength = 0
        p.fuel = 0.5
        for _ in 0..<600 where p.phase == .takeoffRoll || p.phase == .parked(repair: 0) {
            p.advance(input: PlaneInput(pitch: 1, power: true))
            if p.fuel == 0 { break }
        }
        XCTAssertEqual(p.phase, .takeoffRoll)
        XCTAssertGreaterThan(p.plane.speed, 0)
        var ticks = 0
        while p.phase == .takeoffRoll && ticks < 600 {
            p.advance(input: PlaneInput(pitch: 1, power: true))
            ticks += 1
        }
        XCTAssertEqual(p.phase, .parked(repair: 0), "coasted to a stop")
        XCTAssertEqual(p.lastEvent, .parked)
        XCTAssertTrue(p.model.home.contains(p.plane.x))
        p.advance(input: .idle)
        XCTAssertGreaterThan(p.fuel, 0, "and the fieldhand fills it")
    }
}
