import Foundation

/// Who is in the fight and which seat each device flies. The host is the
/// first entry and hands out seats in join order; seats are never renumbered,
/// because a seat is also a livery and a place on the standings. Transport-free:
/// a peer is a string.
public struct FightRoster: Equatable, Sendable, Codable {
    public typealias PeerName = String

    public struct Entry: Equatable, Sendable, Codable {
        public let peer: PeerName
        public let seat: Int
        /// The friendly name the lobby shows.
        public let name: String

        public init(peer: PeerName, seat: Int, name: String) {
            self.peer = peer
            self.seat = seat
            self.name = name
        }
    }

    /// The most seats a fight holds, humans and rivals together.
    public static let maxSeats = 4

    public private(set) var entries: [Entry] = []

    public init() {}

    public var host: PeerName? { entries.first?.peer }
    public var peers: [PeerName] { entries.map(\.peer) }
    /// Human seats, in seat order: the order the sim takes inputs in.
    public var seats: [Int] { entries.map(\.seat).sorted() }
    public var humanCount: Int { entries.count }

    public func seat(for peer: PeerName) -> Int? { entries.first { $0.peer == peer }?.seat }
    public func peer(for seat: Int) -> PeerName? { entries.first { $0.seat == seat }?.peer }
    public func name(for seat: Int) -> String? { entries.first { $0.seat == seat }?.name }

    public enum JoinError: Error, Equatable {
        case fieldFull
        case alreadyJoined
    }

    /// Seat a device: the next seat number, or a reason it cannot be seated.
    public mutating func join(_ peer: PeerName, name: String) throws(JoinError) {
        guard !entries.contains(where: { $0.peer == peer }) else { throw .alreadyJoined }
        guard entries.count < FightRoster.maxSeats else { throw .fieldFull }
        let seat = (entries.map(\.seat).max() ?? -1) + 1
        entries.append(Entry(peer: peer, seat: seat, name: name))
    }

    public mutating func leave(_ peer: PeerName) {
        entries.removeAll { $0.peer == peer }
    }
}
