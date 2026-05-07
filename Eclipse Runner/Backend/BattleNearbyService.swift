import Foundation
import MultipeerConnectivity

// MARK: - Nearby session state

enum NearbySessionState: Equatable {
    case idle
    case advertising                    // hosting, waiting for opponent to connect
    case browsing                       // looking for a host
    case connecting(peerName: String)   // handshake in progress
    case connected(peerName: String)    // both players ready
    case disconnected
}

// MARK: - Nearby message types

private enum NearbyMessageType: String, Codable {
    case handshake   // exchange pilot name + skin ID at connect
    case scoreUpdate // live score during game
    case finalScore  // submitted score at game end
}

private struct NearbyMessage: Codable {
    let type: NearbyMessageType
    let pilot: String
    let skinID: String
    let score: Int
    let seed: Int          // shared game seed (only used in handshake)
}

// MARK: - BattleNearbyService
// Uses MultipeerConnectivity: automatic BT + WiFi-Direct selection.
// The "host" advertises; the "guest" browses and connects.
// Both send score updates every 300ms during gameplay.

@MainActor
final class BattleNearbyService: NSObject, ObservableObject {

    static let shared = BattleNearbyService()

    // MARK: Published state
    @Published var sessionState: NearbySessionState = .idle
    @Published var nearbyPeers: [MCPeerID] = []   // found peers while browsing

    // MARK: Callbacks (wired by BattleCoordinator)
    var onOpponentScore: ((ScoreBroadcast) -> Void)?
    var onOpponentFinalScore: ((ScoreBroadcast) -> Void)?
    var onGameStart: ((Int) -> Void)?  // seed

    // MARK: Private
    private static let serviceType = "eclrunner-1v1"   // max 15 chars, lowercase + hyphens

    private var myPeerID: MCPeerID!
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private var myPilotName: String = ""
    private var mySkinID: String = "classic"
    private var gameSeed: Int = 0

    private var broadcastThrottle: Date = .distantPast
    private let throttleInterval: TimeInterval = 0.3

    // MARK: - Setup

    func setup(pilotName: String, skinID: String) {
        myPilotName = pilotName
        mySkinID = skinID
        myPeerID = MCPeerID(displayName: pilotName)
    }

    // MARK: - Host (advertise)

    func startHosting() {
        stopAll()
        gameSeed = Int.random(in: 1...1_000_000)
        let sess = makeSession()
        session = sess

        let advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: Self.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        sessionState = .advertising
        NSLog("[Nearby] Hosting with seed=%d", gameSeed)
    }

    // MARK: - Guest (browse)

    func startBrowsing() {
        stopAll()
        let sess = makeSession()
        session = sess

        let browser = MCNearbyServiceBrowser(
            peer: myPeerID,
            serviceType: Self.serviceType
        )
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser

        sessionState = .browsing
        NSLog("[Nearby] Browsing for hosts")
    }

    // MARK: - Connect to a found peer (guest → host)

    func connect(to peer: MCPeerID) {
        guard let browser, let session else { return }
        sessionState = .connecting(peerName: peer.displayName)
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
        NSLog("[Nearby] Inviting %@", peer.displayName)
    }

    // MARK: - Broadcast live score (throttled 300ms)

    func broadcastScore(_ score: Int) {
        let now = Date()
        guard now.timeIntervalSince(broadcastThrottle) >= throttleInterval else { return }
        broadcastThrottle = now
        let msg = NearbyMessage(type: .scoreUpdate, pilot: myPilotName,
                                skinID: mySkinID, score: score, seed: 0)
        send(msg)
    }

    // MARK: - Send final score

    func sendFinalScore(_ score: Int) {
        let msg = NearbyMessage(type: .finalScore, pilot: myPilotName,
                                skinID: mySkinID, score: score, seed: 0)
        send(msg, reliable: true)
        NSLog("[Nearby] Sent final score=%d", score)
    }

    // MARK: - Stop everything

