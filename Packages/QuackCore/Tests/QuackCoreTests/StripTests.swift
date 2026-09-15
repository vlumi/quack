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

    // MARK: Terrain

    func testAFlatStripIsAtSeaLevel() {
        XCTAssertEqual(strip.groundHeight(at: 123), 0)
    }

    func testGeneratedHillsAreSeededSeamlessAndAboveSeaLevel() {
        let a = Strip.generate(seed: 3, length: 2400, fields: 4, fieldLength: 60)
        XCTAssertEqual(
            a.heights, Strip.generate(seed: 3, length: 2400, fields: 4, fieldLength: 60).heights)
        XCTAssertEqual(
            a.groundHeight(at: 2400 - 1e-6), a.groundHeight(at: 0), accuracy: 1e-3,
            "no step at the seam")
        XCTAssertEqual(a.groundHeight(at: -5), a.groundHeight(at: 2395), accuracy: 1e-9)
        let samples = stride(from: 0.0, to: 2400, by: 1).map { a.groundHeight(at: $0) }
        XCTAssertEqual(samples.min() ?? -1, 0, accuracy: 1, "the lowest ground is about sea level")
        XCTAssertGreaterThan(samples.max() ?? 0, 5, "and there are hills")
    }

    func testEveryFieldSitsOnAShelfAsFlatAsItsApproaches() {
        // The cones reach 50 m past each end, with the throat 10 m over it: 60 m of apron is flat.
        let a = Strip.generate(seed: 1, length: 2400, fields: 4, fieldLength: 60)
        for field in a.airfields {
            for x in stride(from: field.start - 60, through: field.end + 60, by: 2.5) {
                XCTAssertEqual(
                    a.groundHeight(at: x), field.elevation, accuracy: 1e-3, "flat at \(x)")
            }
            XCTAssertEqual(a.image(of: field, near: field.start).elevation, field.elevation)
        }
    }

}
