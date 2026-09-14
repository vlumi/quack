import XCTest

@testable import QuackCore

final class TuningTests: XCTestCase {
    func testStockTuningIsTheComponentDefaults() {
        let t = Tuning()
        XCTAssertEqual(t.flight, FlightTuning())
        XCTAssertEqual(t.gun, GunTuning())
        XCTAssertTrue(t.changedIDs.isEmpty)
    }

    func testDialIDsAreUniqueAndEveryDefaultIsInRangeAndOnAStep() {
        let ids = TuningDial.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertFalse(ids.contains(Tuning.invertedPitchID))
        let stock = Tuning()
        for dial in TuningDial.all {
            let v = stock[keyPath: dial.keyPath]
            XCTAssertTrue(dial.range.contains(v), "\(dial.id) default \(v) outside \(dial.range)")
            let steps = (v - dial.range.lowerBound) / dial.step
            XCTAssertEqual(
                steps, steps.rounded(), accuracy: 1e-6, "\(dial.id) default is not on a step")
        }
    }

    func testEverySectionHasDialsAndSectionsCoverAll() {
        for section in TuningSection.allCases {
            XCTAssertFalse(TuningDial.dials(in: section).isEmpty, "\(section) is empty")
        }
        XCTAssertEqual(
            TuningSection.allCases.map { TuningDial.dials(in: $0).count }.reduce(0, +),
            TuningDial.all.count)
    }

    func testValuesRoundTrip() {
        var t = Tuning()
        t.flight.gravity = 30
        t.gun.fireInterval = 0.2
        t.throwDistance = 100
        t.invertedPitch = true
        XCTAssertEqual(Tuning(values: t.values), t)
    }

    func testUnknownIDsAreIgnoredMissingOnesStayDefaultAndValuesClamp() {
        let t = Tuning(values: ["flight.gravity": 1000, "no.such.dial": 5, "stall.sink": .nan])
        XCTAssertEqual(t.flight.gravity, 40, "clamped to the dial's top")
        XCTAssertEqual(
            t.flight.stallSink, FlightTuning().stallSink, "a non-finite value is ignored")
        XCTAssertEqual(t.flight.thrust, FlightTuning().thrust)
        XCTAssertFalse(t.invertedPitch)
    }

    func testReportListsEveryValueAndMarksTheChangedOnes() {
        var t = Tuning()
        t.flight.gravity = 24
        t.invertedPitch = true
        let report = t.report()
        let lines = report.split(separator: "\n")
        XCTAssertEqual(lines.first, "Quack Express tuning (2 changed)")
        XCTAssertEqual(lines.count, 1 + TuningDial.all.count + 1)
        XCTAssertTrue(report.contains("flight.gravity = 24  (default 22)"))
        XCTAssertTrue(report.contains("flight.thrust = 8.0\n"))
        XCTAssertTrue(report.contains("controls.invertedPitch = true  (default false)"))
        XCTAssertEqual(t.changedIDs, ["flight.gravity", Tuning.invertedPitchID])
    }

    func testDialFormatUsesItsDecimals() throws {
        let dial = try XCTUnwrap(TuningDial.all.first { $0.id == "gun.fireInterval" })
        XCTAssertEqual(dial.format(0.1), "0.10")
    }
}
