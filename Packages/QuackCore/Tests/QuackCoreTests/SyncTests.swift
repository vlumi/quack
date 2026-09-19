import XCTest

@testable import QuackCore

final class SyncTests: XCTestCase {
    private func roster() -> FightRoster {
        var r = FightRoster()
        try? r.join("host#1", name: "Ville")
        try? r.join("guest#2", name: "Duck")
        return r
    }

    func testAnInputRoundTripsThroughTwoBytes() throws {
        let inputs = [
            PlaneInput(pitch: 0.37, power: true, fire: false, takeOff: 0),
            PlaneInput(pitch: -1, power: false, fire: true, takeOff: 1),
            PlaneInput(pitch: 0, power: true, fire: true, takeOff: -1),
        ]
        for input in inputs {
            let wire = PlaneInputWire(input)
            XCTAssertEqual(wire.bytes.count, 2)
            let back = try XCTUnwrap(PlaneInputWire(bytes: wire.bytes)).input
            XCTAssertEqual(back.pitch, input.pitch, accuracy: 0.005)
            XCTAssertEqual(back.power, input.power)
            XCTAssertEqual(back.fire, input.fire)
            XCTAssertEqual(back.takeOff, input.takeOff)
        }
        XCTAssertNil(PlaneInputWire(bytes: [1]))
    }

    func testAnInputPacketCarriesHistoryAndRejectsGarbage() throws {
        let packet = InputPacket(
            tick: 41, inputs: [PlaneInputWire(PlaneInput(pitch: 1)), PlaneInputWire(.idle)])
        let bytes = packet.encoded
        XCTAssertEqual(bytes.count, 1 + 4 + 1 + 4)
        XCTAssertEqual(try XCTUnwrap(InputPacket(bytes: bytes)), packet)
        XCTAssertNil(InputPacket(bytes: Array(bytes.dropLast())), "clipped")
        XCTAssertNil(InputPacket(bytes: bytes + [0]), "trailing garbage")
        XCTAssertNil(InputPacket(bytes: [9] + bytes.dropFirst()), "wrong tag")
    }

    func testTheRosterSeatsInJoinOrderAndRefusesAFullFieldOrADouble() {
        var r = FightRoster()
        XCTAssertNoThrow(try r.join("a", name: "A"))
        XCTAssertNoThrow(try r.join("b", name: "B"))
        XCTAssertEqual(r.host, "a")
        XCTAssertEqual(r.seat(for: "b"), 1)
        XCTAssertEqual(r.name(for: 1), "B")
        XCTAssertThrowsError(try r.join("a", name: "A")) {
            XCTAssertEqual($0 as? FightRoster.JoinError, .alreadyJoined)
        }
        XCTAssertNoThrow(try r.join("c", name: "C"))
        XCTAssertNoThrow(try r.join("d", name: "D"))
        XCTAssertThrowsError(try r.join("e", name: "E")) {
            XCTAssertEqual($0 as? FightRoster.JoinError, .fieldFull)
        }
        r.leave("b")
        XCTAssertEqual(r.seats, [0, 2, 3])
        XCTAssertEqual(r.peers, ["a", "c", "d"])
        XCTAssertEqual(r.peer(for: 2), "c")
        XCTAssertNoThrow(try r.join("e", name: "E"))
        XCTAssertEqual(r.seat(for: "e"), 4, "seats are never reused")
    }

    func testTheHostHoldsTheNewestInputPerSeatAndIgnoresOldOrUnseatedPackets() {
        var relay = HostRelay(roster: roster(), me: "host#1")
        XCTAssertEqual(relay.input(for: 1), .idle)
        let pull = InputPacket(tick: 5, inputs: [PlaneInputWire(PlaneInput(pitch: 1, power: true))])
            .encoded
        XCTAssertTrue(relay.receive(pull, from: "guest#2"))
        XCTAssertEqual(relay.input(for: 1).pitch, 1)
        let older = InputPacket(tick: 3, inputs: [PlaneInputWire(.idle)]).encoded
        XCTAssertFalse(relay.receive(older, from: "guest#2"), "reordered, superseded")
        XCTAssertEqual(relay.input(for: 1).pitch, 1)
        XCTAssertFalse(relay.receive(pull, from: "stranger"), "not seated")
        XCTAssertFalse(relay.receive(pull, from: "host#1"), "not from itself")
        XCTAssertEqual(relay.inputs(mine: PlaneInput(fire: true)).map(\.fire), [true, false])
        relay.peerLeft("guest#2")
        XCTAssertEqual(relay.input(for: 1), .idle)
        XCTAssertTrue(relay.shouldBroadcast(after: 6))
        XCTAssertFalse(relay.shouldBroadcast(after: 7))
    }

