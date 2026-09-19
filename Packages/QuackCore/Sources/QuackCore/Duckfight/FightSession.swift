import Combine
import Foundation

/// The session around a Duckfight: hosting or joining, the lobby, the start,
/// and the per-tick traffic while the fight runs. The host's sim is the
/// fight; guests send thumbs and render snapshots. Transport-free, so two
/// sessions can be driven against each other in one process.
@MainActor
public final class FightSession: ObservableObject, FightTransportDelegate {
    public enum Phase: Equatable, Sendable {
        case idle
        case hosting
        /// Looking for hosts; the ones seen so far.
        case joining
        /// Asked a host in; waiting for the roster.
        case awaitingSeat
        /// Seated by a host, waiting for the start.
        case lobby
        case fighting
        case ended(reason: String)
    }

    @Published public private(set) var phase = Phase.idle
    @Published public private(set) var roster = FightRoster()
    @Published public private(set) var visibleHosts: [FightRoster.PeerName] = []
    /// Why the last join was refused, for the lobby to say.
    @Published public private(set) var refusal: String?
    /// The host has gone quiet, or a peer is dropping out.
    @Published public private(set) var stallNote: String?
    /// What every device agreed to fight; nil until the start.
    public private(set) var start: FightStart?

    public let transport: FightTransport
    public let name: String
    private var chosenHost: FightRoster.PeerName?
    private var relay: HostRelay?
    private var clientView: ClientView?
    private var onStart: ((FightStart) -> Void)?

    public init(transport: FightTransport, name: String) {
        self.transport = transport
        self.name = name
        transport.delegate = self
    }

    public var me: FightRoster.PeerName { transport.me }
    public var isHost: Bool { roster.host == me }
    public var mySeat: Int? { roster.seat(for: me) }

    // MARK: The lobby

    /// Host: seat ourselves first, so the host is always seat 0, and go findable.
    public func host() {
        reset()
        roster = FightRoster()
        try? roster.join(me, name: name)
        phase = .hosting
        transport.startHosting()
    }

    /// Guest: look for hosts.
    public func join() {
        reset()
        roster = FightRoster()
        phase = .joining
        transport.startBrowsing()
    }

    /// Guest: ask a host in. Choosing is deliberate; a room can hold two fights.
    public func askToJoin(_ host: FightRoster.PeerName) {
        guard phase == .joining || phase == .awaitingSeat else { return }
        chosenHost = host
        refusal = nil
        phase = .awaitingSeat
        transport.send(JoinRequest(name: name).encoded, reliable: true)
    }

    /// Leave for good, saying so first: a silent exit is only noticed later.
    public func leave() {
        if phase != .idle {
            transport.send(LeaveNotice(byHost: isHost).encoded, reliable: true)
        }
        transport.disconnect()
        reset()
        roster = FightRoster()
        phase = .idle
    }

    /// Host only: freeze the roster and tell everyone what to fight. The host
    /// applies its own message exactly as a guest does, so the two cannot differ.
    public func startFight(seed: UInt64, options: DuckfightOptions, tuning: [String: Double]) {
        guard isHost, start == nil else { return }
        var o = options
        o.humans = roster.humanCount
        let message = FightStart(seed: seed, roster: roster, options: o, tuning: tuning)
        transport.send(message.encoded, reliable: true)
        apply(message)
    }

    /// Whoever builds the scene asks to be told when a fight starts.
    public func whenStarted(_ handler: @escaping (FightStart) -> Void) {
        onStart = handler
        if let start { handler(start) }
    }

    private func apply(_ message: FightStart) {
        start = message
        roster = message.roster
        stallNote = nil
        if message.roster.host == me {
            relay = HostRelay(roster: message.roster, me: me)
        } else {
            clientView = ClientView(roster: message.roster, me: me)
        }
        phase = .fighting
        onStart?(message)
    }

    private func reset() {
        start = nil
        relay = nil
        clientView = nil
        chosenHost = nil
        visibleHosts = []
        refusal = nil
        stallNote = nil
    }

    // MARK: Driving the fight

