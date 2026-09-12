/// Every dial the flight model reads, in one place, so feel can be tuned on a
/// device without touching the model. Values are the milestone-1 starting
/// point, not a verdict.
public struct FlightTuning: Equatable, Sendable {
    /// Metres per second squared, pulling -y.
    public var gravity: Double = 9.8
    /// Engine push in metres per second squared, constant while powered.
    public var thrust: Double = 6
    /// Speed at which thrust and drag balance in level powered flight. Drag is
    /// derived from it, so this is the one speed dial.
    public var cruiseSpeed: Double = 40
    /// Speed below which the wing stops flying: the nose drops regardless of input.
    public var stallSpeed: Double = 14
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
