import Foundation

// MARK: - Models

struct BattleRoom: Codable {
    let id: String
    let status: String
    let seed: Int
    let createdAt: String
    let expiresAt: String
    let hostName: String?
    let invitedPilot: String?
    let roomCode: String?

    enum CodingKeys: String, CodingKey {
        case id, status, seed
        case createdAt    = "created_at"
        case expiresAt    = "expires_at"
        case hostName     = "host_name"
        case invitedPilot = "invited_pilot"
        case roomCode     = "room_code"
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

struct BattleResult {
    let myScore: Int
    let opponentScore: Int
    let opponentName: String
    let didWin: Bool
    let isDraw: Bool
}

struct RivalryRow: Codable {
    let pilotA: String
    let pilotB: String
    let winsA: Int
    let winsB: Int
    let draws: Int
    enum CodingKeys: String, CodingKey {
        case pilotA = "pilot_a"; case pilotB = "pilot_b"
        case winsA  = "wins_a";  case winsB  = "wins_b"; case draws
    }
}

struct RivalryStats: Equatable {
    let myWins: Int
    let theirWins: Int
    let draws: Int
    var total: Int { myWins + theirWins + draws }
}

// MARK: - Service

final class BattleService {
    static let shared = BattleService()
    private init() {}

    private let session = URLSession.shared

    // MARK: - Random matchmaking (find waiting room or create new)

    func findOrCreateRoom(pilotName: String, completion: @escaping (BattleRoom?, Error?) -> Void) {
        guard let cfg = SupabaseConfig.current else {
            completion(nil, NSError(domain: "Battle", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "No Supabase config"]))
            return
        }
        // Only join rooms that have no invitation (public rooms)
        fetchWaitingRoom(cfg: cfg, publicOnly: true) { [weak self] room in
            guard let self else { return }
            if let room {
                self.joinRoom(room, pilotName: pilotName, cfg: cfg, completion: completion)
            } else {
                self.createRoom(pilotName: pilotName, invitedPilot: nil, cfg: cfg, completion: completion)
            }
        }
    }

    // MARK: - Private room: create with 6-char code

    func createPrivateRoom(pilotName: String, completion: @escaping (BattleRoom?, Error?) -> Void) {
        guard let cfg = SupabaseConfig.current else {
            NSLog("[Battle] createPrivateRoom: no Supabase config")
            completion(nil, NSError(domain: "Battle", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "No Supabase config"]))
            return
        }
        NSLog("[Battle] createPrivateRoom: starting for %@", pilotName)
        createRoom(pilotName: pilotName, invitedPilot: nil, isPrivate: true, cfg: cfg, completion: completion)
    }

    // MARK: - Join by code

    func joinByCode(_ code: String, pilotName: String,
                    completion: @escaping (BattleRoom?, Error?) -> Void) {
        guard let cfg = SupabaseConfig.current else {
            NSLog("[Battle] joinByCode: no Supabase config")
            completion(nil, NSError(domain: "Battle", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "No Supabase config"]))
            return
        }
        let clean = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        NSLog("[Battle] joinByCode: looking for code=%@, pilot=%@", clean, pilotName)
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/battle_rooms")!
        comps.queryItems = [
            .init(name: "select",     value: "*"),
            .init(name: "room_code",  value: "eq.\(clean)"),
            .init(name: "status",     value: "eq.waiting"),
            .init(name: "expires_at", value: "gt.\(ISO8601DateFormatter().string(from: Date()))"),
            .init(name: "limit",      value: "1")
        ]
        guard let url = comps.url else { completion(nil, nil); return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        addHeaders(&req, cfg: cfg)
        session.dataTask(with: req) { [weak self] data, resp, error in
            guard let self else { return }
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            NSLog("[Battle] joinByCode: HTTP %d", status)
            if let data { NSLog("[Battle] joinByCode: response=%@", String(data: data, encoding: .utf8) ?? "?") }
            if let e = error { DispatchQueue.main.async { completion(nil, e) }; return }
            let rooms = data.flatMap { try? JSONDecoder().decode([BattleRoom].self, from: $0) } ?? []
            NSLog("[Battle] joinByCode: found %d rooms", rooms.count)
            guard let room = rooms.first else {
                let err = NSError(domain: "Battle", code: 404,
                                  userInfo: [NSLocalizedDescriptionKey: "Code not found or expired"])
                DispatchQueue.main.async { completion(nil, err) }
                return
            }
            self.joinRoom(room, pilotName: pilotName, cfg: cfg, completion: completion)
        }.resume()
    }

