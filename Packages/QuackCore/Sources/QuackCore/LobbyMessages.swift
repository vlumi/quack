import Foundation

/// What every device must agree before a tick runs, sent once and reliably by
/// the host: the seed, the roster, the options, and the host's dials. JSON,
/// because it is sent once and a lobby message that is easy to read is easier
/// to debug on two phones.
public struct FightStart: Equatable, Sendable, Codable {
    public var seed: UInt64
    public var roster: FightRoster
    public var humans: Int
    public var rivals: Int
    public var guns: Bool
    public var duration: Double
    /// The host's tuning values by dial id, so both sims fly the same numbers.
    public var tuning: [String: Double]

    public init(
        seed: UInt64, roster: FightRoster, options: DuckfightOptions, tuning: [String: Double]
    ) {
        self.seed = seed
        self.roster = roster
        humans = options.humans
        rivals = options.rivals
        guns = options.guns
        duration = options.duration
        self.tuning = tuning
    }

    public var options: DuckfightOptions {
        var o = DuckfightOptions()
        o.humans = humans
        o.rivals = rivals
        o.guns = guns
        o.duration = duration
        return o
    }

    /// The fight every device builds from this, identically.
    public func makeFight() -> Practice {
        var p = Practice(seed: seed, mode: .duckfight, duckfight: options)
        p.apply(Tuning(values: tuning))
        return p
    }

    static let tag: UInt8 = 200
    public var encoded: [UInt8] { LobbyWire.encode(self, tag: FightStart.tag) }
    public init?(bytes: [UInt8]) {
        guard let v: FightStart = LobbyWire.decode(bytes, tag: FightStart.tag) else { return nil }
        self = v
    }
}

/// A guest asking in, with the name to show.
public struct JoinRequest: Equatable, Sendable, Codable {
    public var name: String
    public init(name: String) { self.name = name }
    static let tag: UInt8 = 201
    public var encoded: [UInt8] { LobbyWire.encode(self, tag: JoinRequest.tag) }
    public init?(bytes: [UInt8]) {
        guard let v: JoinRequest = LobbyWire.decode(bytes, tag: JoinRequest.tag) else { return nil }
        self = v
    }
}

/// The host's roster, pushed to guests whenever it changes.
public struct RosterUpdate: Equatable, Sendable, Codable {
    public var roster: FightRoster
    /// Why a guest was not seated, if it was not.
    public var refused: String?
    public init(roster: FightRoster, refused: String? = nil) {
        self.roster = roster
        self.refused = refused
    }
    static let tag: UInt8 = 202
    public var encoded: [UInt8] { LobbyWire.encode(self, tag: RosterUpdate.tag) }
    public init?(bytes: [UInt8]) {
        guard let v: RosterUpdate = LobbyWire.decode(bytes, tag: RosterUpdate.tag) else {
            return nil
        }
        self = v
    }
}

/// Announcing a departure rather than being noticed missing. The host leaving
/// ends the fight for everyone.
public struct LeaveNotice: Equatable, Sendable, Codable {
    public var byHost: Bool
    public init(byHost: Bool) { self.byHost = byHost }
    static let tag: UInt8 = 203
    public var encoded: [UInt8] { LobbyWire.encode(self, tag: LeaveNotice.tag) }
    public init?(bytes: [UInt8]) {
        guard let v: LeaveNotice = LobbyWire.decode(bytes, tag: LeaveNotice.tag) else { return nil }
        self = v
    }
}

enum LobbyWire {
    static func encode<T: Encodable>(_ value: T, tag: UInt8) -> [UInt8] {
        guard let data = try? JSONEncoder().encode(value) else { return [] }
        return [tag] + [UInt8](data)
    }

    static func decode<T: Decodable>(_ bytes: [UInt8], tag: UInt8) -> T? {
        guard bytes.first == tag else { return nil }
        return try? JSONDecoder().decode(T.self, from: Data(bytes.dropFirst()))
    }
}
