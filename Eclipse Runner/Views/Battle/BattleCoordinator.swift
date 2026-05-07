import Foundation
import Combine

// MARK: - Battle Phase
enum BattlePhase: Equatable {
    case idle
    case searching          // finding a room
    case waitingForOpponent // room created, waiting 2nd player
    case playing            // in game
    case waitingResult      // my game done, waiting opponent
    case result(BattleResult)
    case error(String)
    case offline
}

extension BattleResult: Equatable {
    static func == (lhs: BattleResult, rhs: BattleResult) -> Bool {
        lhs.myScore == rhs.myScore && lhs.opponentScore == rhs.opponentScore
    }
}

// MARK: - Coordinator

@MainActor
final class BattleCoordinator: ObservableObject {
    @Published var phase: BattlePhase = .idle
    @Published var currentRoom: BattleRoom?
    @Published var myScore: Int = 0
    @Published var opponentFinished: Bool = false
    @Published var waitingSecondsLeft: Int = 60

    private var pilotName: String = ""
    private var pollTimer: Timer?
    private var waitTimer: Timer?

    // MARK: - Start matchmaking
    func startSearch(pilotName: String) {
        guard SupabaseConfig.current != nil else { phase = .offline; return }
        self.pilotName = pilotName
        phase = .searching

        BattleService.shared.findOrCreateRoom(pilotName: pilotName) { [weak self] room, error in
            guard let self else { return }
            if let error {
                self.phase = .error(error.localizedDescription)
                return
            }
            guard let room else { self.phase = .error("Could not find or create room"); return }
            self.currentRoom = room
            if room.status == "waiting" {
                self.phase = .waitingForOpponent
                self.startWaitTimer()
                self.startPolling(phase: .waitingForOpponent)
            } else {
                // Joined an existing room — go straight to game
                self.phase = .playing
            }
        }
    }

    // MARK: - After game ends — submit score
    func submitMyScore(_ score: Int) {
        myScore = score
        guard let room = currentRoom else { return }
        phase = .waitingResult

        BattleService.shared.submitScore(roomID: room.id, pilotName: pilotName, score: score) { [weak self] _ in
            guard let self else { return }
            self.startPolling(phase: .waitingResult)
        }
    }

    // MARK: - Cancel / leave
    func cancel() {
        stopTimers()
        if let room = currentRoom, room.status == "waiting" {
            BattleService.shared.cancelRoom(roomID: room.id)
        }
        currentRoom = nil
        phase = .idle
    }

    func reset() {
        stopTimers()
        currentRoom = nil
        myScore = 0
        opponentFinished = false
        waitingSecondsLeft = 60
        phase = .idle
    }

    // MARK: - Polling

    private func startPolling(phase: BattlePhase) {
        stopPolling()
        let interval: TimeInterval = phase == .waitingResult ? 2.0 : 3.0
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func poll() {
        guard let room = currentRoom else { return }
        BattleService.shared.pollRoom(roomID: room.id) { [weak self] updatedRoom, participants in
            guard let self else { return }
            if let r = updatedRoom { self.currentRoom = r }

            switch self.phase {
            case .waitingForOpponent:
                // Check if opponent joined
                if participants.count >= 2 || updatedRoom?.status == "in_progress" {
                    self.stopTimers()
                    self.phase = .playing
                } else if updatedRoom?.status == "cancelled" {
                    self.phase = .error("Match cancelled — no opponent joined")
                }

            case .waitingResult:
                // Check if opponent also finished
                let myName = self.pilotName.lowercased()
                let me = participants.first { $0.pilotName.lowercased() == myName }
                let opponent = participants.first { $0.pilotName.lowercased() != myName }

                if let opp = opponent, opp.score != nil {
                    // Both done
                    self.stopPolling()
                    let oppScore = opp.score ?? 0
                    let result = BattleResult(
                        myScore: self.myScore,
                        opponentScore: oppScore,
                        opponentName: opp.pilotName,
                        didWin: self.myScore > oppScore,
                        isDraw: self.myScore == oppScore
                    )
                    BattleService.shared.completeRoom(roomID: room.id) { _ in }
                    self.phase = .result(result)
                } else if let r = updatedRoom, r.status == "completed" {
                    // Room already completed externally
                    self.stopPolling()
                    let oppScore = opponent?.score ?? 0
                    let oppName = opponent?.pilotName ?? "Opponent"
                    let result = BattleResult(
                        myScore: self.myScore,
                        opponentScore: oppScore,
                        opponentName: oppName,
                        didWin: self.myScore > oppScore,
                        isDraw: self.myScore == oppScore
                    )
                    self.phase = .result(result)
                }
                // else keep waiting

            default:
                break
            }
        }
    }

    // MARK: - Wait timer (60s timeout for opponent)

    private func startWaitTimer() {
        waitingSecondsLeft = 60
        waitTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.waitingSecondsLeft -= 1
                if self.waitingSecondsLeft <= 0 {
                    self.stopTimers()
                    if let room = self.currentRoom {
                        BattleService.shared.cancelRoom(roomID: room.id)
                    }
                    self.phase = .error("No opponent found. Try again!")
                }
            }
        }
    }

    private func stopTimers() {
        stopPolling()
        waitTimer?.invalidate()
        waitTimer = nil
    }

    deinit {
        pollTimer?.invalidate()
        waitTimer?.invalidate()
    }
}