    // MARK: - Challenge same opponent (find their waiting room or create invite)

    func challengeSameOpponent(myName: String, opponentName: String,
                                completion: @escaping (BattleRoom?, Error?) -> Void) {
        guard let cfg = SupabaseConfig.current else {
            completion(nil, NSError(domain: "Battle", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "No Supabase config"]))
            return
        }
        // Look for a room hosted by opponent waiting for me
        fetchInviteRoom(for: myName, from: opponentName, cfg: cfg) { [weak self] room in
            guard let self else { return }
            if let room {
                self.joinRoom(room, pilotName: myName, cfg: cfg, completion: completion)
            } else {
                // Create a room with invitation so opponent can find it
                self.createRoom(pilotName: myName, invitedPilot: opponentName, cfg: cfg, completion: completion)
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

    // MARK: - Check for incoming challenges (opponent created a room inviting me)

    func checkIncomingChallenge(for pilotName: String,
                                 completion: @escaping (BattleRoom?) -> Void) {
        guard let cfg = SupabaseConfig.current else { completion(nil); return }
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/battle_rooms")!
        comps.queryItems = [
            .init(name: "select",         value: "*"),
            .init(name: "invited_pilot",  value: "ilike.\(pilotName)"),
            .init(name: "status",         value: "eq.waiting"),
            .init(name: "expires_at",     value: "gt.\(ISO8601DateFormatter().string(from: Date()))"),
            .init(name: "order",          value: "created_at.desc"),
            .init(name: "limit",          value: "1")
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

    // MARK: - Submit score

    func submitScore(roomID: String, pilotName: String, score: Int,
                     completion: @escaping (Bool) -> Void) {
        guard let cfg = SupabaseConfig.current else { completion(false); return }
        let safe = String(pilotName.prefix(32))
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
        session.dataTask(with: req) { _, resp, _ in
            let ok = (resp as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
            DispatchQueue.main.async { completion(ok) }
        }.resume()
    }

    // MARK: - Complete / cancel room

    func completeRoom(roomID: String, completion: @escaping (Bool) -> Void) {
        updateRoomStatus(roomID: roomID, status: "completed", completion: completion)
    }

    func cancelRoom(roomID: String, completion: ((Bool) -> Void)? = nil) {
        updateRoomStatus(roomID: roomID, status: "cancelled") { ok in completion?(ok) }
    }

    // MARK: - Rivalry

    func recordRivalry(me: String, opponent: String, didWin: Bool?, isDraw: Bool,
                       completion: @escaping (Bool) -> Void) {
        guard let cfg = SupabaseConfig.current else { completion(false); return }
        let a = me.lowercased() < opponent.lowercased() ? me.lowercased() : opponent.lowercased()
        let b = me.lowercased() < opponent.lowercased() ? opponent.lowercased() : me.lowercased()
        let iAmA = me.lowercased() == a

        var winsA = 0, winsB = 0, draws = 0
        if isDraw { draws = 1 }
        else if let won = didWin {
            if won { if iAmA { winsA = 1 } else { winsB = 1 } }
            else   { if iAmA { winsB = 1 } else { winsA = 1 } }
        }

        guard let url = URL(string: "\(cfg.projectURL)/rest/v1/rpc/upsert_rivalry") else {
            completion(false); return
        }
        let body: [String: Any] = [
            "p_pilot_a": a, "p_pilot_b": b,
            "p_wins_a": winsA, "p_wins_b": winsB, "p_draws": draws
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(false); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        addHeaders(&req, cfg: cfg)
        req.httpBody = bodyData
        session.dataTask(with: req) { _, resp, _ in
            let ok = (resp as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
            DispatchQueue.main.async { completion(ok) }
        }.resume()
    }

    func fetchRivalry(me: String, opponent: String,
                      completion: @escaping (RivalryStats?) -> Void) {
        guard let cfg = SupabaseConfig.current else { completion(nil); return }
        let a = me.lowercased() < opponent.lowercased() ? me.lowercased() : opponent.lowercased()
        let b = me.lowercased() < opponent.lowercased() ? opponent.lowercased() : me.lowercased()
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/battle_rivalries")!
        comps.queryItems = [
            .init(name: "select",  value: "*"),
            .init(name: "pilot_a", value: "eq.\(a)"),
            .init(name: "pilot_b", value: "eq.\(b)"),
            .init(name: "limit",   value: "1")
        ]
        guard let url = comps.url else { completion(nil); return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        addHeaders(&req, cfg: cfg)
        session.dataTask(with: req) { data, _, _ in
            guard let data,
                  let rows = try? JSONDecoder().decode([RivalryRow].self, from: data),
                  let row = rows.first
            else { DispatchQueue.main.async { completion(nil) }; return }
            let iAmA = me.lowercased() == a
            let stats = RivalryStats(myWins: iAmA ? row.winsA : row.winsB,
                                     theirWins: iAmA ? row.winsB : row.winsA,
                                     draws: row.draws)
            DispatchQueue.main.async { completion(stats) }
        }.resume()
    }

    // MARK: - Private helpers

    private func fetchWaitingRoom(cfg: SupabaseConfig, publicOnly: Bool,
                                   completion: @escaping (BattleRoom?) -> Void) {
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/battle_rooms")!
        var items: [URLQueryItem] = [
            .init(name: "select",     value: "*"),
            .init(name: "status",     value: "eq.waiting"),
            .init(name: "expires_at", value: "gt.\(ISO8601DateFormatter().string(from: Date()))"),
            .init(name: "order",      value: "created_at.asc"),
            .init(name: "limit",      value: "1")
        ]
        if publicOnly { items.append(.init(name: "invited_pilot", value: "is.null")) }
        comps.queryItems = items
        guard let url = comps.url else { completion(nil); return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        addHeaders(&req, cfg: cfg)
        session.dataTask(with: req) { data, _, _ in
            let rows = data.flatMap { try? JSONDecoder().decode([BattleRoom].self, from: $0) } ?? []
            DispatchQueue.main.async { completion(rows.first) }
        }.resume()
    }

    private func fetchInviteRoom(for invitedPilot: String, from host: String,
                                  cfg: SupabaseConfig, completion: @escaping (BattleRoom?) -> Void) {
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/battle_rooms")!
        comps.queryItems = [
            .init(name: "select",        value: "*"),
            .init(name: "host_name",     value: "ilike.\(host)"),
            .init(name: "invited_pilot", value: "ilike.\(invitedPilot)"),
            .init(name: "status",        value: "eq.waiting"),
            .init(name: "expires_at",    value: "gt.\(ISO8601DateFormatter().string(from: Date()))"),
            .init(name: "limit",         value: "1")
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

    private func createRoom(pilotName: String, invitedPilot: String?,
                             isPrivate: Bool = false,
                             cfg: SupabaseConfig,
                             completion: @escaping (BattleRoom?, Error?) -> Void) {
        guard let url = URL(string: "\(cfg.projectURL)/rest/v1/battle_rooms") else {
            NSLog("[Battle] createRoom: bad URL")
            completion(nil, nil); return
        }
        var bodyDict: [String: Any] = ["host_name": pilotName]
        if let inv = invitedPilot { bodyDict["invited_pilot"] = inv }
        if isPrivate || invitedPilot != nil {
            bodyDict["room_code"] = Self.generateCode()
        }
        guard let bodyData = try? JSONSerialization.data(withJSONObject: [bodyDict]) else {
            NSLog("[Battle] createRoom: JSON serialize failed")
            completion(nil, nil); return
        }
        NSLog("[Battle] createRoom: POST to %@ body=%@", url.absoluteString, String(data: bodyData, encoding: .utf8) ?? "?")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        addHeaders(&req, cfg: cfg)
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = bodyData
        session.dataTask(with: req) { [weak self] data, resp, error in
            guard let self else { return }
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            NSLog("[Battle] createRoom: HTTP %d", status)
            if let data { NSLog("[Battle] createRoom: response=%@", String(data: data, encoding: .utf8) ?? "?") }
            if let e = error {
                NSLog("[Battle] createRoom: error=%@", e.localizedDescription)
                DispatchQueue.main.async { completion(nil, e) }; return
            }
            let rooms = data.flatMap { try? JSONDecoder().decode([BattleRoom].self, from: $0) } ?? []
            NSLog("[Battle] createRoom: decoded %d rooms", rooms.count)
            guard let room = rooms.first else {
                let err = NSError(domain: "Battle", code: status,
                                  userInfo: [NSLocalizedDescriptionKey: "Room creation failed (HTTP \(status))"])
                DispatchQueue.main.async { completion(nil, err) }; return
            }
            self.addParticipant(pilotName: pilotName, room: room, cfg: cfg, completion: completion)
        }.resume()
    }

    private func joinRoom(_ room: BattleRoom, pilotName: String, cfg: SupabaseConfig,
                          completion: @escaping (BattleRoom?, Error?) -> Void) {
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/battle_rooms")!
        comps.queryItems = [
            .init(name: "id",     value: "eq.\(room.id)"),
            .init(name: "status", value: "eq.waiting")
        ]
        guard let url = comps.url else { completion(nil, nil); return }
        let body: [String: Any] = ["status": "in_progress"]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil, nil); return
        }
        NSLog("[Battle] joinRoom: id=%@ pilot=%@", room.id, pilotName)
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        addHeaders(&req, cfg: cfg)
        // Use return=minimal — we re-fetch the room separately to avoid 204-vs-200 parsing ambiguity
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = bodyData
        session.dataTask(with: req) { [weak self] data, resp, error in
            guard let self else { return }
            let httpStatus = (resp as? HTTPURLResponse)?.statusCode ?? -1
            NSLog("[Battle] joinRoom PATCH: HTTP %d", httpStatus)
            if let e = error { DispatchQueue.main.async { completion(nil, e) }; return }
            guard (200..<300).contains(httpStatus) else {
                // PATCH failed (room already taken, gone, or RLS denied)
                let err = NSError(domain: "Battle", code: httpStatus,
                                  userInfo: [NSLocalizedDescriptionKey: "Room is no longer available"])
                DispatchQueue.main.async { completion(nil, err) }
                return
            }
            // PATCH succeeded (200 or 204) — re-fetch to get current room state
            self.fetchRoom(roomID: room.id, cfg: cfg) { [weak self] updated in
                guard let self else { return }
                guard let updated else {
                    let err = NSError(domain: "Battle", code: 404,
                                      userInfo: [NSLocalizedDescriptionKey: "Room not found after join"])
                    DispatchQueue.main.async { completion(nil, err) }
                    return
                }
                NSLog("[Battle] joinRoom re-fetch: status=%@", updated.status)
                self.addParticipant(pilotName: pilotName, room: updated, cfg: cfg, completion: completion)
            }
        }.resume()
    }

    private func addParticipant(pilotName: String, room: BattleRoom, cfg: SupabaseConfig,
                                completion: @escaping (BattleRoom?, Error?) -> Void) {
        guard let url = URL(string: "\(cfg.projectURL)/rest/v1/battle_participants") else {
            NSLog("[Battle] addParticipant: bad URL, returning room anyway")
            DispatchQueue.main.async { completion(room, nil) }; return
        }
        let safe = String(pilotName.prefix(32))
        let body: [[String: Any]] = [["room_id": room.id, "pilot_name": safe]]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            DispatchQueue.main.async { completion(room, nil) }; return
        }
        NSLog("[Battle] addParticipant: pilot=%@ room=%@", safe, room.id)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        addHeaders(&req, cfg: cfg)
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = bodyData
        session.dataTask(with: req) { data, resp, error in
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            NSLog("[Battle] addParticipant: HTTP %d", status)
            if let data { NSLog("[Battle] addParticipant: response=%@", String(data: data, encoding: .utf8) ?? "?") }
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

    private func updateRoomStatus(roomID: String, status: String, completion: @escaping (Bool) -> Void) {
        guard let cfg = SupabaseConfig.current else { completion(false); return }
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/battle_rooms")!
        comps.queryItems = [.init(name: "id", value: "eq.\(roomID)")]
        guard let url = comps.url else { completion(false); return }
        let body: [String: Any] = ["status": status]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { completion(false); return }
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

    private func addHeaders(_ req: inout URLRequest, cfg: SupabaseConfig) {
        req.setValue("application/json",      forHTTPHeaderField: "Content-Type")
        req.setValue("application/json",      forHTTPHeaderField: "Accept")
        req.setValue(cfg.anonKey,             forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(cfg.anonKey)", forHTTPHeaderField: "Authorization")
    }

    static func generateCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