    func stopAll() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        nearbyPeers = []
        sessionState = .idle
        onOpponentScore = nil
        onOpponentFinalScore = nil
        onGameStart = nil
        NSLog("[Nearby] Stopped all")
    }

    // MARK: - Private helpers

    private func makeSession() -> MCSession {
        let s = MCSession(peer: myPeerID,
                          securityIdentity: nil,
                          encryptionPreference: .required)
        s.delegate = self
        return s
    }

    private func send(_ msg: NearbyMessage, reliable: Bool = false) {
        guard let session, !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(msg) else { return }
        let mode: MCSessionSendDataMode = reliable ? .reliable : .unreliable
        do {
            try session.send(data, toPeers: session.connectedPeers, with: mode)
        } catch {
            NSLog("[Nearby] Send error: %@", error.localizedDescription)
        }
    }

    private func sendHandshake(to peer: MCPeerID) {
        let msg = NearbyMessage(type: .handshake, pilot: myPilotName,
                                skinID: mySkinID, score: 0, seed: gameSeed)
        guard let session, let data = try? JSONEncoder().encode(msg) else { return }
        do {
            try session.send(data, toPeers: [peer], with: .reliable)
            NSLog("[Nearby] Sent handshake to %@ seed=%d", peer.displayName, gameSeed)
        } catch {
            NSLog("[Nearby] Handshake send error: %@", error.localizedDescription)
        }
    }

    private func handle(message msg: NearbyMessage, from peer: MCPeerID) {
        switch msg.type {
        case .handshake:
            NSLog("[Nearby] Handshake from %@ seed=%d", msg.pilot, msg.seed)
            // Guest receives host's seed and starts the game
            if msg.seed > 0 { gameSeed = msg.seed }
            sessionState = .connected(peerName: msg.pilot)
            onGameStart?(gameSeed)

        case .scoreUpdate:
            let broadcast = ScoreBroadcast(pilot: msg.pilot, score: msg.score, skinID: msg.skinID)
            onOpponentScore?(broadcast)

        case .finalScore:
            NSLog("[Nearby] Final score from %@: %d", msg.pilot, msg.score)
            let broadcast = ScoreBroadcast(pilot: msg.pilot, score: msg.score, skinID: msg.skinID)
            onOpponentFinalScore?(broadcast)
        }
    }
}

// MARK: - MCSessionDelegate

extension BattleNearbyService: MCSessionDelegate {

    nonisolated func session(_ session: MCSession,
                              peer peerID: MCPeerID,
                              didChange state: MCSessionState) {
        NSLog("[Nearby] Peer %@ state=%d", peerID.displayName, state.rawValue)
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch state {
            case .connected:
                self.sessionState = .connected(peerName: peerID.displayName)
                // Host sends handshake with seed; guest waits for it
                if self.advertiser != nil {
                    self.sendHandshake(to: peerID)
                    self.onGameStart?(self.gameSeed)
                }
            case .notConnected:
                self.sessionState = .disconnected
            case .connecting:
                self.sessionState = .connecting(peerName: peerID.displayName)
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession,
                              didReceive data: Data,
                              fromPeer peerID: MCPeerID) {
        guard let msg = try? JSONDecoder().decode(NearbyMessage.self, from: data) else { return }
        Task { @MainActor [weak self] in
            self?.handle(message: msg, from: peerID)
        }
    }

    nonisolated func session(_ session: MCSession,
                              didReceive stream: InputStream,
                              withName streamName: String,
                              fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession,
                              didStartReceivingResourceWithName resourceName: String,
                              fromPeer peerID: MCPeerID,
                              with progress: Progress) {}

    nonisolated func session(_ session: MCSession,
                              didFinishReceivingResourceWithName resourceName: String,
                              fromPeer peerID: MCPeerID,
                              at localURL: URL?,
                              withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension BattleNearbyService: MCNearbyServiceAdvertiserDelegate {

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                 didNotStartAdvertisingPeer error: Error) {
        NSLog("[Nearby] Advertiser error: %@", error.localizedDescription)
        Task { @MainActor [weak self] in
            self?.sessionState = .idle
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                 didReceiveInvitationFromPeer peerID: MCPeerID,
                                 withContext context: Data?,
                                 invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("[Nearby] Received invitation from %@", peerID.displayName)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.sessionState = .connecting(peerName: peerID.displayName)
            invitationHandler(true, self.session)
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension BattleNearbyService: MCNearbyServiceBrowserDelegate {

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                              didNotStartBrowsingForPeers error: Error) {
        NSLog("[Nearby] Browser error: %@", error.localizedDescription)
        Task { @MainActor [weak self] in
            self?.sessionState = .idle
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                              foundPeer peerID: MCPeerID,
                              withDiscoveryInfo info: [String: String]?) {
        NSLog("[Nearby] Found peer: %@", peerID.displayName)
        Task { @MainActor [weak self] in
            guard let self, !self.nearbyPeers.contains(peerID) else { return }
            self.nearbyPeers.append(peerID)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                              lostPeer peerID: MCPeerID) {
        NSLog("[Nearby] Lost peer: %@", peerID.displayName)
        Task { @MainActor [weak self] in
            self?.nearbyPeers.removeAll { $0 == peerID }
        }
    }
}
