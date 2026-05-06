import Foundation
import SwiftUI

// MARK: - GameStore
@MainActor
final class GameStore: ObservableObject {
    @Published var bestScore: Int
    @Published var totalRuns: Int
    @Published var totalDistance: Int
    @Published var pilotName: String

    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var leaderboardLoading: Bool = false
    @Published var isOnline: Bool = false

    // Last submitted run's result
    @Published var lastRunRank: Int? = nil
    @Published var lastRunIsOnline: Bool = false

    // MARK: Daily Burst
    @Published var dailyBestScore: Int = 0          // best score today
    @Published var dailyCompleted: Bool = false      // finished at least one burst today
    @Published var dailyRank: Int? = nil             // rank after last submission
    @Published var dailyLeaderboard: [LeaderboardEntry] = []
    @Published var dailyLeaderboardLoading: Bool = false
    @Published var lastDailyRank: Int? = nil

    private let defaults = UserDefaults.standard

    init() {
        self.bestScore     = defaults.integer(forKey: Keys.best)
        self.totalRuns     = defaults.integer(forKey: Keys.runs)
        self.totalDistance = defaults.integer(forKey: Keys.distance)
        self.pilotName     = defaults.string(forKey: Keys.pilot) ?? "Pilot Nova"

        // Restore daily state for today
        let today = DailyBurstService.shared.todayString
        if defaults.string(forKey: Keys.dailyDate) == today {
            dailyBestScore = defaults.integer(forKey: Keys.dailyBest)
            dailyCompleted = defaults.bool(forKey: Keys.dailyDone)
        }

        leaderboard = LeaderboardEntry.sample
        refreshLeaderboard()
        refreshDailyLeaderboard()
    }

    // MARK: - Pilot name
    func savePilotName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pilotName = trimmed
        defaults.set(trimmed, forKey: Keys.pilot)
    }

    // MARK: - Register run + submit to leaderboard
    func registerRun(score: Int) {
        totalRuns     += 1
        totalDistance += max(1, score / 4)
        if score > bestScore { bestScore = score }
        defaults.set(bestScore,     forKey: Keys.best)
        defaults.set(totalRuns,     forKey: Keys.runs)
        defaults.set(totalDistance, forKey: Keys.distance)

        lastRunRank = nil
        lastRunIsOnline = false

        let name = pilotName
        LeaderboardService.shared.submit(score: score, pilotName: name) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.lastRunRank     = result.globalRank
                self.lastRunIsOnline = result.isOnline
                if result.isOnline { self.refreshLeaderboard() }
            }
        }
    }

    // MARK: - Register Daily Burst run
    func registerDailyRun(score: Int) {
        totalRuns     += 1
        totalDistance += max(1, score / 4)
        if score > bestScore { bestScore = score }
        defaults.set(bestScore,     forKey: Keys.best)
        defaults.set(totalRuns,     forKey: Keys.runs)
        defaults.set(totalDistance, forKey: Keys.distance)

        // Track daily best locally
        let today = DailyBurstService.shared.todayString
        if score > dailyBestScore { dailyBestScore = score }
        dailyCompleted = true
        defaults.set(today,          forKey: Keys.dailyDate)
        defaults.set(dailyBestScore, forKey: Keys.dailyBest)
        defaults.set(true,           forKey: Keys.dailyDone)

        lastDailyRank = nil

        let name = pilotName
        // Also submit to global leaderboard
        LeaderboardService.shared.submit(score: score, pilotName: name) { _ in }

        DailyBurstService.shared.submit(score: score, pilotName: name) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.lastDailyRank = result.rank
                if result.isOnline { self.refreshDailyLeaderboard() }
            }
        }
    }

    // MARK: - Fetch leaderboard
    func refreshLeaderboard() {
        leaderboardLoading = true
        LeaderboardService.shared.fetchTop { [weak self] rows in
            guard let self else { return }
            self.leaderboardLoading = false
            self.isOnline = SupabaseConfig.current != nil
            guard !rows.isEmpty else { return }
            let myName = self.pilotName
            self.leaderboard = rows.enumerated().map { idx, row in
                LeaderboardEntry(rank: idx + 1, name: row.pilotName,
                                 score: row.score,
                                 isYou: row.pilotName.lowercased() == myName.lowercased())
            }
        }
    }

    // MARK: - Fetch daily leaderboard
    func refreshDailyLeaderboard() {
        dailyLeaderboardLoading = true
        DailyBurstService.shared.fetchToday { [weak self] rows in
            guard let self else { return }
            self.dailyLeaderboardLoading = false
            guard !rows.isEmpty else { return }
            let myName = self.pilotName
            self.dailyLeaderboard = rows.enumerated().map { idx, row in
                LeaderboardEntry(rank: idx + 1, name: row.pilotName,
                                 score: row.score,
                                 isYou: row.pilotName.lowercased() == myName.lowercased())
            }
        }
    }

    private enum Keys {
        static let best       = "cd.bestScore"
        static let runs       = "cd.totalRuns"
        static let distance   = "cd.totalDistance"
        static let pilot      = "cd.pilotName"
        static let dailyDate  = "cd.dailyDate"
        static let dailyBest  = "cd.dailyBest"
        static let dailyDone  = "cd.dailyDone"
    }
}

// MARK: - LeaderboardEntry (UI model)
struct LeaderboardEntry: Identifiable, Hashable {
    let id   = UUID()
    let rank:  Int
    let name:  String
    let score: Int
    let isYou: Bool

    static let sample: [LeaderboardEntry] = [
        .init(rank: 1, name: "Stardancer",  score: 612, isYou: false),
        .init(rank: 2, name: "Lyra-7",      score: 488, isYou: false),
        .init(rank: 3, name: "Orion Vex",   score: 341, isYou: false),
        .init(rank: 4, name: "Pilot Nova",  score: 142, isYou: true),
        .init(rank: 5, name: "Ghost Comet", score: 96,  isYou: false)
    ]
}

// MARK: - RunRecord
struct RunRecord: Identifiable, Hashable {
    let id    = UUID()
    let score: Int
    let dateLabel: String

    static let sample: [RunRecord] = [
        .init(score: 142, dateLabel: "Today"),
        .init(score: 118, dateLabel: "Today"),
        .init(score: 96,  dateLabel: "Yesterday"),
        .init(score: 74,  dateLabel: "Yesterday"),
        .init(score: 51,  dateLabel: "Mon")
    ]
}