    /// Host: the inputs for this tick, in seat order, its own among them.
    public func hostInputs(mine: PlaneInput) -> [PlaneInput] {
        relay?.inputs(mine: mine) ?? [mine]
    }

    /// Host: after a simulated tick, a snapshot on the cadence ticks, unreliably.
    public func broadcast(_ run: Run, tick: Int) {
        guard let relay, relay.shouldBroadcast(after: tick) else { return }
        transport.send(FightSnapshot(of: run, tick: tick).encoded, reliable: false)
    }

    /// Guest: this frame's thumbs, off to the host on the frames that send.
    public func publish(_ input: PlaneInput) {
        guard var view = clientView else { return }
        let bytes = view.publish(input)
        clientView = view
        if let bytes { transport.send(bytes, reliable: false) }
    }

    /// Guest: the smoothed state to draw, and whether the host has gone quiet.
    public func view(advancedBy dt: TimeInterval) -> FightSnapshot? {
        guard var view = clientView else { return nil }
        let shown = view.view(advancedBy: dt)
        clientView = view
        if view.isStarved {
            stallNote = "Waiting for \(roster.name(for: 0) ?? "the host")"
        } else if stallNote != nil {
            stallNote = nil
        }
        return shown
    }

    // MARK: The transport's word

    public func transport(didReceive bytes: [UInt8], from peer: FightRoster.PeerName) {
        if receiveLobbyMessage(bytes, from: peer) { return }
        if var relay {
            relay.receive(bytes, from: peer)
            self.relay = relay
        } else if var view = clientView {
            view.receive(bytes, from: peer)
            clientView = view
        }
    }

    private func receiveLobbyMessage(_ bytes: [UInt8], from peer: FightRoster.PeerName) -> Bool {
        if let request = JoinRequest(bytes: bytes) {
            guard isHost, start == nil else { return true }
            seat(peer, name: request.name)
            return true
        }
        if let update = RosterUpdate(bytes: bytes) {
            guard !isHost, peer == chosenHost else { return true }
            if let why = update.refused, update.roster.seat(for: me) == nil {
                refusal = why
                chosenHost = nil
                phase = .joining
            } else {
                roster = update.roster
                if start == nil { phase = .lobby }
            }
            return true
        }
        if let message = FightStart(bytes: bytes) {
            guard !isHost, peer == chosenHost else { return true }
            apply(message)
            return true
        }
        if let notice = LeaveNotice(bytes: bytes) {
            departed(peer, byHost: notice.byHost)
            return true
        }
        return false
    }

    public func transport(peerJoined peer: FightRoster.PeerName) {
        guard start == nil, !isHost else { return }
        if !visibleHosts.contains(peer) { visibleHosts.append(peer) }
        if peer == chosenHost { askToJoin(peer) }
    }

    public func transport(peerLeft peer: FightRoster.PeerName) {
        visibleHosts.removeAll { $0 == peer }
        departed(peer, byHost: peer == roster.host)
    }

    /// Seat a guest, or tell it why not.
    private func seat(_ peer: FightRoster.PeerName, name: String) {
        do {
            try roster.join(peer, name: name)
            transport.send(RosterUpdate(roster: roster).encoded, reliable: true)
        } catch {
            let why =
                error == .fieldFull
                ? "The fight is full" : "Already seated"
            transport.send(RosterUpdate(roster: roster, refused: why).encoded, reliable: true)
        }
    }

    /// A peer is gone. A guest going costs its seat, which flies idle mid-fight;
    /// the host going ends the fight, since there is no fight without it.
    private func departed(_ peer: FightRoster.PeerName, byHost: Bool) {
        if (byHost || peer == roster.host) && !isHost && phase != .idle {
            transport.disconnect()
            reset()
            roster = FightRoster()
            phase = .ended(reason: "The host left")
            return
        }
        if var relay {
            relay.peerLeft(peer)
            self.relay = relay
        }
        if start != nil {
            stallNote = "\(roster.name(for: roster.seat(for: peer) ?? -1) ?? "A player") left"
            return
        }
        roster.leave(peer)
        if isHost { transport.send(RosterUpdate(roster: roster).encoded, reliable: true) }
    }
}
