/// What the player asks of the plane on one tick. Plane-relative, nothing
/// screen-oriented: touch, keys, AI and network peers all produce this.
public struct PlaneInput: Equatable, Sendable {
    /// Elevator demand in -1...1: negative pitches the nose down, positive up.
    /// Zero is hands off, which lets the plane roll itself upright.
    public var pitch: Double
    /// Engine on (hold) or idle (release, glide).
    public var power: Bool
    /// Trigger held.
    public var fire: Bool
    /// Asked to take off, and which way along the strip: 1 to the right, -1
    /// to the left, 0 for no. Only a parked plane listens; the ground has its
    /// own buttons, the stick is for the air.
    public var takeOff: Double

    public init(pitch: Double = 0, power: Bool = false, fire: Bool = false, takeOff: Double = 0) {
        self.pitch = min(1, max(-1, pitch))
        self.power = power
        self.fire = fire
        self.takeOff = takeOff
    }

    /// Anything the player is doing at all; the practice clock starts on it.
    public var isActive: Bool { pitch != 0 || fire || takeOff != 0 }

    public static let idle = PlaneInput()
}
