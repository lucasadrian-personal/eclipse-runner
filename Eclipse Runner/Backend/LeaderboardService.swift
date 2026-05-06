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

// MARK: - Service
final class LeaderboardService {
    static let shared = LeaderboardService()
    private init() {}

    private let cachedKey = "cd.cached_leaderboard"
    private let session   = URLSession.shared

    // MARK: - Fetch top-100
    func fetchTop(completion: @escaping ([CDLeaderboardRow]) -> Void) {
        guard let cfg = SupabaseConfig.current else {
            completion(cachedRows())
            return
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

        session.dataTask(with: req) { [weak self] data, resp, error in
            guard let self else { return }
            if let error { NSLog("[LB] fetchTop error: %@", error.localizedDescription) }
            guard error == nil, let data else {
                DispatchQueue.main.async { completion(self.cachedRows()) }
                return
            }
            if let raw = String(data: data, encoding: .utf8) { NSLog("[LB] fetchTop response: %@", raw) }
            let rows = (try? JSONDecoder().decode([CDLeaderboardRow].self, from: data)) ?? []
            if !rows.isEmpty { self.cacheRows(rows) }
            DispatchQueue.main.async { completion(rows) }
        }.resume()
    }

    // MARK: - Submit score
    func submit(score: Int, pilotName: String,
                completion: @escaping (SubmitResult) -> Void) {
        guard let cfg = SupabaseConfig.current else {
            completion(SubmitResult(globalRank: nil, isOnline: false))
            return
        }
        guard let url = URL(string: "\(cfg.projectURL)/rest/v1/\(cfg.table)") else {
            completion(SubmitResult(globalRank: nil, isOnline: false))
            return
        }

        let safe = String(pilotName.prefix(32)).trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [[String: Any]] = [["pilot_name": safe, "score": score]]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(SubmitResult(globalRank: nil, isOnline: false))
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        addHeaders(&req, cfg: cfg)
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = bodyData

        session.dataTask(with: req) { [weak self] data, resp, error in
            guard let self else { return }
            if let error { NSLog("[LB] submit error: %@", error.localizedDescription) }
            if let data, let raw = String(data: data, encoding: .utf8) {
                NSLog("[LB] submit response: %@", raw)
            }
            guard error == nil, let data,
                  let inserted = try? JSONDecoder().decode([CDLeaderboardRow].self, from: data).first
            else {
                DispatchQueue.main.async { completion(SubmitResult(globalRank: nil, isOnline: false)) }
                return
            }
            self.fetchRank(for: inserted, cfg: cfg) { rank in
                DispatchQueue.main.async {
                    completion(SubmitResult(globalRank: rank, isOnline: true))
                }
            }
        }.resume()
    }

    // MARK: - Rank: count rows with higher score + 1
    private func fetchRank(for row: CDLeaderboardRow, cfg: SupabaseConfig,
                           completion: @escaping (Int?) -> Void) {
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/\(cfg.table)")!
        comps.queryItems = [
            .init(name: "select", value: "id"),
            .init(name: "score",  value: "gt.\(row.score)")
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
