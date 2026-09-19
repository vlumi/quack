import XCTest

@testable import QuackCore

final class CareerTests: XCTestCase {
    func testUpgradesHaveLevelsAndPricesAndBuyingTakesTheMoney() {
        var c = Career(money: 100)
        XCTAssertEqual(c.level(.tank), 0)
        XCTAssertEqual(c.nextPrice(.tank), 60)
        XCTAssertTrue(c.canBuy(.tank))
        XCTAssertFalse(c.canBuy(.seat), "200 is more than 100")
        XCTAssertTrue(c.buy(.tank))
        XCTAssertEqual(c.money, 40)
        XCTAssertEqual(c.level(.tank), 1)
        XCTAssertEqual(c.nextPrice(.tank), 100)
        XCTAssertFalse(c.buy(.tank), "cannot afford the next")
        c.money = 1000
        XCTAssertTrue(c.buy(.tank))
        XCTAssertTrue(c.buy(.tank))
        XCTAssertNil(c.nextPrice(.tank), "at the top")
        XCTAssertFalse(c.buy(.tank))
        XCTAssertEqual(c.level(.tank), 3)
        XCTAssertEqual(c.tankBonus, 150)
        XCTAssertTrue(c.buy(.engine))
        XCTAssertEqual(c.thrustBonus, 1.5)
        XCTAssertEqual(c.seats, 1)
        XCTAssertTrue(c.buy(.seat))
        XCTAssertEqual(c.seats, 2)
        XCTAssertEqual(c.money, 1000 - 100 - 150 - 80 - 200)
    }

    func testACareerSurvivesBeingSaved() throws {
        var c = Career(money: 42.5)
        c.buy(.seat)
        c.money = 12
        c.buy(.engine)
        let data = try JSONEncoder().encode(c)
        let back = try JSONDecoder().decode(Career.self, from: data)
        XCTAssertEqual(back, c)
        XCTAssertEqual(back.version, Career.version)
    }

    func testARunStartsFromTheCareerWithItsUpgradesAndThePanelKeepsThem() {
        var c = Career(money: 500)
        c.buy(.tank)
        c.buy(.engine)
        c.buy(.seat)
        let stock = Run(seed: 1, mode: .courier)
        var p = Run(seed: 1, mode: .courier, career: c)
        XCTAssertEqual(p.money, c.money)
        XCTAssertEqual(p.fuel, 200)
        XCTAssertEqual(p.fuelTuning.tank, 200)
        XCTAssertEqual(p.model.flight.tuning.thrust, stock.model.flight.tuning.thrust + 1.5)
        p.advance(input: .idle)
        let passenger = p.offers.first { $0.kind == .passenger }!
        var one = stock
        one.advance(input: .idle)
        let single = one.offers.first { $0.kind == .passenger }!
        XCTAssertEqual(passenger.fare, single.fare * 2, accuracy: 1, "two seats, two fares")
        var tuning = Tuning()
        tuning.fuel.tank = 100
        tuning.flight.thrust = 10
        p.apply(tuning)
        XCTAssertEqual(p.fuelTuning.tank, 150, "the panel's tank plus the bonus")
        XCTAssertEqual(p.model.flight.tuning.thrust, 11.5)
        XCTAssertEqual(
            Run(seed: 1, mode: .balloons, career: c).money, 0, "the balloon run has no till")
    }

    func testRoundsCostMoneyAtTheFieldForTheCourierOnly() {
        var p = Run(seed: 1, mode: .courier, career: Career(money: 10))
        p.ammo = 0
        for _ in 0..<600 { p.advance(input: .idle) }
        XCTAssertEqual(p.ammo, 40)
        XCTAssertEqual(p.money, 0, "40 rounds at a quarter each is all of it")
        var b = Run(seed: 1, mode: .balloons)
        b.ammo = 0
        for _ in 0..<600 { b.advance(input: .idle) }
        XCTAssertEqual(b.ammo, 40)
        XCTAssertEqual(b.money, 0)
        var broke = Run(seed: 1, mode: .courier)
        broke.ammo = 0
        for _ in 0..<600 { broke.advance(input: .idle) }
        XCTAssertEqual(broke.ammo, 40, "filled on credit")
    }
}
