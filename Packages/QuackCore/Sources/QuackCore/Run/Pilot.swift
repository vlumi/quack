import Foundation

/// One seat in a run: a plane and everything that is its own. Every device in
/// a lockstep game simulates every seat the same way, so the local player is
/// nothing special here; the scene decides whose readouts to show.
public struct Pilot: Equatable, Sendable {
    /// Who flies the seat: a person's inputs, or the rival's mind.
    public enum Brain: Equatable, Sendable {
        case human
        case rival
    }

    public var brain: Brain
    public var plane: PlaneState
    public var phase: FlightPhase
    /// What happened to this plane on the last tick.
    public var lastEvent: FlightEvent?
    /// This seat's rounds in the air.
    public var bullets: [Bullet] = []
    public var gunCooldown: Double = 0
    /// Rounds left in the belt.
    public var ammo: Int
    /// Part of the next round loaded while parked.
    public var rearmProgress: Double = 0
    /// Seconds of engine left in the tank.
    public var fuel: Double
    /// Hits taken since the last repair, and the repair they have earned.
    public var hits = 0
    public var repairDue: Double = 0
    /// Rounds a rival can still take; 0 and it is falling.
    public var health: Int = 0
    /// A rival's stretch of the strip; it turns back at the ends.
    public var patrol: ClosedRange<Double> = 0...0
    /// A rival's seconds into its burst-and-pause cycle.
    public var fireClock: Double = 0
    /// Falling out of the sky, until the ground; then down, gone or waiting to come back.
    public var falling = false
    public var down = false
    /// Seconds until a downed seat comes back, in a Duckfight.
    public var respawnIn: Double?
    /// The field a seat starts at and comes back to.
    public var spawnField = 0
    /// The Duckfight tally: planes it has downed, times it has been downed.
    public var kills = 0
    public var downs = 0

    public init(
        brain: Brain, plane: PlaneState, phase: FlightPhase, ammo: Int, fuel: Double
    ) {
        self.brain = brain
        self.plane = plane
        self.phase = phase
        self.ammo = ammo
        self.fuel = fuel
    }

    public var isFlying: Bool { !falling && !down }
}
