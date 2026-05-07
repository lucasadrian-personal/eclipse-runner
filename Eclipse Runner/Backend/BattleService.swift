import Foundation

// MARK: - Models

struct BattleRoom: Codable {
    let id: String
    let status: String
    let seed: Int
    let createdAt: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case id, status, seed
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

struct BattleParticipant: Codable {
    let id: String
    let roomId: String
    let pilotName: String
    var score: Int?
    var finishedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case roomId    = "room_id"
        case pilotName = "pilot_name"
        case score
        case finishedAt = "finished_at"
    }
}

// MARK: - Battle Result
struct BattleResult {
    let myScore: Int
    let opponentScore: Int
    let opponentName: String
    let didWin: Bool
    let isDraw: Bool
}

// MARK: - Service

final class BattleService {
    static let shared = BattleService()
    private init() {}

    private let session = URLSession.shared

    // MARK: - Find or create a room

    /// Finds an open waiting room and joins it, or creates a new one.
    func findOrCreateRoom(pilotName: String, completion: @escaping (BattleRoom?, Error?) -> Void) {
        guard let cfg = SupabaseConfig.current else {
            completion(nil, NSError(domain: "Battle", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "No Supabase config"]))
            return
        }
        fetchWaitingRoom(cfg: cfg) { [weak self] room in
            guard let self else { return }
            if let room {
                self.joinRoom(room, pilotName: pilotName, cfg: cfg, completion: completion)
            } else {
                self.createRoom(pilotName: pilotName, cfg: cfg, completion: completion)
            }
        }
    }

    // MARK: - Poll room state

    func pollRoom(roomID: String, completion: @escaping (BattleRoom?, [BattleParticipant]) -> Void) {
        guard let cfg = SupabaseConfig.current else { completion(nil, []); return }

        let group = DispatchGroup()
        var room: BattleRoom?
        var participants: [BattleParticipant] = []

        group.enter()
        fetchRoom(roomID: roomID, cfg: cfg) { r in room = r; group.leave() }

        group.enter()
        fetchParticipants(roomID: roomID, cfg: cfg) { p in participants = p; group.leave() }

        group.notify(queue: .main) { completion(room, participants) }
    }

    // MARK: - Submit score
    func submitScore(roomID: String, pilotName: String, score: Int,
                     completion: @escaping (Bool) -> Void) {
        guard let cfg = SupabaseConfig.current else { completion(false); return }
        let safe = String(pilotName.prefix(32))

        // Update participant score + finished_at
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/battle_participants")!
        comps.queryItems = [
            .init(name: "room_id",    value: "eq.\(roomID)"),
            .init(name: "pilot_name", value: "eq.\(safe)")
        ]
        guard let url = comps.url else { completion(false); return }

        let body: [String: Any] = [
            "score": score,
            "finished_at": ISO8601DateFormatter().string(from: Date())
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(false); return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        addHeaders(&req, cfg: cfg)
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = bodyData

        session.dataTask(with: req) { _, resp, error in
            let ok = (resp as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
            DispatchQueue.main.async { completion(ok) }
        }.resume()
    }

    // MARK: - Mark room completed
    func completeRoom(roomID: String, completion: @escaping (Bool) -> Void) {
        guard let cfg = SupabaseConfig.current else { completion(false); return }

        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/battle_rooms")!
        comps.queryItems = [.init(name: "id", value: "eq.\(roomID)")]
        guard let url = comps.url else { completion(false); return }

        let body: [String: Any] = ["status": "completed"]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(false); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        addHeaders(&req, cfg: cfg)
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = bodyData

        session.dataTask(with: req) { _, resp, _ in
            let ok = (resp as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
            DispatchQueue.main.async { completion(ok) }
        }.resume()
    }

    // MARK: - Cancel room
    func cancelRoom(roomID: String, completion: ((Bool) -> Void)? = nil) {
        guard let cfg = SupabaseConfig.current else { completion?(false); return }
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/battle_rooms")!
        comps.queryItems = [.init(name: "id", value: "eq.\(roomID)")]
        guard let url = comps.url else { completion?(false); return }
        let body: [String: Any] = ["status": "cancelled"]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion?(false); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        addHeaders(&req, cfg: cfg)
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = bodyData
        session.dataTask(with: req) { _, resp, _ in
            let ok = (resp as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
            DispatchQueue.main.async { completion?(ok) }
        }.resume()
    }

    // MARK: - Private helpers

    private func fetchWaitingRoom(cfg: SupabaseConfig, completion: @escaping (BattleRoom?) -> Void) {
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/battle_rooms")!
        comps.queryItems = [
            .init(name: "select",     value: "*"),
            .init(name: "status",     value: "eq.waiting"),
            .init(name: "expires_at", value: "gt.\(ISO8601DateFormatter().string(from: Date()))"),
            .init(name: "order",      value: "created_at.asc"),
            .init(name: "limit",      value: "1")
        ]
        guard let url = comps.url else { completion(nil); return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        addHeaders(&req, cfg: cfg)
        session.dataTask(with: req) { data, _, _ in
            let rows = data.flatMap { try? JSONDecoder().decode([BattleRoom].self, from: $0) } ?? []
            DispatchQueue.main.async { completion(rows.first) }
        }.resume()
    }

    private func createRoom(pilotName: String, cfg: SupabaseConfig,
                            completion: @escaping (BattleRoom?, Error?) -> Void) {
        guard let url = URL(string: "\(cfg.projectURL)/rest/v1/battle_rooms") else {
            completion(nil, nil); return
        }
        let body: [[String: Any]] = [[:]]  // defaults: status=waiting, seed=random
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil, nil); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        addHeaders(&req, cfg: cfg)
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = bodyData

        session.dataTask(with: req) { [weak self] data, _, error in
            guard let self else { return }
            if let e = error { DispatchQueue.main.async { completion(nil, e) }; return }
            let rooms = data.flatMap { try? JSONDecoder().decode([BattleRoom].self, from: $0) } ?? []
            guard let room = rooms.first else { DispatchQueue.main.async { completion(nil, nil) }; return }
            self.addParticipant(pilotName: pilotName, room: room, cfg: cfg, completion: completion)
        }.resume()
    }

    private func joinRoom(_ room: BattleRoom, pilotName: String, cfg: SupabaseConfig,
                          completion: @escaping (BattleRoom?, Error?) -> Void) {
        // Atomically mark room as in_progress
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/battle_rooms")!
        comps.queryItems = [
            .init(name: "id",     value: "eq.\(room.id)"),
            .init(name: "status", value: "eq.waiting")   // guard: only if still waiting
        ]
        guard let url = comps.url else { completion(nil, nil); return }
        let body: [String: Any] = ["status": "in_progress"]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil, nil); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        addHeaders(&req, cfg: cfg)
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = bodyData

        session.dataTask(with: req) { [weak self] data, resp, error in
            guard let self else { return }
            if let e = error { DispatchQueue.main.async { completion(nil, e) }; return }
            let rooms = data.flatMap { try? JSONDecoder().decode([BattleRoom].self, from: $0) } ?? []
            if let updated = rooms.first {
                self.addParticipant(pilotName: pilotName, room: updated, cfg: cfg, completion: completion)
            } else {
                // Race condition: someone else grabbed the room — try again
                self.findOrCreateRoom(pilotName: pilotName, completion: completion)
            }
        }.resume()
    }

    private func addParticipant(pilotName: String, room: BattleRoom, cfg: SupabaseConfig,
                                completion: @escaping (BattleRoom?, Error?) -> Void) {
        guard let url = URL(string: "\(cfg.projectURL)/rest/v1/battle_participants") else {
            completion(room, nil); return
        }
        let safe = String(pilotName.prefix(32))
        let body: [[String: Any]] = [["room_id": room.id, "pilot_name": safe]]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(room, nil); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        addHeaders(&req, cfg: cfg)
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = bodyData

        session.dataTask(with: req) { _, _, error in
            if let e = error { NSLog("[Battle] addParticipant error: %@", e.localizedDescription) }
            DispatchQueue.main.async { completion(room, nil) }
        }.resume()
    }

    private func fetchRoom(roomID: String, cfg: SupabaseConfig,
                           completion: @escaping (BattleRoom?) -> Void) {
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/battle_rooms")!
        comps.queryItems = [
            .init(name: "select", value: "*"),
            .init(name: "id",     value: "eq.\(roomID)"),
            .init(name: "limit",  value: "1")
        ]
        guard let url = comps.url else { completion(nil); return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        addHeaders(&req, cfg: cfg)
        session.dataTask(with: req) { data, _, _ in
            let rows = data.flatMap { try? JSONDecoder().decode([BattleRoom].self, from: $0) } ?? []
            DispatchQueue.main.async { completion(rows.first) }
        }.resume()
    }

    private func fetchParticipants(roomID: String, cfg: SupabaseConfig,
                                   completion: @escaping ([BattleParticipant]) -> Void) {
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/battle_participants")!
        comps.queryItems = [
            .init(name: "select",  value: "*"),
            .init(name: "room_id", value: "eq.\(roomID)")
        ]
        guard let url = comps.url else { completion([]); return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        addHeaders(&req, cfg: cfg)
        session.dataTask(with: req) { data, _, _ in
            let rows = data.flatMap { try? JSONDecoder().decode([BattleParticipant].self, from: $0) } ?? []
            DispatchQueue.main.async { completion(rows) }
        }.resume()
    }

    private func addHeaders(_ req: inout URLRequest, cfg: SupabaseConfig) {
        req.setValue("application/json",      forHTTPHeaderField: "Content-Type")
        req.setValue("application/json",      forHTTPHeaderField: "Accept")
        req.setValue(cfg.anonKey,             forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(cfg.anonKey)", forHTTPHeaderField: "Authorization")
    }
}
