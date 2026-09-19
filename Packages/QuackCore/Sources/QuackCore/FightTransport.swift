import Foundation

/// What the session needs from a network: bytes to everyone, reliably or not,
/// and word of peers coming and going. Multipeer implements it in the app; a
/// loopback implements it in tests, so the whole lobby and fight loop runs in
/// one process.
public protocol FightTransport: AnyObject {
    /// This device's key: what peers call it.
    var me: FightRoster.PeerName { get }
    var connectedPeers: [FightRoster.PeerName] { get }
    var delegate: FightTransportDelegate? { get set }

    func startHosting()
    func startBrowsing()
    func stopDiscovery()
    func disconnect()
    /// Reliable traffic is ordered and arrives; unreliable may be dropped or reordered.
    func send(_ bytes: [UInt8], reliable: Bool)
}

/// Called on the main actor.
@MainActor
public protocol FightTransportDelegate: AnyObject {
    func transport(didReceive bytes: [UInt8], from peer: FightRoster.PeerName)
    func transport(peerJoined peer: FightRoster.PeerName)
    func transport(peerLeft peer: FightRoster.PeerName)
}
