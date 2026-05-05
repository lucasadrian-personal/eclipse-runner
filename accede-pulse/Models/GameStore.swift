import Foundation
import SwiftUI

/// Lightweight local store. UI prototype — persists to UserDefaults.
@MainActor
final class GameStore: ObservableObject {
    @Published var bestScore: Int
    @Published var totalRuns: Int
    @Published var totalDistance: Int    // light-years (sample)
    @Published var pilotName: String

    @Published var leaderboard: [LeaderboardEntry]
    @Published var recentRuns: [RunRecord]

    private let defaults = UserDefaults.standard

    init() {
        self.bestScore = defaults.integer(forKey: Keys.best)
        self.totalRuns = defaults.integer(forKey: Keys.runs)
        self.totalDistance = defaults.integer(forKey: Keys.distance)
        self.pilotName = defaults.string(forKey: Keys.pilot) ?? "Pilot Nova"

        // Sample data so UI feels alive on first launch
        self.leaderboard = LeaderboardEntry.sample
        self.recentRuns = RunRecord.sample

        if self.bestScore == 0 { self.bestScore = 142 }
        if self.totalRuns == 0 { self.totalRuns = 27 }
        if self.totalDistance == 0 { self.totalDistance = 38 }
    }

    func registerRun(score: Int) {
        totalRuns += 1
        totalDistance += max(1, score / 4)
        if score > bestScore { bestScore = score }
        defaults.set(bestScore, forKey: Keys.best)
        defaults.set(totalRuns, forKey: Keys.runs)
        defaults.set(totalDistance, forKey: Keys.distance)
    }

    private enum Keys {
        static let best = "cd.bestScore"
        static let runs = "cd.totalRuns"
        static let distance = "cd.totalDistance"
        static let pilot = "cd.pilotName"
    }
}

struct LeaderboardEntry: Identifiable, Hashable {
    let id = UUID()
    let rank: Int
    let name: String
    let score: Int
    let isYou: Bool

    static let sample: [LeaderboardEntry] = [
        .init(rank: 1, name: "Stardancer", score: 612, isYou: false),
        .init(rank: 2, name: "Lyra-7", score: 488, isYou: false),
        .init(rank: 3, name: "Orion Vex", score: 341, isYou: false),
        .init(rank: 4, name: "Pilot Nova", score: 142, isYou: true),
        .init(rank: 5, name: "Ghost Comet", score: 96, isYou: false)
    ]
}

struct RunRecord: Identifiable, Hashable {
    let id = UUID()
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
