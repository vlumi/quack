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

/// How hard a run's wind blows: one of five steps, so a glance at a windsock
/// says which. Each is a share of the strongest wind.
public enum WindStep: Int, CaseIterable, Sendable {
    case calm
    case low
    case medium
    case strong
    case gale

    /// The step's share of the strongest wind: 0, ¼, ½, ¾, 1.
    public var share: Double { Double(rawValue) / Double(WindStep.allCases.count - 1) }
}

/// The wind: one steady speed along the strip for a run, from the seed, in
/// one of five steps and either direction. Positive blows toward increasing
/// x. There is no gauge; the clouds, the balloons and the windsocks show it.
public enum Wind {
    /// The run's step, each as likely as any other.
    public static func step(seed: UInt64) -> WindStep {
        var rng = SeededRNG(seed: seed ^ 0x3A1D_B10E)
        let all = WindStep.allCases
        return all[min(all.count - 1, Int(rng.unit() * Double(all.count)))]
    }

    /// Which way the run's wind blows: 1 toward increasing x, -1 the other way.
    public static func direction(seed: UInt64) -> Double {
        var rng = SeededRNG(seed: seed ^ 0xD14E_C710)
        return rng.unit() < 0.5 ? -1 : 1
    }

    /// The signed share of the strongest wind: the step's share, the run's way.
    public static func share(seed: UInt64) -> Double {
        step(seed: seed).share * direction(seed: seed)
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

/// How strong the wind can be, how it fades near the ground, and how the
/// balloons take it.
public struct WindTuning: Equatable, Sendable {
    /// Metres a second of the strongest wind a seed can give.
    public var strength: Double = 16
    /// The share of the wind that blows at ground level: what a plane on its
    /// wheels feels, and where the climb through the shear starts.
    public var groundShare: Double = 0.5
    /// Metres above the ground at which the wind reaches full strength.
    public var layer: Double = 30
    /// The share of the wind's speed the balloons drift at: they are slow to get going.
    public var balloonDrift: Double = 0.4
    /// Metres a second a balloon rises to keep clear of a hill drifting under it.
    public var balloonRise: Double = 6

    public init() {}

    /// The share of the wind blowing `height` metres above the ground: the
    /// ground share at 0, rising in a straight line to all of it at `layer`.
    public func share(atHeight height: Double) -> Double {
        let t = min(1, max(0, height / max(0.1, layer)))
        return groundShare + (1 - groundShare) * t
    }
}

extension Practice {
    /// The wind's dials live on the model, which flies the plane through it.
    public var windTuning: WindTuning {
        get { model.windTuning }
        set { model.windTuning = newValue }
    }

    /// The signed share of the strongest wind this run gets: the step, the run's way.
    public var windShare: Double { windStep.share * windDirection }

    /// Metres a second of this run's wind, at full strength up in the air.
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
            let height = balloons[i].y - strip.groundHeight(at: balloons[i].x)
            let drift = w * windTuning.share(atHeight: height) * windTuning.balloonDrift
            balloons[i].x = strip.wrap(balloons[i].x + drift * dt)
            let floor = strip.surfaceHeight(at: balloons[i].x) + 18
            if balloons[i].y < floor {
                balloons[i].y = min(floor, balloons[i].y + windTuning.balloonRise * dt)
            }
        }
    }
}
