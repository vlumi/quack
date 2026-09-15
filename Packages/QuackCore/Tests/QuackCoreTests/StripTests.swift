import XCTest

@testable import QuackCore

final class StripTests: XCTestCase {
    let strip = Strip(
        length: 1000,
        airfields: [Airfield(start: 980, length: 60), Airfield(start: 400, length: 60)])

    func testWrapAndOffsetTakeTheShorterWayRound() {
        XCTAssertEqual(strip.wrap(1010), 10, accuracy: 1e-9)
        XCTAssertEqual(strip.wrap(-10), 990, accuracy: 1e-9)
        XCTAssertEqual(strip.wrap(0), 0)
        XCTAssertEqual(strip.offset(from: 990, to: 10), 20, accuracy: 1e-9, "forward over the seam")
        XCTAssertEqual(strip.offset(from: 10, to: 990), -20, accuracy: 1e-9, "back over the seam")
        XCTAssertEqual(strip.offset(from: 100, to: 400), 300, accuracy: 1e-9)
        XCTAssertEqual(
            strip.offset(from: 100, to: 700), -400, accuracy: 1e-9, "the other way is shorter")
    }

    func testAFieldAcrossTheSeamIsFoundFromEitherSide() {
        let fromRight = strip.airfield(under: 1030)
        XCTAssertNotNil(fromRight)
        XCTAssertEqual(fromRight?.start ?? .nan, 980, accuracy: 1e-9)
        let fromLeft = strip.airfield(under: 20)
        XCTAssertEqual(
            fromLeft?.start ?? .nan, -20, accuracy: 1e-9, "an image a lap back, containing 20")
        XCTAssertNil(strip.airfield(under: 200))
        XCTAssertEqual(strip.airfield(under: 430)?.start ?? .nan, 400, accuracy: 1e-9)
    }

    func testTheNearestFieldIsMeasuredRoundTheSeam() {
        XCTAssertEqual(strip.nearestAirfield(to: 900)?.start ?? .nan, 980, accuracy: 1e-9)
        XCTAssertEqual(strip.nearestAirfield(to: 60)?.start ?? .nan, -20, accuracy: 1e-9)
        XCTAssertEqual(strip.nearestAirfield(to: 500)?.start ?? .nan, 400, accuracy: 1e-9)
    }

    func testGeneratedStripsAreSeededSpreadAndWithinTheLength() {
        let a = Strip.generate(seed: 3, length: 2400, fields: 4, fieldLength: 60)
        XCTAssertEqual(a, Strip.generate(seed: 3, length: 2400, fields: 4, fieldLength: 60))
        XCTAssertNotEqual(a, Strip.generate(seed: 4, length: 2400, fields: 4, fieldLength: 60))
        XCTAssertEqual(a.airfields.count, 4)
        let starts = a.airfields.map(\.start)
        XCTAssertEqual(starts, starts.sorted(), "in order along the strip")
        for (i, f) in a.airfields.enumerated() {
            XCTAssertTrue(f.start >= 0 && f.end <= 2400, "field \(i) within the strip")
            let next = a.airfields[(i + 1) % 4]
            let gap = a.wrap(next.start - f.start)
            XCTAssertGreaterThan(gap, 300, "fields \(i) and \(i + 1) are well apart")
        }
    }
}
