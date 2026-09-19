import Foundation
import MultipeerConnectivity
import QuackCore

#if canImport(UIKit)
import UIKit
#endif

/// MultipeerConnectivity wrapped down to `FightTransport`, after Skid Jam's:
/// infrastructure Wi-Fi when peers share a network, peer-to-peer Wi-Fi or
/// Bluetooth when they do not, so two phones on a train still find each
/// other. Every call into Multipeer goes through one serial queue, since
/// sends and teardowns block and froze Skid's lobby three times from the main
/// thread; everything coming out is hopped to the main actor.
public final class MultipeerTransport: NSObject, FightTransport {
    /// Bonjour service type; must match `NSBonjourServices` in the Info.plist
    /// exactly, or iOS 14+ silently refuses to browse.
    public static let serviceType = "quack-fight"

    public let me: FightRoster.PeerName
    public weak var delegate: FightTransportDelegate?

    private let localPeer: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    public init(displayName: String) {
        let trimmed = String(displayName.prefix(60))
        localPeer = MCPeerID(displayName: trimmed.isEmpty ? "Quack" : trimmed)
        me = localPeer.displayName
        session = MCSession(peer: localPeer, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    public var connectedPeers: [FightRoster.PeerName] {
        session.connectedPeers.map(\.displayName)
    }

    /// Host: advertise and accept anyone who asks. An invitation dialog on a
    /// phone held by someone sitting next to you is friction, not security;
    /// the roster's cap is what bounds who gets in.
    public func startHosting() {
        stopDiscovery()
        let advertiser = MCNearbyServiceAdvertiser(
            peer: localPeer, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser.delegate = self
        self.advertiser = advertiser
        Self.queue.async { advertiser.startAdvertisingPeer() }
    }

    /// Guest: look for hosts and invite ourselves in. Only the guest invites;
    /// both sides inviting makes two sessions and Multipeer drops one.
    public func startBrowsing() {
        stopDiscovery()
        let browser = MCNearbyServiceBrowser(peer: localPeer, serviceType: Self.serviceType)
        browser.delegate = self
        self.browser = browser
        Self.queue.async { browser.startBrowsingForPeers() }
    }

    public func stopDiscovery() {
        let advertiser = advertiser
        let browser = browser
        self.advertiser = nil
        self.browser = nil
        guard advertiser != nil || browser != nil else { return }
        Self.queue.async {
            advertiser?.stopAdvertisingPeer()
            browser?.stopBrowsingForPeers()
        }
    }

    public func disconnect() {
        stopDiscovery()
        let session = session
        Self.queue.async { session.disconnect() }
    }

    public func send(_ bytes: [UInt8], reliable: Bool) {
        let peers = session.connectedPeers
        guard !peers.isEmpty else { return }
        let data = Data(bytes)
        let mode: MCSessionSendDataMode = reliable ? .reliable : .unreliable
        let session = session
        Self.queue.async {
            // A failed send is not worth propagating: unreliable traffic is
            // repaired by the next packet, and a reliable one failing means the
            // peer is gone, which arrives separately.
            try? session.send(data, toPeers: peers, with: mode)
        }
    }

    /// Serial, so reliable messages keep their order.
    private static let queue = DispatchQueue(label: "fi.misaki.quack.mc")
}

extension MultipeerTransport: MCSessionDelegate {
    public func session(
        _ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState
    ) {
        let name = peerID.displayName
        Task { @MainActor [weak self] in
            switch state {
            case .connected: self?.delegate?.transport(peerJoined: name)
            case .notConnected: self?.delegate?.transport(peerLeft: name)
            case .connecting: break
            @unknown default: break
            }
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let bytes = [UInt8](data)
        let name = peerID.displayName
        Task { @MainActor [weak self] in
            self?.delegate?.transport(didReceive: bytes, from: name)
        }
    }

    public func session(
        _ session: MCSession, didReceive stream: InputStream, withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    public func session(
        _ session: MCSession, didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID, with progress: Progress
    ) {}

    public func session(
        _ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?
    ) {}
}

extension MultipeerTransport: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        invitationHandler(true, session)
    }
}

extension MultipeerTransport: MCNearbyServiceBrowserDelegate {
    public func browser(
        _ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        let session = session
        Self.queue.async { browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15) }
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

/// What to call this device, and, separately, how to tell it apart: two
/// iPhones are both "iPhone", so the key carries a short random suffix and
/// the lobby shows only the part before it.
public enum DeviceName {
    static let separator: Character = "#"

    public static var friendly: String {
        #if canImport(UIKit)
        let name = UIDevice.current.name
        #else
        let name = Host.current().localizedName ?? ""
        #endif
        return name.isEmpty ? "Quack pilot" : name
    }

    /// Unique per launch: enough to tell the devices in one fight apart, and
    /// short of a device identifier.
    public static func uniqueKey(suffixLength: Int = 4) -> String {
        let alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
        let suffix = String((0..<suffixLength).map { _ in alphabet.randomElement() ?? "x" })
        let room = max(1, 60 - suffixLength - 1)
        return "\(friendly.prefix(room))\(separator)\(suffix)"
    }

    public static func display(_ peer: String) -> String {
        guard let index = peer.lastIndex(of: separator) else { return peer }
        let name = String(peer[peer.startIndex..<index])
        return name.isEmpty ? peer : name
    }
}
