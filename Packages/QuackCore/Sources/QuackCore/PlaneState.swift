import Foundation

/// The plane at one instant. Angles in radians, distances in metres, time in
/// seconds. `heading` is the direction of flight measured anticlockwise from
/// the +x axis, so 0 flies right and π flies left; `inverted` says which way
/// the cockpit faces relative to the direction of flight.
public struct PlaneState: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var heading: Double
    public var speed: Double
    public var inverted: Bool

    public init(
        x: Double = 0, y: Double = 0, heading: Double = 0, speed: Double = 0, inverted: Bool = false
    ) {
        self.x = x
        self.y = y
        self.heading = heading
        self.speed = speed
        self.inverted = inverted
    }

    /// Velocity components from heading and speed.
    public var vx: Double { cos(heading) * speed }
    public var vy: Double { sin(heading) * speed }
}
