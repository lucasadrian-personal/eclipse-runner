import Foundation

// MARK: - Remote model
struct DailyBurstRow: Codable {
    let id: String
    let pilotName: String
    let score: Int
    let burstDate: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case pilotName = "pilot_name"
        case score
        case burstDate = "burst_date"
        case updatedAt = "updated_at"
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

    private let table   = "cd_daily_burst"
    private let session = URLSession.shared
    private let cacheKey = "cd.daily_burst_cache"

    // ISO date string for today
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
            completion(cachedRows())
            return
        }
        let today = todayString
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/\(table)")!
        comps.queryItems = [
            .init(name: "select",     value: "id,pilot_name,score,burst_date,updated_at"),
            .init(name: "burst_date", value: "eq.\(today)"),
            .init(name: "order",      value: "score.desc,updated_at.asc"),
            .init(name: "limit",      value: "50")
        ]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        addHeaders(&req, cfg: cfg)

        session.dataTask(with: req) { [weak self] data, _, error in
            guard let self, error == nil, let data else {
                completion(self?.cachedRows() ?? [])
                return
            }
            let rows = (try? JSONDecoder().decode([DailyBurstRow].self, from: data)) ?? []
            if !rows.isEmpty { self.cacheRows(rows) }
            DispatchQueue.main.async { completion(rows) }
        }.resume()
    }

    // MARK: Submit (upsert — only keeps best score for pilot today)
    func submit(score: Int, pilotName: String,
                completion: @escaping (DailyBurstSubmitResult) -> Void) {
        guard let cfg = SupabaseConfig.current else {
            completion(DailyBurstSubmitResult(rank: nil, isOnline: false))
            return
        }
        guard let url = URL(string: "\(cfg.projectURL)/rest/v1/\(table)") else {
            completion(DailyBurstSubmitResult(rank: nil, isOnline: false))
            return
        }
        let safe = String(pilotName.prefix(32)).trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: Any] = [
            "pilot_name": safe,
            "score": score,
            "burst_date": todayString
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(DailyBurstSubmitResult(rank: nil, isOnline: false))
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        addHeaders(&req, cfg: cfg)
        // Upsert: if (pilot_name, burst_date) exists, update score only if new score is higher
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = bodyData

        session.dataTask(with: req) { [weak self] data, resp, error in
            guard let self, error == nil, let data,
                  let rows = try? JSONDecoder().decode([DailyBurstRow].self, from: data),
                  let inserted = rows.first
            else {
                DispatchQueue.main.async {
                    completion(DailyBurstSubmitResult(rank: nil, isOnline: false))
                }
                return
            }
            self.fetchRank(for: inserted, cfg: cfg) { rank in
                DispatchQueue.main.async {
                    completion(DailyBurstSubmitResult(rank: rank, isOnline: true))
                }
            }
        }.resume()
    }

    // MARK: Rank = count rows today with higher score + 1
    private func fetchRank(for row: DailyBurstRow, cfg: SupabaseConfig,
                           completion: @escaping (Int?) -> Void) {
        let today = todayString
        var comps = URLComponents(string: "\(cfg.projectURL)/rest/v1/\(table)")!
        comps.queryItems = [
            .init(name: "select",     value: "id"),
            .init(name: "burst_date", value: "eq.\(today)"),
            .init(name: "score",      value: "gt.\(row.score)")
        ]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "HEAD"
        addHeaders(&req, cfg: cfg)
        req.setValue("count=exact", forHTTPHeaderField: "Prefer")
        req.setValue("0-0", forHTTPHeaderField: "Range")

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
