import Foundation

// MARK: - Broadcast payload

struct ScoreBroadcast: Codable {
    let pilot: String
    let score: Int
    let skinID: String
}

// MARK: - BattleRealtimeService
// Uses Supabase Realtime WebSocket broadcast channel.
// One WS connection per battle room, shared between both players.
// Impact: ~200ms handshake on connect, then idle (keep-alive only).
// Score messages: ~80 bytes each, throttled to max 1 per 300ms.

final class BattleRealtimeService {

    static let shared = BattleRealtimeService()
    private init() {}

    // MARK: State
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isConnected = false
    private var pendingRoomID: String?

    private var broadcastThrottle: Date = .distantPast
    private let throttleInterval: TimeInterval = 0.3   // 300ms max

    var onOpponentScore: ((ScoreBroadcast) -> Void)?
    var myPilotName: String = ""

    // MARK: - Connect

    func connect(roomID: String, myPilotName: String) {
        guard let cfg = SupabaseConfig.current else { return }
        disconnect()
        self.myPilotName = myPilotName
        self.pendingRoomID = roomID

        // Build WebSocket URL: wss://<ref>.supabase.co/realtime/v1/websocket
        let projectRef = cfg.projectURL
            .replacingOccurrences(of: "https://", with: "")
            .components(separatedBy: ".").first ?? ""
        let wsURL = "wss://\(projectRef).supabase.co/realtime/v1/websocket?apikey=\(cfg.anonKey)&vsn=1.0.0"

        guard let url = URL(string: wsURL) else {
            NSLog("[Realtime] Invalid WS URL")
            return
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()

        NSLog("[Realtime] Connecting for room=%@", roomID)
        joinChannel(roomID: roomID, cfg: cfg)
        receiveLoop()
    }

    // MARK: - Disconnect

    func disconnect() {
        guard isConnected || webSocketTask != nil else { return }
        NSLog("[Realtime] Disconnecting")
        isConnected = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        session = nil
        onOpponentScore = nil
    }

    // MARK: - Broadcast my score (throttled)

    func broadcastScore(_ score: Int, skinID: String) {
        let now = Date()
        guard now.timeIntervalSince(broadcastThrottle) >= throttleInterval else { return }
        broadcastThrottle = now
        guard isConnected, let roomID = pendingRoomID else { return }

        let payload = ScoreBroadcast(pilot: myPilotName, score: score, skinID: skinID)
        guard let payloadData = try? JSONEncoder().encode(payload),
              let payloadJSON = String(data: payloadData, encoding: .utf8) else { return }

        let msg: [String: Any] = [
            "topic": "realtime:battle:\(roomID)",
            "event": "broadcast",
            "payload": [
                "type": "broadcast",
                "event": "score_update",
                "payload": payloadJSON
            ],
            "ref": UUID().uuidString
        ]
        sendJSON(msg)
    }

    // MARK: - Private: join channel after WS open

    private func joinChannel(roomID: String, cfg: SupabaseConfig) {
        let joinMsg: [String: Any] = [
            "topic": "realtime:battle:\(roomID)",
            "event": "phx_join",
            "payload": [
                "config": [
                    "broadcast": ["self": false],
                    "presence": ["key": ""]
                ],
                "access_token": cfg.anonKey
            ],
            "ref": "1"
        ]
        // Small delay so WS handshake completes before join
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendJSON(joinMsg)
        }
    }

    // MARK: - Private: send

    private func sendJSON(_ dict: [String: Any]) {
        guard let task = webSocketTask,
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        task.send(.string(text)) { error in
            if let error {
                NSLog("[Realtime] Send error: %@", error.localizedDescription)
            }
        }
    }

    // MARK: - Private: receive loop

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                NSLog("[Realtime] Receive error: %@", error.localizedDescription)
                return
            case .success(let message):
                self.handleMessage(message)
                self.receiveLoop()   // keep listening
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message else { return }
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        let event = json["event"] as? String ?? ""

        if event == "phx_reply" {
            // Channel join confirmation
            if let payload = json["payload"] as? [String: Any],
               let status = payload["status"] as? String, status == "ok" {
                isConnected = true
                NSLog("[Realtime] Channel joined OK")
            }
            return
        }

        if event == "broadcast" {
            guard let outerPayload = json["payload"] as? [String: Any],
                  let innerStr = outerPayload["payload"] as? String,
                  let innerData = innerStr.data(using: .utf8),
                  let broadcast = try? JSONDecoder().decode(ScoreBroadcast.self, from: innerData)
            else { return }

            // Ignore our own messages
            if broadcast.pilot.lowercased() == myPilotName.lowercased() { return }

            NSLog("[Realtime] Received score: pilot=%@ score=%d", broadcast.pilot, broadcast.score)
            DispatchQueue.main.async { [weak self] in
                self?.onOpponentScore?(broadcast)
            }
        }
    }
}
