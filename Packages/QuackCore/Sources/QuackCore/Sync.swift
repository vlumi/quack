import Foundation

/// **Host-authoritative sync, both ends.** One device, the host, simulates the
/// one true fight; everyone else sends thumbs and renders snapshots. Nothing
/// stalls and nothing diverges: a late input means one plane flies on its
/// last input a moment on the host, a late snapshot means the client
/// interpolates a moment longer. Skid Jam's lesson, adopted whole: lockstep
/// over Multipeer stalled in bursts, snapshots cost latency instead of rhythm.
public enum SyncMessage {
    public static let inputTag: UInt8 = 1
    public static let snapshotTag: UInt8 = 3
}

/// One peer's thumbs for one or more ticks, newest first, so a lost packet is
/// repaired by the next one carrying the same tick again.
public struct InputPacket: Equatable, Sendable {
    public var tick: Int
    public var inputs: [PlaneInputWire]

    /// Ticks of redundancy each packet carries.
    public static let history = 8

    public init(tick: Int, inputs: [PlaneInputWire]) {
        self.tick = tick
        self.inputs = inputs
    }

    public var encoded: [UInt8] {
        var w = ByteWriter()
        w.byte(SyncMessage.inputTag)
        w.int32(Int32(tick))
        w.byte(UInt8(truncatingIfNeeded: inputs.count))
        for input in inputs { w.append(input.bytes) }
        return w.bytes
    }

    /// Nil on any malformation: a peer sending garbage is dropped, not half-believed.
    public init?(bytes: [UInt8]) {
        var r = ByteReader(bytes)
        guard r.byte() == SyncMessage.inputTag, let tick = r.int32(), let count = r.byte()
        else { return nil }
        var inputs: [PlaneInputWire] = []
        for _ in 0..<count {
            guard let raw = r.bytes(PlaneInputWire.byteCount),
                let input = PlaneInputWire(bytes: raw)
            else { return nil }
            inputs.append(input)
        }
        guard r.isDrained else { return nil }
        self.tick = Int(tick)
        self.inputs = inputs
    }
}

/// The host's half: the freshest thumb per remote seat, held between packets.
/// Holding the last input is the natural move under a host authority: the
/// host's sim is the fight, so there is nothing to fork.
public struct HostRelay: Equatable, Sendable {
    public let roster: FightRoster
    public let me: FightRoster.PeerName
    /// Sim ticks between snapshots: 3 is 20 a second, under the rate at which
    /// Multipeer congests.
    public static let snapshotEvery = 3

    private var latestTick: [Int: Int] = [:]
    private var latestInput: [Int: PlaneInput] = [:]

    public init(roster: FightRoster, me: FightRoster.PeerName) {
        self.roster = roster
        self.me = me
    }

    /// What a remote seat is doing, right now.
    public func input(for seat: Int) -> PlaneInput { latestInput[seat] ?? .idle }

    /// Take a client's packet: only a seated peer counts, and only newer ticks.
    @discardableResult
    public mutating func receive(_ bytes: [UInt8], from peer: FightRoster.PeerName) -> Bool {
        guard peer != me, let seat = roster.seat(for: peer), let packet = InputPacket(bytes: bytes),
            let newest = packet.inputs.first, packet.tick > latestTick[seat] ?? -1
        else { return false }
        latestTick[seat] = packet.tick
        latestInput[seat] = newest.input
        return true
    }

    /// A departed peer's plane flies idle, not on a held stick.
    public mutating func peerLeft(_ peer: FightRoster.PeerName) {
        if let seat = roster.seat(for: peer) { latestInput[seat] = .idle }
    }

    /// The inputs for the host's sim this tick, in seat order: its own, and each remote seat's.
    public func inputs(mine: PlaneInput) -> [PlaneInput] {
        roster.seats.map { $0 == roster.seat(for: me) ? mine : input(for: $0) }
    }

    public func shouldBroadcast(after tick: Int) -> Bool { tick % HostRelay.snapshotEvery == 0 }
}

