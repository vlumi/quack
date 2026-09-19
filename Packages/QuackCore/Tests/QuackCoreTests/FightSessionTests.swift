import XCTest

@testable import QuackCore

/// Transports wired to each other in one process: a send lands on every
/// other transport's delegate at once, reliably or not alike.
@MainActor
final class Loopback: FightTransport {
    final class Hub {
        var members: [Loopback] = []
    }

    let me: FightRoster.PeerName
    let hub: Hub
    weak var delegate: FightTransportDelegate?
    var connected = false
    var sent: [[UInt8]] = []

    init(me: FightRoster.PeerName, hub: Hub) {
        self.me = me
        self.hub = hub
        hub.members.append(self)
    }

    var connectedPeers: [FightRoster.PeerName] {
        hub.members.filter { $0 !== self && $0.connected }.map(\.me)
    }
    func startHosting() { connected = true }
    func startBrowsing() {
        connected = true
        for other in hub.members where other !== self && other.connected {
            delegate?.transport(peerJoined: other.me)
            other.delegate?.transport(peerJoined: me)
        }
    }
    func stopDiscovery() {}
    func disconnect() {
        connected = false
        for other in hub.members where other !== self && other.connected {
            other.delegate?.transport(peerLeft: me)
        }
    }
    func send(_ bytes: [UInt8], reliable: Bool) {
        sent.append(bytes)
        for other in hub.members where other !== self && other.connected {
            other.delegate?.transport(didReceive: bytes, from: me)
        }
    }
}

@MainActor
final class FightSessionTests: XCTestCase {
    private func pair() -> (FightSession, FightSession) {
        let hub = Loopback.Hub()
        let host = FightSession(transport: Loopback(me: "host#1", hub: hub), name: "Ville")
        let guest = FightSession(transport: Loopback(me: "guest#2", hub: hub), name: "Duck")
        return (host, guest)
    }

    private func seated() -> (FightSession, FightSession) {
        let (host, guest) = pair()
        host.host()
        guest.join()
        guest.askToJoin("host#1")
        return (host, guest)
    }

    func testAGuestFindsTheHostAsksInAndIsSeatedWithTheRosterPushed() {
        let (host, guest) = pair()
        host.host()
        XCTAssertEqual(host.phase, .hosting)
        XCTAssertEqual(host.roster.seat(for: "host#1"), 0)
        guest.join()
        XCTAssertEqual(guest.visibleHosts, ["host#1"])
        XCTAssertEqual(guest.phase, .joining)
        guest.askToJoin("host#1")
        XCTAssertEqual(guest.phase, .lobby)
        XCTAssertEqual(guest.roster, host.roster)
        XCTAssertEqual(guest.mySeat, 1)
        XCTAssertEqual(host.roster.name(for: 1), "Duck")
    }

    func testAFullFightRefusesAFifthWithAReason() {
        let hub = Loopback.Hub()
        let host = FightSession(transport: Loopback(me: "h", hub: hub), name: "H")
        host.host()
        let guests = (1...4).map {
            FightSession(transport: Loopback(me: "g\($0)", hub: hub), name: "G\($0)")
        }
        for g in guests {
            g.join()
            g.askToJoin("h")
        }
        XCTAssertEqual(host.roster.humanCount, 4)
        XCTAssertEqual(guests[2].phase, .lobby)
        XCTAssertEqual(guests[3].phase, .joining)
        XCTAssertEqual(guests[3].refusal, "The fight is full")
    }

    func testTheHostStartsAndBothBuildTheSameFightThenThumbsAndSnapshotsFlow() throws {
        let (host, guest) = seated()
        var hostFight: Practice?
        var guestFight: Practice?
        host.whenStarted { hostFight = $0.makeFight() }
        guest.whenStarted { guestFight = $0.makeFight() }
        var options = DuckfightOptions()
        options.rivals = 1
        host.startFight(seed: 9, options: options, tuning: Tuning().values)
        XCTAssertEqual(host.phase, .fighting)
        XCTAssertEqual(guest.phase, .fighting)
        var h = try XCTUnwrap(hostFight)
        var g = try XCTUnwrap(guestFight)
        XCTAssertEqual(h, g)
        XCTAssertEqual(h.pilots.count, 3, "two humans and the rival")
        XCTAssertTrue(host.isHost)
        XCTAssertFalse(guest.isHost)
        // The guest pulls; two frames later the host has it.
        guest.publish(PlaneInput(pitch: 1, power: true, takeOff: 1))
        guest.publish(PlaneInput(pitch: 1, power: true, takeOff: 1))
        let inputs = host.hostInputs(mine: PlaneInput(fire: true))
        XCTAssertEqual(inputs.count, 2)
        XCTAssertTrue(inputs[0].fire)
        XCTAssertEqual(inputs[1].takeOff, 1)
        // The host steps and broadcasts; the guest's view catches up.
        for tick in 1...12 {
            h.advance(inputs: host.hostInputs(mine: .idle))
            host.broadcast(h, tick: tick)
        }
        var shown: FightSnapshot?
        for _ in 0..<20 { shown = guest.view(advancedBy: 1 / 60) }
        let snap = try XCTUnwrap(shown)
        snap.apply(to: &g)
        XCTAssertEqual(
            g.pilots[1].plane.x, h.pilots[1].plane.x, accuracy: 5, "the guest sees its plane roll")
        XCTAssertNil(guest.stallNote)
        for _ in 0..<70 { _ = guest.view(advancedBy: 1 / 60) }
        XCTAssertNotNil(guest.stallNote, "a quiet host is said so")
        host.broadcast(h, tick: 15)
        _ = guest.view(advancedBy: 1 / 60)
        XCTAssertNil(guest.stallNote, "and the note clears when it speaks again")
    }

    func testAGuestLeavingIsDroppedFromTheLobbyAndTheHostLeavingEndsItForTheGuest() {
        let (host, guest) = seated()
        guest.leave()
        XCTAssertEqual(host.roster.humanCount, 1)
        XCTAssertEqual(guest.phase, .idle)
        let (host2, guest2) = seated()
        host2.startFight(seed: 1, options: DuckfightOptions(), tuning: [:])
        host2.leave()
        XCTAssertEqual(guest2.phase, .ended(reason: "The host left"))
        XCTAssertNil(guest2.start)
    }

    func testAGuestDroppingMidFightFliesIdleAndIsNoted() {
        let (host, guest) = seated()
        host.startFight(seed: 1, options: DuckfightOptions(), tuning: [:])
        guest.publish(PlaneInput(pitch: 1))
        guest.publish(PlaneInput(pitch: 1))
        XCTAssertEqual(host.hostInputs(mine: .idle)[1].pitch, 1)
        guest.transport.disconnect()
        XCTAssertEqual(host.hostInputs(mine: .idle)[1], .idle)
        XCTAssertEqual(host.stallNote, "Duck left")
        XCTAssertEqual(host.roster.humanCount, 2, "the roster is frozen mid-fight")
    }
}
