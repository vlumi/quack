import SpriteKit
import SwiftUI
import XCTest

@testable import QuackCore
@testable import QuackKit

@MainActor
final class ControlsAndNamesTests: XCTestCase {
    func testTheThrottleIsAlwaysOpenAndThePitchSenseCanBeInverted() {
        let controls = ThumbControls(overlay: ThumbOverlayState())
        XCTAssertTrue(controls.input.power)
        XCTAssertEqual(controls.input.pitch, 0)
        XCTAssertFalse(controls.input.fire)
        #if os(macOS)
        controls.key(.downArrow, down: true)
        XCTAssertEqual(controls.input.pitch, 1, "down arrow is stick back, nose up")
        controls.invertedPitch = true
        XCTAssertEqual(controls.input.pitch, -1)
        controls.invertedPitch = false
        controls.key(.downArrow, down: false)
        XCTAssertEqual(controls.input.pitch, 0)
        controls.key(.upArrow, down: true)
        XCTAssertEqual(controls.input.pitch, -1)
        controls.key(.downArrow, down: false)
        XCTAssertEqual(controls.input.pitch, -1, "letting go of the other key changes nothing")
        controls.key(.space, down: true)
        XCTAssertTrue(controls.input.fire)
        controls.key(.space, down: false)
        XCTAssertFalse(controls.input.fire)
        #endif
    }

    func testADeviceKeyShowsItsNameAndStaysUnique() {
        XCTAssertEqual(DeviceName.display("Ville's iPhone#ab12"), "Ville's iPhone")
        XCTAssertEqual(DeviceName.display("iPhone"), "iPhone", "a key without a suffix still shows")
        XCTAssertEqual(DeviceName.display("#ab12"), "#ab12")
        let a = DeviceName.uniqueKey(), b = DeviceName.uniqueKey()
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(DeviceName.display(a), DeviceName.display(b))
        XCTAssertLessThanOrEqual(a.utf8.count, 63, "inside Multipeer's limit")
    }

    func testThePaletteDarkensBalloonsAndTurnsTheInkPaleAtNight() {
        let noon = Palette(.noon), night = Palette(.night)
        XCTAssertEqual(noon.tintAmount, 0)
        XCTAssertEqual(noon.lit(RGB(0x336699)), RGB(0x336699), "no tint by day")
        XCTAssertNotEqual(night.lit(RGB(0x336699)), RGB(0x336699))
        XCTAssertLessThan(night.balloon(0).redComponentValue, noon.balloon(0).redComponentValue)
        XCTAssertGreaterThan(night.hudInk.whiteValue, noon.hudInk.whiteValue)
        XCTAssertEqual(noon.onLayer(RGB(0x000000), 3), RGB(0x000000), "the strip has no haze")
        XCTAssertNotEqual(noon.onLayer(RGB(0x000000), 0), RGB(0x000000), "the far ridge fades")
    }
}

extension SKColor {
    fileprivate var redComponentValue: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        usingColorSpace(.deviceRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return r
    }

    fileprivate var whiteValue: CGFloat {
        var w: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        getWhite(&w, alpha: &a)
        #else
        usingColorSpace(.deviceGray)?.getWhite(&w, alpha: &a)
        #endif
        return w
    }
}
