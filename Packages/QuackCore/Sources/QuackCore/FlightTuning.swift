/// Every dial the flight model reads, in one place, so feel can be tuned on a
/// device without touching the model. Values are the milestone-1 starting
/// point, not a verdict.
public struct FlightTuning: Equatable, Sendable {
    /// Metres per second squared, pulling -y.
    public var gravity: Double = 9.8
    /// Speed the engine holds in level powered flight.
    public var cruiseSpeed: Double = 40
    /// Speed below which the wing stops flying: the nose drops regardless of input.
    public var stallSpeed: Double = 14
    /// How hard the engine pushes the speed back toward cruise per second.
    public var engineResponse: Double = 1.2
    /// How strongly gravity trades against speed when climbing or diving (the energy model).
    public var energyExchange: Double = 1
    /// Air drag as a fraction of speed lost per second while gliding.
    public var glideDrag: Double = 0.12
    /// Metres per second the plane sinks at zero airspeed from lost lift; scales
    /// down to nothing at cruise, so a powered level plane holds its height.
    public var liftDeficitSink: Double = 6
    /// Radians per second of pitch at full elevator.
    public var pitchRate: Double = 3
    /// Radians per second the plane rolls back upright once the elevator is released.
    public var uprightRate: Double = 4

    public init() {}
}
