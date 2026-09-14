import XCTest

@testable import QuackCore

/// Shared helpers for the airfield tests: a long test field, and ways to fly
/// a plane through it tick by tick.
class AirfieldTestCase: XCTestCase {
    let field = Airfield(start: 0, length: 160)
    var model: AirfieldModel { AirfieldModel(airfield: field) }
    var gear: Double { model.landing.gearHeight }

    /// Steps until `stop` returns true or `seconds` run out; returns every event, in order.
    @discardableResult
    func fly(
        _ s: inout PlaneState, _ phase: inout FlightPhase, input: PlaneInput = .idle,
        seconds: Double,
        until stop: (PlaneState, FlightPhase) -> Bool = { _, _ in false }
    ) -> [FlightEvent] {
        var events: [FlightEvent] = []
        for _ in 0..<Int(seconds * 60) {
            if let e = model.advance(&s, &phase, input: input) { events.append(e) }
            if stop(s, phase) { break }
        }
        return events
    }

    /// A plane descending at `degrees` below the horizon, `height` metres above the wheels.
    func descending(
        x: Double, height: Double, degrees: Double, leftward: Bool = false, speed: Double = 30
    )
        -> PlaneState
    {
        let g = degrees * .pi / 180
        return PlaneState(
            x: x, y: gear + height, heading: leftward ? .pi + g : -g, speed: speed,
            inverted: leftward)
    }
}