/// The client's half: send thumbs, buffer snapshots, render a smoothed view a
/// short, adaptive distance behind the newest one.
public struct ClientView: Equatable, Sendable {
    public let roster: FightRoster
    public let me: FightRoster.PeerName
    public let seat: Int

    /// Ticks behind the newest snapshot the view renders, at least: one and a
    /// half snapshot intervals. At most three quarters of a second.
    static let minLag = 4.5
    static let maxLag = 45.0
    /// Send thumbs every other frame: 30 a second, half the message rate.
    static let inputEveryNthFrame = 2

    private var snapshots: [FightSnapshot] = []
    private var recent: [PlaneInputWire] = []
    private var renderTick: Double = -1
    private var frame = 0
    private var inputTick = 0
    private var sinceLastSnapshot: TimeInterval = 0
    private var worstGap: TimeInterval = 0

    public init(roster: FightRoster, me: FightRoster.PeerName) {
        self.roster = roster
        self.me = me
        seat = roster.seat(for: me) ?? 0
    }

    /// This frame's thumbs as a packet, or nil on the frames that skip.
    public mutating func publish(_ input: PlaneInput) -> [UInt8]? {
        inputTick += 1
        frame += 1
        recent.insert(PlaneInputWire(input), at: 0)
        if recent.count > InputPacket.history {
            recent.removeLast(recent.count - InputPacket.history)
        }
        guard frame % ClientView.inputEveryNthFrame == 0 else { return nil }
        return InputPacket(tick: inputTick, inputs: recent).encoded
    }

    /// Take a host message. Only the host's word is the fight, and an older
    /// snapshot is superseded, never rendered: the view must not move backwards.
    @discardableResult
    public mutating func receive(_ bytes: [UInt8], from peer: FightRoster.PeerName) -> Bool {
        guard peer == roster.host, let snapshot = FightSnapshot(bytes: bytes),
            snapshot.tick > (snapshots.last?.tick ?? -1)
        else { return false }
        snapshots.append(snapshot)
        if snapshots.count > 32 { snapshots.removeFirst(snapshots.count - 32) }
        worstGap = max(sinceLastSnapshot, worstGap * 0.995)
        sinceLastSnapshot = 0
        return true
    }

    /// The state to draw, `dt` seconds after the last call: played out at a
    /// steady rate with only a small skew toward the target, so a bursty link
    /// costs latency instead of rhythm. Nil until the first snapshot.
    public mutating func view(advancedBy dt: TimeInterval) -> FightSnapshot? {
        sinceLastSnapshot += dt
        guard let newest = snapshots.last else { return nil }
        let target = Double(newest.tick) - lagTicks
        if renderTick < 0 || renderTick < Double(newest.tick) - 2 * lagTicks - 6 {
            renderTick = target
        } else {
            let skew = min(0.08, max(-0.08, (target - renderTick) * 0.01))
            renderTick += dt * FlightModel.tickRate * (1 + skew)
            renderTick = min(renderTick, Double(newest.tick))
        }
        return interpolated(at: renderTick)
    }

    /// How far behind the newest snapshot to render: the worst recent arrival
    /// gap plus one snapshot interval, within the bounds.
    public var lagTicks: Double {
        min(ClientView.maxLag, max(ClientView.minLag, worstGap * FlightModel.tickRate + 3))
    }

    public var worstGapMs: Int { Int(worstGap * 1000) }
    /// The host has gone quiet long enough that the view is a freeze frame.
    public var isStarved: Bool { sinceLastSnapshot > 1.0 }
    public var newestTick: Int { snapshots.last?.tick ?? -1 }

    private func interpolated(at tick: Double) -> FightSnapshot? {
        guard let last = snapshots.last else { return nil }
        guard let after = snapshots.firstIndex(where: { Double($0.tick) >= tick }) else {
            return last
        }
        guard after > 0, Double(snapshots[after].tick) > tick else { return snapshots[after] }
        let a = snapshots[after - 1], b = snapshots[after]
        let t = (tick - Double(a.tick)) / Double(b.tick - a.tick)
        return a.blended(toward: b, t: t)
    }
}
