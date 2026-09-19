import XCTest

@testable import QuackCore

final class BackdropTests: XCTestCase {
    private let backdrop = Backdrop.generate(seed: 3, stripLength: 2400)

    func testSeededThreeLayersBackToFrontEachALapOfTheStrip() {
        XCTAssertEqual(backdrop, Backdrop.generate(seed: 3, stripLength: 2400))
        XCTAssertNotEqual(backdrop, Backdrop.generate(seed: 4, stripLength: 2400))
        XCTAssertEqual(backdrop.layers.map(\.parallax), [0.15, 0.4, 0.7])
        for layer in backdrop.layers {
            XCTAssertEqual(layer.period, 2400 * layer.parallax, accuracy: 1e-9)
            XCTAssertEqual(
                layer.spacing * Double(layer.heights.count), layer.period, accuracy: 1e-9)
            XCTAssertLessThan(layer.rise, layer.parallax, "drifts up less than it slides")
            XCTAssertLessThan(layer.baseline, 0)
            XCTAssertTrue(layer.heights.allSatisfy { $0 > 0 })
        }
        XCTAssertLessThan(
            backdrop.layers[2].heights.max() ?? 0, backdrop.layers[0].heights.min() ?? 0,
            "the far ridge stands above the hedgerows")
    }

    func testRidgesWrapWithoutAStep() {
        for layer in backdrop.layers {
            XCTAssertEqual(layer.height(at: 0), layer.height(at: layer.period), accuracy: 1e-9)
            XCTAssertEqual(
                layer.height(at: -0.01), layer.height(at: layer.period - 0.01), accuracy: 1e-6)
            XCTAssertEqual(layer.wrap(-1), layer.period - 1, accuracy: 1e-9)
            XCTAssertEqual(layer.wrap(layer.period + 2), 2, accuracy: 1e-9)
            let mid = layer.spacing * 2.5
            XCTAssertEqual(
                layer.height(at: mid), (layer.heights[2] + layer.heights[3]) / 2, accuracy: 1e-9)
        }
    }

    func testEachLayerCarriesItsOwnKindOfProps() {
        let kinds = backdrop.layers.map { Set($0.props.map(\.kind)) }
        XCTAssertEqual(kinds[0], [.poplar, .mill])
        XCTAssertTrue(kinds[1].isSuperset(of: [.house, .poplar, .tree]))
        XCTAssertFalse(kinds[1].isDisjoint(with: [.church, .mill]))
        XCTAssertTrue(kinds[2].isSubset(of: [.tree, .house]))
        XCTAssertEqual(backdrop.layers.map(\.propScale), [0.22, 0.38, 0.6])
    }
}
