import Foundation

/// A cloud at the plane's depth: something to fly into and hide in, drifting
/// with the wind. Only a look for now; nothing can see yet whether a plane is
/// inside one.
public struct Cloud: Equatable, Sendable {
    /// Metres along the strip of its middle.
    public var x: Double
    /// Metres above sea level of its middle.
    public var y: Double
    /// Metres from end to end.
    public var width: Double

    public init(x: Double, y: Double, width: Double) {
        self.x = x
        self.y = y
        self.width = width
    }
}

/// The wind: one steady speed along the strip for a run, from the seed.
/// Positive blows toward increasing x. There is no gauge; the clouds, the
/// balloons and the windsocks show it.
public enum Wind {
    /// A share of the strongest wind, anywhere in -1...1, from the seed.
    public static func share(seed: UInt64) -> Double {
        var rng = SeededRNG(seed: seed ^ 0x3A1D_B10E)
        return rng.unit() * 2 - 1
    }

    /// `count` clouds spread round the strip from the seed, 60 to 220 m above
    /// sea level and 25 to 60 m wide.
    public static func clouds(seed: UInt64, count: Int, strip: Strip) -> [Cloud] {
        var rng = SeededRNG(seed: seed ^ 0xC10D_5000)
        let gap = strip.length / Double(max(1, count))
        return (0..<count).map { k in
            Cloud(
                x: strip.wrap(Double(k) * gap + rng.unit() * gap * 0.6),
                y: 60 + rng.unit() * 160, width: 25 + rng.unit() * 35)
        }
    }
}

/// How strong the wind can be and how the balloons take it.
public struct WindTuning: Equatable, Sendable {
    /// Metres a second of the strongest wind a seed can give.
    public var strength: Double = 8
    /// The share of the wind's speed the balloons drift at: they are slow to get going.
    public var balloonDrift: Double = 0.4
    /// Metres a second a balloon rises to keep clear of a hill drifting under it.
    public var balloonRise: Double = 6

    public init() {}
}

extension Practice {
    /// Metres a second of this run's wind.
    public var wind: Double { windShare * windTuning.strength }

    /// Clouds drift with the wind, balloons at a share of it, rising clear of
    /// the hills they drift over; the distance the air has moved adds up for
    /// the scene's far clouds.
    mutating func advanceWeather(dt: Double) {
        let w = wind
        airDrift += w * dt
        for i in clouds.indices {
            clouds[i].x = model.strip.wrap(clouds[i].x + w * dt)
        }
        let strip = model.strip
        for i in balloons.indices where !balloons[i].popped {
            balloons[i].x = strip.wrap(balloons[i].x + w * windTuning.balloonDrift * dt)
            let floor = strip.surfaceHeight(at: balloons[i].x) + 18
            if balloons[i].y < floor {
                balloons[i].y = min(floor, balloons[i].y + windTuning.balloonRise * dt)
            }
        }
    }
}
