import Foundation

/// The host's word on where everything is: per seat, the fields the renderer
/// and readouts read, and every round in the air. The client never simulates
/// with these numbers, so `Float32` is the right precision.
public struct FightSnapshot: Equatable, Sendable {
    /// What a seat is doing, as far as a screen needs to know.
    public enum Doing: UInt8, Sendable {
        case parked
        case onGround
        case flying
        case falling
        case down
        case wrecked
    }

    public struct Seat: Equatable, Sendable {
        public var plane: PlaneState
        public var doing: Doing
        public var health: Int
        public var kills: Int
        public var downs: Int
        public var ammo: Int
        public var fuel: Double
        public var respawnIn: Double
        public var rounds: [Bullet]
    }

    public var tick: Int
    /// Seconds into the fight, and left of it.
    public var elapsed: Double
    public var seats: [Seat]
    /// The fight is over.
    public var finished: Bool

    public init(tick: Int, elapsed: Double, seats: [Seat], finished: Bool) {
        self.tick = tick
        self.elapsed = elapsed
        self.seats = seats
        self.finished = finished
    }

    /// The fight as it stands on the host, at sim tick `tick`.
    public init(of practice: Practice, tick: Int) {
        self.tick = tick
        elapsed = practice.elapsed
        finished = practice.isFinished
        seats = practice.pilots.map { p in
            let doing: Doing
            if p.down {
                doing = .down
            } else if p.falling {
                doing = .falling
            } else {
                switch p.phase {
                case .parked: doing = .parked
                case .wrecked: doing = .wrecked
                case .flying, .approach, .goAround: doing = .flying
                default: doing = .onGround
                }
            }
            return Seat(
                plane: p.plane, doing: doing, health: p.health, kills: p.kills, downs: p.downs,
                ammo: p.ammo, fuel: p.fuel, respawnIn: p.respawnIn ?? 0, rounds: p.bullets)
        }
    }

    /// Lay the snapshot over a client's copy of the fight, so the scene draws
    /// it as it draws the host's. The phase is set to something that reads
    /// right; the client never steps it.
    public func apply(to practice: inout Practice) {
        for (i, s) in seats.enumerated() where practice.pilots.indices.contains(i) {
            var p = practice.pilots[i]
            p.plane = s.plane
            p.health = s.health
            p.kills = s.kills
            p.downs = s.downs
            p.ammo = s.ammo
            p.fuel = s.fuel
            p.bullets = s.rounds
            p.falling = s.doing == .falling
            p.down = s.doing == .down
            p.respawnIn = s.doing == .down ? s.respawnIn : nil
            switch s.doing {
            case .parked: p.phase = .parked(repair: 0)
            case .onGround: p.phase = .takeoffRoll
            case .wrecked: p.phase = .wrecked(remaining: 1)
            case .flying, .falling, .down: p.phase = .flying
            }
            practice.pilots[i] = p
        }
        if finished, practice.finishedAt == nil { practice.finishedAt = practice.time }
    }

    /// Between this and `other`, `t` of the way: planes interpolated, everything else from the nearer.
    public func blended(toward other: FightSnapshot, t: Double) -> FightSnapshot {
        let near = t < 0.5 ? self : other
        var out = near
        out.tick = t < 0.5 ? tick : other.tick
        out.seats = zip(seats, other.seats).enumerated().map { i, pair in
            let (a, b) = pair
            var s = near.seats[i]
            var plane = s.plane
            plane.x = a.plane.x + (b.plane.x - a.plane.x) * t
            plane.y = a.plane.y + (b.plane.y - a.plane.y) * t
            plane.speed = a.plane.speed + (b.plane.speed - a.plane.speed) * t
            plane.heading = FlightModel.wrap(
                a.plane.heading + FlightModel.shortestTurn(
                    from: a.plane.heading, to: b.plane.heading) * t)
            s.plane = plane
            return s
        }
        return out
    }

    // MARK: Bytes

    public var encoded: [UInt8] {
        var w = ByteWriter()
        w.byte(SyncMessage.snapshotTag)
        w.int32(Int32(tick))
        w.float(elapsed)
        w.byte(finished ? 1 : 0)
        w.byte(UInt8(truncatingIfNeeded: seats.count))
        for s in seats {
            w.float(s.plane.x)
            w.float(s.plane.y)
            w.float(s.plane.heading)
            w.float(s.plane.speed)
            w.byte(s.plane.inverted ? 1 : 0)
            w.byte(s.doing.rawValue)
            w.byte(UInt8(clamping: max(0, s.health)))
            w.byte(UInt8(clamping: max(0, s.kills)))
            w.byte(UInt8(clamping: max(0, s.downs)))
            w.byte(UInt8(clamping: max(0, s.ammo)))
            w.float(s.fuel)
            w.float(s.respawnIn)
            w.byte(UInt8(clamping: s.rounds.count))
            for b in s.rounds.prefix(255) {
                w.float(b.x)
                w.float(b.y)
                w.float(b.vx)
                w.float(b.vy)
            }
        }
        return w.bytes
    }

    /// Nil on any malformation, trailing garbage included.
    public init?(bytes: [UInt8]) {
        var r = ByteReader(bytes)
        guard r.byte() == SyncMessage.snapshotTag, let tick = r.int32(), let elapsed = r.float(),
            let finished = r.byte(), let count = r.byte()
        else { return nil }
        var seats: [Seat] = []
        for _ in 0..<count {
            guard let seat = FightSnapshot.readSeat(&r) else { return nil }
            seats.append(seat)
        }
        guard r.isDrained else { return nil }
        self.init(tick: Int(tick), elapsed: elapsed, seats: seats, finished: finished == 1)
    }

    private static func readSeat(_ r: inout ByteReader) -> Seat? {
        guard let x = r.float(), let y = r.float(), let heading = r.float(), let speed = r.float(),
            let inverted = r.byte(), let doingRaw = r.byte(), let doing = Doing(rawValue: doingRaw),
            let health = r.byte(), let kills = r.byte(), let downs = r.byte(), let ammo = r.byte(),
            let fuel = r.float(), let respawnIn = r.float(), let roundCount = r.byte()
        else { return nil }
        var rounds: [Bullet] = []
        for _ in 0..<roundCount {
            guard let bx = r.float(), let by = r.float(), let vx = r.float(), let vy = r.float()
            else { return nil }
            rounds.append(Bullet(x: bx, y: by, vx: vx, vy: vy))
        }
        return Seat(
            plane: PlaneState(x: x, y: y, heading: heading, speed: speed, inverted: inverted == 1),
            doing: doing, health: Int(health), kills: Int(kills), downs: Int(downs),
            ammo: Int(ammo), fuel: fuel, respawnIn: respawnIn, rounds: rounds)
    }
}
