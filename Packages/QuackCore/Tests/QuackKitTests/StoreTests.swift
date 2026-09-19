import XCTest

@testable import QuackCore
@testable import QuackKit

@MainActor
final class StoreTests: XCTestCase {
    private func defaults(_ name: String) -> UserDefaults {
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func testTheInvertSwitchIsKeptInEveryBuildAndTheDialsUnderTheFlag() {
        let d = defaults("quack.tests.tuning")
        let store = TuningStore(defaults: d)
        XCTAssertFalse(store.tuning.invertedPitch)
        store.tuning.invertedPitch = true
        store.tuning.flight.thrust = 21
        let again = TuningStore(defaults: d)
        XCTAssertTrue(again.tuning.invertedPitch)
        #if QUACK_TUNING
        XCTAssertEqual(again.tuning.flight.thrust, 21)
        #else
        XCTAssertEqual(again.tuning.flight.thrust, Tuning().flight.thrust)
        #endif
        again.reset()
        XCTAssertEqual(again.tuning, Tuning())
    }

    func testACareerIsKeptAndAnotherVersionsIsDropped() throws {
        let d = defaults("quack.tests.career")
        let store = CareerStore(defaults: d)
        XCTAssertEqual(store.career, Career())
        store.career.money = 120
        store.career.buy(.tank)
        XCTAssertEqual(CareerStore(defaults: d).career, store.career)
        var stale = store.career
        stale.version = Career.version + 1
        d.set(try JSONEncoder().encode(stale), forKey: CareerStore.key)
        XCTAssertEqual(CareerStore(defaults: d).career, Career(), "not half-read")
        d.set(Data([1, 2, 3]), forKey: CareerStore.key)
        XCTAssertEqual(CareerStore(defaults: d).career, Career())
    }
}
