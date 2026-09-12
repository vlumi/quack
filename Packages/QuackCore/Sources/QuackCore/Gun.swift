import Foundation

/// The dials for the gun on the hump.
public struct GunTuning: Equatable, Sendable {
    /// Metres per second a round leaves the muzzle, on top of the plane's own speed.
    public var muzzleSpeed: Double = 120
    /// Seconds between rounds with the trigger held.
    public var fireInterval: Double = 0.1
    /// Seconds a round flies before it is gone.
    public var bulletLife: Double = 1.2
    /// Where the muzzle is, in metres ahead of and above the plane's centre.
    public var muzzleAhead: Double = 2
    public var muzzleUp: Double = 0.75

    public init() {}
}

/// One round in the air. Straight-line flight; the game is not that kind of simulation.
public struct Bullet: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var age: Double = 0

    public init(x: Double, y: Double, vx: Double, vy: Double) {
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
    }
}

extension PlaneState {
    /// The muzzle in world metres, on whichever side is currently up.
    public func muzzle(_ gun: GunTuning) -> (x: Double, y: Double) {
        let up = inverted ? -gun.muzzleUp : gun.muzzleUp
        let c = cos(heading)
        let s = sin(heading)
        return (x + gun.muzzleAhead * c - up * s, y + gun.muzzleAhead * s + up * c)
    }
}
