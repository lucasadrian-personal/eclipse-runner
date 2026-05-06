import Foundation

// MARK: - Remote model  (matches cd_daily_burst columns exactly)
struct DailyBurstRow: Codable {
    let id: Int
    let pilotName: String
    let score: Int
    let day: String       // "yyyy-MM-dd"
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case pilotName = "pilot_name"
        case score
        case day
        case createdAt = "created_at"
    }
}

struct DailyBurstSubmitResult {
    let rank: Int?
    let isOnline: Bool
}

// MARK: - Service
final class DailyBurstService {
    static let shared = DailyBurstService()
    private init() {}

    private let table    = "cd_daily_burst"
    private let session  = URLSession.shared
    private let cacheKey = "cd.daily_burst_cache"

    // ISO date string for today (UTC)
    var todayString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt.string(from: Date())
    }

    // Seconds until UTC midnight
    var secondsUntilReset: TimeInterval {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let tomorrow = cal.startOfDay(for: Date().addingTimeInterval(86400))
        return tomorrow.timeIntervalSinceNow
    }

    // MARK: Fetch today's top-50
    func fetchToday(completion: @escaping ([DailyBurstRow]) -> Void) {
        guard let cfg = SupabaseConfig.current else {
            completion(cachedRows()); return
        }
        let today = todayString
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/\(table)")!
        comps.queryItems = [
            .init(name: "select", value: "id,pilot_name,score,day,created_at"),
            .init(name: "day",    value: "eq.\(today)"),
            .init(name: "order",  value: "score.desc,created_at.asc"),
            .init(name: "limit",  value: "50")
        ]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        addHeaders(&req, cfg: cfg)

        session.dataTask(with: req) { [weak self] data, _, error in
            guard let self else { return }
            if let error { NSLog("[DB] fetchToday error: %@", error.localizedDescription) }
            guard error == nil, let data else {
                DispatchQueue.main.async { completion(self.cachedRows()) }
                return
            }
            if let raw = String(data: data, encoding: .utf8) { NSLog("[DB] fetchToday: %@", raw) }
            let rows = (try? JSONDecoder().decode([DailyBurstRow].self, from: data)) ?? []
            if !rows.isEmpty { self.cacheRows(rows) }
            DispatchQueue.main.async { completion(rows) }
        }.resume()
    }

    // MARK: Submit — upsert by (pilot_name, day), keeps best score via DB policy
    func submit(score: Int, pilotName: String,
                completion: @escaping (DailyBurstSubmitResult) -> Void) {
        guard let cfg = SupabaseConfig.current else {
            completion(DailyBurstSubmitResult(rank: nil, isOnline: false)); return
        }
        guard let url = URL(string: "\(cfg.projectURL)/rest/v1/\(table)") else {
            completion(DailyBurstSubmitResult(rank: nil, isOnline: false)); return
        }

        let safe = String(pilotName.prefix(32)).trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: Any] = ["pilot_name": safe, "score": score, "day": todayString]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(DailyBurstSubmitResult(rank: nil, isOnline: false)); return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        addHeaders(&req, cfg: cfg)
        // Single Prefer header combining upsert + return
        req.setValue("resolution=merge-duplicates,return=representation",
                     forHTTPHeaderField: "Prefer")
        req.httpBody = bodyData

        session.dataTask(with: req) { [weak self] data, resp, error in
            guard let self else { return }
            if let error { NSLog("[DB] submit error: %@", error.localizedDescription) }
            if let data, let raw = String(data: data, encoding: .utf8) {
                NSLog("[DB] submit response: %@", raw)
            }
            guard error == nil, let data,
                  let rows = try? JSONDecoder().decode([DailyBurstRow].self, from: data),
                  let inserted = rows.first
            else {
                DispatchQueue.main.async {
                    completion(DailyBurstSubmitResult(rank: nil, isOnline: false))
                }
                return
            }
            self.fetchRank(score: inserted.score, cfg: cfg) { rank in
                DispatchQueue.main.async {
                    completion(DailyBurstSubmitResult(rank: rank, isOnline: true))
                }
            }
        }.resume()
    }

    // MARK: Rank = pilots today with higher score + 1
    private func fetchRank(score: Int, cfg: SupabaseConfig,
                           completion: @escaping (Int?) -> Void) {
        let today = todayString
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/\(table)")!
        comps.queryItems = [
            .init(name: "select", value: "id"),
            .init(name: "day",    value: "eq.\(today)"),
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

    // MARK: Cache
    private func cacheRows(_ rows: [DailyBurstRow]) {
        if let data = try? JSONEncoder().encode(rows) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
    private func cachedRows() -> [DailyBurstRow] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return [] }
        return (try? JSONDecoder().decode([DailyBurstRow].self, from: data)) ?? []
    }

    // MARK: Headers
    private func addHeaders(_ req: inout URLRequest, cfg: SupabaseConfig) {
        req.setValue("application/json",      forHTTPHeaderField: "Content-Type")
        req.setValue("application/json",      forHTTPHeaderField: "Accept")
        req.setValue(cfg.anonKey,             forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(cfg.anonKey)", forHTTPHeaderField: "Authorization")
    }
}
