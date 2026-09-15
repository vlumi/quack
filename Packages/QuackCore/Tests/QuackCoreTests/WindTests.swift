import XCTest

@testable import QuackCore

final class WindTests: AirfieldTestCase {
    func testEachSeedGetsItsOwnWindEitherWay() {
        let shares = (0..<60).map { Wind.share(seed: $0) }
        XCTAssertEqual(Wind.share(seed: 7), Wind.share(seed: 7))
        XCTAssertTrue(shares.allSatisfy { (-1...1).contains($0) })
        XCTAssertTrue(shares.contains { $0 > 0.5 } && shares.contains { $0 < -0.5 })
        var p = Practice(seed: 7)
        XCTAssertEqual(p.windShare, Wind.share(seed: 7))
        p.windTuning.strength = 10
        XCTAssertEqual(p.wind, 10 * p.windShare, accuracy: 1e-12)
    }

    func testAPlaneFlownByHandDriftsWithTheWind() {
        var calm = model
        calm.wind = 0
        var windy = model
        windy.wind = 8
        var a = PlaneState(x: -500, y: 60, heading: 0, speed: 40)
        var b = a
        var pa = FlightPhase.flying
        var pb = FlightPhase.flying
        for _ in 0..<60 {
            _ = calm.advance(&a, &pa, input: PlaneInput(power: true))
            _ = windy.advance(&b, &pb, input: PlaneInput(power: true))
        }
        XCTAssertEqual(b.x - a.x, 8, accuracy: 1e-6, "a second of 8 m/s tailwind")
        XCTAssertEqual(b.y, a.y, accuracy: 1e-9)
    }

    func testTheAssistAndTheGroundIgnoreTheWind() {
        var s = descending(x: -30, height: 30 * tan(8 * Double.pi / 180), degrees: 8)
        var phase = FlightPhase.flying
        fly(&s, &phase, seconds: 5) { _, p in
            if case .approach = p { return true }
            return false
        }
        guard case .approach = phase else { return XCTFail("the assist engaged, \(phase)") }
        // From the moment the assist takes over, a headwind changes nothing:
        // not the glide, the rollout, the stop, or the takeoff roll after it.
        var windy = model
        windy.wind = -10
        var calm = (s, phase)
        var gusty = (s, phase)
        for tick in 0..<(60 * 20) {
            let input = tick > 60 * 12 ? PlaneInput(pitch: 1, power: true) : .idle
            _ = model.advance(&calm.0, &calm.1, input: input)
            _ = windy.advance(&gusty.0, &gusty.1, input: input)
            if case .flying = calm.1 { break }
        }
        XCTAssertEqual(gusty.0, calm.0)
        XCTAssertEqual(gusty.1, calm.1)
        XCTAssertEqual(calm.1, .flying, "landed, stopped, and took off again")
    }

    func testCloudsDriftAtTheWindAndBalloonsAtAShare() throws {
        var p = Practice(seed: 2, balloons: 1)
        p.windTuning.strength = 10
        p.windTuning.balloonDrift = 0.5
        let wind = p.wind
        let cloud = try XCTUnwrap(p.clouds.first)
        let balloon = p.balloons[0]
        for _ in 0..<60 { p.advance(input: .idle) }
        XCTAssertEqual(p.clouds.count, 7)
        XCTAssertEqual(p.model.strip.offset(from: cloud.x, to: p.clouds[0].x), wind, accuracy: 1e-6)
        XCTAssertEqual(
            p.model.strip.offset(from: balloon.x, to: p.balloons[0].x), wind * 0.5, accuracy: 1e-6)
        XCTAssertEqual(p.airDrift, wind, accuracy: 1e-6)
        XCTAssertEqual(Practice(seed: 2).clouds, Practice(seed: 2).clouds)
        XCTAssertNotEqual(Practice(seed: 2).clouds, Practice(seed: 3).clouds)
        for c in Practice(seed: 2).clouds {
            XCTAssertTrue((60...220).contains(c.y) && (25...60).contains(c.width))
        }
    }

    func testABalloonDriftingOverAHillRisesClearOfIt() {
        var p = Practice(seed: 2, balloons: 1)
        p.windTuning.strength = 0
        p.model.strip.heights = [40, 40, 40, 40]
        p.model.strip.spacing = p.model.strip.length / 4
        p.model.strip.scenery = []
        p.balloons[0] = Balloon(x: 500, y: 30, radius: 3)
        p.advance(input: .idle)
        XCTAssertEqual(p.balloons[0].y, 30 + p.windTuning.balloonRise / 60, accuracy: 1e-9)
        for _ in 0..<600 { p.advance(input: .idle) }
        XCTAssertEqual(p.balloons[0].y, 58, accuracy: 1e-9, "18 m clear, and no higher")
    }

    func testRoundsFlyInTheMovingAir() {
        var p = Practice(seed: 1, balloons: 0)
        p.windTuning.strength = 10
        p.plane = PlaneState(x: 0, y: 60, heading: 0, speed: 40)
        p.phase = .flying
        p.advance(input: PlaneInput(power: true, fire: true))
        let round = p.bullets[0]
        XCTAssertEqual(round.vx, 40 + p.wind + p.gun.muzzleSpeed, accuracy: 1e-6)
    }
}
