/// Every dial the flight model reads, in one place, so feel can be tuned on a
/// device without touching the model. Values are the milestone-1 starting
/// point, not a verdict.
public struct FlightTuning: Equatable, Sendable {
    /// Metres per second squared traded between speed and height. Well above
    /// Earth's on purpose: at 9.8 a plane at cruise pointed straight up climbs
    /// ninety metres before the wing quits, which is most of a screen. This is
    /// the dial that decides how soon a vertical climb stops and flips over.
    public var gravity: Double = 22
    /// Engine push in metres per second squared, constant while powered. At 8
    /// the steepest climb the plane could hold was 17°, and getting any height
    /// off the field was a slog; 16 holds 35° and still stalls straight up
    /// inside a screen.
    public var thrust: Double = 16
    /// Speed at which thrust and drag balance in level powered flight. Drag is
    /// derived from it, so this is the one speed dial.
    public var cruiseSpeed: Double = 40
    /// Speed below which the wing stops flying: the nose drops regardless of input.
    public var stallSpeed: Double = 18
    /// Metres per second below stall speed at which the drop reaches its full
    /// rate; a narrow band makes the stall decisive, a wide one lets a slow
    /// glide mush along.
    public var stallBand: Double = 4
    /// Radians per second the nose falls toward straight down in a full stall.
    public var stallDropRate: Double = 4
    /// Metres per second a fully stalled plane sinks, whatever way it points,
    /// on top of the lift deficit. It is there before the nose goes and fades
    /// as airspeed comes back.
    public var stallSink: Double = 14
    /// Metres per second the plane sinks at zero airspeed from lost lift; scales
    /// down to nothing at cruise, so a powered level plane holds its height.
    public var liftDeficitSink: Double = 6
    /// Radians per second of pitch at full elevator.
    public var pitchRate: Double = 3
    /// Metres above sea level where the air starts to thin: above the highest
    /// balloons, so everything so far is flown in full air.
    public var thinAirFrom: Double = 120
    /// Metres above sea level where the air is so thin the plane can only just
    /// hold level at full throttle; above it, it cannot. A soft ceiling.
    public var ceiling: Double = 250

    /// How dense the air is at `altitude`, from 1 at `thinAirFrom` down to the
    /// density at which the fastest level speed meets the stall speed at the
    /// `ceiling`, and thinner still above it (never below a fifth). Thrust scales
    /// with it; the stall speed rises as one over its square root.
    public func airDensity(at altitude: Double) -> Double {
        guard altitude > thinAirFrom else { return 1 }
        let atCeiling = min(1, stallSpeed / cruiseSpeed)
        let t = (altitude - thinAirFrom) / max(1, ceiling - thinAirFrom)
        return max(0.2, 1 - (1 - atCeiling) * t)
    }

    /// Drag as a fraction of speed squared per metre, set so thrust and drag
    /// cancel exactly at cruise.
    public var drag: Double { thrust / (cruiseSpeed * cruiseSpeed) }

    public init() {}
}
