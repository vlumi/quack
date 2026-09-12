/// What the player asks of the plane on one tick. Plane-relative, nothing
/// screen-oriented: touch, keys, AI and network peers all produce this.
public struct PlaneInput: Equatable, Sendable {
    /// Elevator demand in -1...1: negative pitches the nose down, positive up.
    /// Zero is hands off, which lets the plane roll itself upright.
    public var pitch: Double
    /// Engine on (hold) or idle (release, glide).
    public var power: Bool

    public init(pitch: Double = 0, power: Bool = false) {
        self.pitch = min(1, max(-1, pitch))
        self.power = power
    }

    public static let idle = PlaneInput()
}
