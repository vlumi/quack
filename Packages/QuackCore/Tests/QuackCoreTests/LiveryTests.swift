import Foundation
import XCTest

@testable import QuackCore

final class LiveryTests: XCTestCase {
    func testHexSplitsChannels() {
        let c = Livery.Color(hex: 0x8B5A2B)
        XCTAssertEqual(c.red, 0x8B / 255.0, accuracy: 1e-9)
        XCTAssertEqual(c.green, 0x5A / 255.0, accuracy: 1e-9)
        XCTAssertEqual(c.blue, 0x2B / 255.0, accuracy: 1e-9)
    }

    func testBuiltInsAreDistinctAndCoverEveryEmblem() {
        XCTAssertEqual(Set(Livery.all).count, Livery.all.count)
        XCTAssertEqual(Set(Livery.all.map(\.emblem)), Set(Livery.Emblem.allCases))
        XCTAssertEqual(Livery.all.first, .courier)
    }

    func testCodableRoundTrip() throws {
        for livery in Livery.all {
            let data = try JSONEncoder().encode(livery)
            XCTAssertEqual(try JSONDecoder().decode(Livery.self, from: data), livery)
        }
    }

    func testEmblemEncodesAsItsName() throws {
        let data = try JSONEncoder().encode(Livery.rival)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"checker\""))
    }
}
