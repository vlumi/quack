/// Every dial the flight model reads, in one place, so feel can be tuned on a
/// device without touching the model. Values are the milestone-1 starting
/// point, not a verdict.
public struct FlightTuning: Equatable, Sendable {
    /// Metres per second squared traded between speed and height. Well above
    /// Earth's on purpose: at 9.8 a plane at cruise pointed straight up climbs
    /// ninety metres before the wing quits, which is most of a screen. This is
    /// the dial that decides how soon a vertical climb stops and flips over.
    public var gravity: Double = 22
    /// Engine push in metres per second squared, constant while powered.
    public var thrust: Double = 8
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
    /// Metres per second the plane sinks at zero airspeed from lost lift; scales
    /// down to nothing at cruise, so a powered level plane holds its height.
    public var liftDeficitSink: Double = 6
    /// Radians per second of pitch at full elevator.
    public var pitchRate: Double = 3

    /// Drag as a fraction of speed squared per metre, set so thrust and drag
    /// cancel exactly at cruise.
    public var drag: Double { thrust / (cruiseSpeed * cruiseSpeed) }

    public init() {}
}
