import Foundation

// MARK: - Remote model
struct CDLeaderboardRow: Codable {
    let id: Int
    let pilotName: String
    let score: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case pilotName = "pilot_name"
        case score
        case createdAt = "created_at"
    }
}

// MARK: - Submit result
struct SubmitResult {
    let globalRank: Int?
    let isOnline: Bool
}

// MARK: - Name check result
enum PilotNameStatus {
    case available
    case taken
    case offline   // could not reach DB — allow locally
}

// MARK: - Service
final class LeaderboardService {
    static let shared = LeaderboardService()
    private init() {}

    private let cachedKey = "cd.cached_leaderboard"
    private let session   = URLSession.shared

    // MARK: - Fetch top-100
    func fetchTop(completion: @escaping ([CDLeaderboardRow]) -> Void) {
        guard let cfg = SupabaseConfig.current else {
            completion(cachedRows()); return
        }
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/\(cfg.table)")!
        comps.queryItems = [
            .init(name: "select", value: "id,pilot_name,score,created_at"),
            .init(name: "order",  value: "score.desc,created_at.asc"),
            .init(name: "limit",  value: "100")
        ]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        addHeaders(&req, cfg: cfg)

        session.dataTask(with: req) { [weak self] data, _, error in
            guard let self else { return }
            if let e = error { NSLog("[LB] fetchTop error: %@", e.localizedDescription) }
            guard error == nil, let data else {
                DispatchQueue.main.async { completion(self.cachedRows()) }; return
            }
            let rows = (try? JSONDecoder().decode([CDLeaderboardRow].self, from: data)) ?? []
            if !rows.isEmpty { self.cacheRows(rows) }
            DispatchQueue.main.async { completion(rows) }
        }.resume()
    }

    // MARK: - Submit score (upsert — only updates if new score is better)
    func submit(score: Int, pilotName: String,
                completion: @escaping (SubmitResult) -> Void) {
        guard let cfg = SupabaseConfig.current else {
            completion(SubmitResult(globalRank: nil, isOnline: false)); return
        }
        guard let url = URL(string: "\(cfg.projectURL)/rest/v1/\(cfg.table)") else {
            completion(SubmitResult(globalRank: nil, isOnline: false)); return
        }
        let safe = String(pilotName.prefix(32)).trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [[String: Any]] = [["pilot_name": safe, "score": score]]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(SubmitResult(globalRank: nil, isOnline: false)); return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        addHeaders(&req, cfg: cfg)
        // PostgREST requires separate Prefer directives
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.addValue("return=representation",       forHTTPHeaderField: "Prefer")
        // Tell PostgREST which columns form the conflict key
        req.setValue("lower(pilot_name)", forHTTPHeaderField: "On-Conflict")
        req.httpBody = bodyData

        session.dataTask(with: req) { [weak self] data, resp, error in
            guard let self else { return }
            if let e = error { NSLog("[LB] submit error: %@", e.localizedDescription) }
            if let data, let raw = String(data: data, encoding: .utf8) {
                NSLog("[LB] submit response: %@", raw)
            }
            guard error == nil else {
                DispatchQueue.main.async { completion(SubmitResult(globalRank: nil, isOnline: false)) }
                return
            }
            // If upsert returned empty (score was not better), still fetch rank
            let rows = data.flatMap { try? JSONDecoder().decode([CDLeaderboardRow].self, from: $0) } ?? []
            if let inserted = rows.first {
                self.fetchRank(for: inserted, cfg: cfg) { rank in
                    DispatchQueue.main.async { completion(SubmitResult(globalRank: rank, isOnline: true)) }
                }
            } else {
                // Score not updated (existing is better) — fetch rank for submitted score anyway
                self.fetchRankByScore(score: score, cfg: cfg) { rank in
                    DispatchQueue.main.async { completion(SubmitResult(globalRank: rank, isOnline: true)) }
                }
            }
        }.resume()
    }

    // MARK: - Check if pilot name is already taken
    func checkPilotName(_ name: String, completion: @escaping (PilotNameStatus) -> Void) {
        guard let cfg = SupabaseConfig.current else {
            completion(.offline); return
        }
        let safe = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/\(cfg.table)")!
        comps.queryItems = [
            .init(name: "select",     value: "id"),
            .init(name: "pilot_name", value: "ilike.\(safe)"),
            .init(name: "limit",      value: "1")
        ]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        addHeaders(&req, cfg: cfg)

        session.dataTask(with: req) { data, _, error in
            guard error == nil, let data,
                  let rows = try? JSONDecoder().decode([[String: Int]].self, from: data)
            else { DispatchQueue.main.async { completion(.offline) }; return }
            DispatchQueue.main.async { completion(rows.isEmpty ? .available : .taken) }
        }.resume()
    }

    // MARK: - Rank by row
    private func fetchRank(for row: CDLeaderboardRow, cfg: SupabaseConfig,
                           completion: @escaping (Int?) -> Void) {
        fetchRankByScore(score: row.score, cfg: cfg, completion: completion)
    }

    // MARK: - Rank by raw score
    private func fetchRankByScore(score: Int, cfg: SupabaseConfig,
                                  completion: @escaping (Int?) -> Void) {
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/\(cfg.table)")!
        comps.queryItems = [
            .init(name: "select", value: "id"),
            .init(name: "score",  value: "gt.\(score)")
        ]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        addHeaders(&req, cfg: cfg)
        req.setValue("count=exact", forHTTPHeaderField: "Prefer")

        session.dataTask(with: req) { _, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  let range = http.value(forHTTPHeaderField: "Content-Range"),
                  let total = range.split(separator: "/").last.flatMap({ Int($0) })
            else { completion(nil); return }
            completion(total + 1)
        }.resume()
    }

    // MARK: - Cache
    private func cacheRows(_ rows: [CDLeaderboardRow]) {
        if let data = try? JSONEncoder().encode(rows) {
            UserDefaults.standard.set(data, forKey: cachedKey)
        }
    }
    private func cachedRows() -> [CDLeaderboardRow] {
        guard let data = UserDefaults.standard.data(forKey: cachedKey) else { return [] }
        return (try? JSONDecoder().decode([CDLeaderboardRow].self, from: data)) ?? []
    }

    // MARK: - Headers
    private func addHeaders(_ req: inout URLRequest, cfg: SupabaseConfig) {
        req.setValue("application/json",      forHTTPHeaderField: "Content-Type")
        req.setValue("application/json",      forHTTPHeaderField: "Accept")
        req.setValue(cfg.anonKey,             forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(cfg.anonKey)", forHTTPHeaderField: "Authorization")
    }
}