    func testASnapshotRoundTripsThroughItsBytesAndLaysOverAClientsFight() throws {
        var o = DuckfightOptions()
        o.humans = 2
        o.rivals = 1
        var host = Practice(seed: 5, mode: .duckfight, duckfight: o)
        host.windTuning.strength = 0
        for _ in 0..<120 {
            host.advance(inputs: [PlaneInput(power: true, fire: true, takeOff: 1), .idle])
        }
        let snap = FightSnapshot(of: host, tick: 120)
        XCTAssertEqual(snap.seats.count, 3)
        XCTAssertFalse(snap.seats[0].rounds.isEmpty, "rounds travel")
        let bytes = snap.encoded
        let back = try XCTUnwrap(FightSnapshot(bytes: bytes))
        XCTAssertEqual(back.tick, 120)
        XCTAssertEqual(back.seats[0].plane.x, snap.seats[0].plane.x, accuracy: 0.01)
        XCTAssertEqual(back.seats[0].doing, snap.seats[0].doing)
        XCTAssertEqual(back.seats[0].rounds.count, snap.seats[0].rounds.count)
        XCTAssertNil(FightSnapshot(bytes: Array(bytes.dropLast(3))))
        var shot = host
        shot.pilots[1].falling = true
        XCTAssertEqual(FightSnapshot(of: shot, tick: 1).seats[1].doing, .falling)
        shot.pilots[1].down = true
        let downed = FightSnapshot(of: shot, tick: 1)
        XCTAssertEqual(downed.seats[1].doing, .down)
        var laid = host
        downed.apply(to: &laid)
        XCTAssertTrue(laid.pilots[1].down)
        XCTAssertNil(FightSnapshot(bytes: bytes + [1]))
        var client = Practice(seed: 5, mode: .duckfight, duckfight: o)
        back.apply(to: &client)
        XCTAssertEqual(client.pilots[0].plane.x, back.seats[0].plane.x, accuracy: 1e-6)
        XCTAssertEqual(client.pilots[0].ammo, host.pilots[0].ammo)
        XCTAssertEqual(client.pilots[0].bullets.count, host.pilots[0].bullets.count)
        XCTAssertLessThan(bytes.count, 1500, "one datagram: \(bytes.count) bytes")
    }

    func testTheClientSendsEveryOtherFrameWithHistoryAndPlaysSnapshotsOutSmoothly() throws {
        var view = ClientView(roster: roster(), me: "guest#2")
        XCTAssertEqual(view.seat, 1)
        XCTAssertNil(view.publish(PlaneInput(pitch: 1)))
        let bytes = try XCTUnwrap(view.publish(PlaneInput(pitch: 0.5)))
        let packet = try XCTUnwrap(InputPacket(bytes: bytes))
        XCTAssertEqual(packet.tick, 2)
        XCTAssertEqual(packet.inputs.map { $0.input.pitch }, [0.5, 1])
        XCTAssertNil(view.view(advancedBy: 1 / 60), "nothing yet")
        func snap(_ tick: Int, x: Double) -> FightSnapshot {
            let seat = FightSnapshot.Seat(
                plane: PlaneState(x: x, y: 50, heading: 0, speed: 40), doing: .flying, health: 2,
                kills: 0, downs: 0, ammo: 40, fuel: 100, respawnIn: 0, rounds: [])
            return FightSnapshot(
                tick: tick, elapsed: Double(tick) / 60, seats: [seat, seat], finished: false)
        }
        XCTAssertFalse(view.receive(snap(3, x: 0).encoded, from: "guest#2"), "only the host's word")
        XCTAssertTrue(view.receive(snap(3, x: 0).encoded, from: "host#1"))
        XCTAssertTrue(view.receive(snap(6, x: 2).encoded, from: "host#1"))
        XCTAssertFalse(
            view.receive(snap(6, x: 2).encoded, from: "host#1"),
            "an older or same tick is superseded")
        XCTAssertTrue(view.receive(snap(9, x: 4).encoded, from: "host#1"))
        XCTAssertTrue(view.receive(snap(12, x: 6).encoded, from: "host#1"))
        let shown = try XCTUnwrap(view.view(advancedBy: 1 / 60))
        XCTAssertLessThan(Double(shown.tick), 12, "behind the newest by the lag")
        var xs: [Double] = []
        for _ in 0..<6 {
            xs.append(try XCTUnwrap(view.view(advancedBy: 1 / 60)).seats[0].plane.x)
        }
        XCTAssertEqual(xs, xs.sorted(), "the view never moves backwards")
        XCTAssertFalse(view.isStarved)
        XCTAssertEqual(view.newestTick, 12)
        XCTAssertGreaterThanOrEqual(view.worstGapMs, 0)
        _ = view.view(advancedBy: 1.5)
        XCTAssertTrue(view.isStarved)
        // Ten more frames of thumbs: the packet still carries only the newest eight.
        var last: [UInt8]?
        for i in 0..<10 { if let b = view.publish(PlaneInput(pitch: Double(i % 2))) { last = b } }
        XCTAssertEqual(try XCTUnwrap(InputPacket(bytes: try XCTUnwrap(last))).inputs.count, 8)
    }

    func testLobbyMessagesRoundTripAndAFightStartBuildsTheSameFightEverywhere() throws {
        var options = DuckfightOptions()
        options.humans = 2
        options.rivals = 1
        options.guns = true
        var tuning = Tuning()
        tuning.flight.thrust = 19
        let start = FightStart(seed: 77, roster: roster(), options: options, tuning: tuning.values)
        let back = try XCTUnwrap(FightStart(bytes: start.encoded))
        XCTAssertEqual(back, start)
        var a = back.makeFight(), b = start.makeFight()
        XCTAssertEqual(a.model.flight.tuning.thrust, 19)
        XCTAssertEqual(a.pilots.count, 3)
        XCTAssertFalse(a.guns.isEmpty)
        for _ in 0..<60 {
            a.advance(inputs: [PlaneInput(power: true, takeOff: 1), .idle])
            b.advance(inputs: [PlaneInput(power: true, takeOff: 1), .idle])
        }
        XCTAssertEqual(a, b)
        XCTAssertEqual(
            try XCTUnwrap(JoinRequest(bytes: JoinRequest(name: "Duck").encoded)).name, "Duck")
        let update = RosterUpdate(roster: roster(), refused: "full")
        XCTAssertEqual(try XCTUnwrap(RosterUpdate(bytes: update.encoded)), update)
        XCTAssertEqual(
            try XCTUnwrap(LeaveNotice(bytes: LeaveNotice(byHost: true).encoded)).byHost, true)
        XCTAssertNil(FightStart(bytes: JoinRequest(name: "x").encoded), "tags keep messages apart")
    }
}
