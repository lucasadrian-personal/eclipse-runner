import Foundation
import Combine

// MARK: - Battle Phase
enum BattlePhase: Equatable {
    case idle
    case searching(message: String)
    case waitingForOpponent
    case playing
    case waitingResult
    case result(BattleResult)
    case error(String)
    case offline
}

extension BattleResult: Equatable {
    static func == (lhs: BattleResult, rhs: BattleResult) -> Bool {
        lhs.myScore == rhs.myScore && lhs.opponentScore == rhs.opponentScore
    }
}

// MARK: - Rematch mode
enum RematchMode {
    case sameOpponent
    case randomOpponent
}

// MARK: - Coordinator

@MainActor
final class BattleCoordinator: ObservableObject {
    @Published var phase: BattlePhase = .idle
    @Published var currentRoom: BattleRoom?
    @Published var myScore: Int = 0
    @Published var waitingSecondsLeft: Int = 60
    @Published var rivalryStats: RivalryStats? = nil
    @Published var incomingChallenge: BattleRoom? = nil

    private(set) var pilotName: String = ""
    private(set) var lastOpponentName: String = ""

    private var pollTimer: Timer?
    private var waitTimer: Timer?
    private var incomingTimer: Timer?

    // MARK: - Random matchmaking
    func startSearch(pilotName: String) {
        guard SupabaseConfig.current != nil else { phase = .offline; return }
        self.pilotName = pilotName
        phase = .searching(message: "Finding opponent")
        BattleService.shared.findOrCreateRoom(pilotName: pilotName) { [weak self] room, error in
            self?.handleRoomResult(room: room, error: error)
        }
    }

    // MARK: - Challenge same opponent
    func challengeSameOpponent() {
        guard SupabaseConfig.current != nil else { phase = .offline; return }
        guard !lastOpponentName.isEmpty else { return }
        let opp = lastOpponentName
        phase = .searching(message: "Challenging \(opp)")
        BattleService.shared.challengeSameOpponent(myName: pilotName, opponentName: opp) { [weak self] room, error in
            self?.handleRoomResult(room: room, error: error)
        }
    }

    // MARK: - Create private room (share code)
    func createPrivateRoom(pilotName: String) {
        guard SupabaseConfig.current != nil else { phase = .offline; return }
        self.pilotName = pilotName
        phase = .searching(message: "Creating private room")
        BattleService.shared.createPrivateRoom(pilotName: pilotName) { [weak self] room, error in
            self?.handleRoomResult(room: room, error: error)
        }
    }

    // MARK: - Join by code
    func joinByCode(_ code: String, pilotName: String) {
        guard SupabaseConfig.current != nil else { phase = .offline; return }
        self.pilotName = pilotName
        phase = .searching(message: "Joining room")
        BattleService.shared.joinByCode(code, pilotName: pilotName) { [weak self] room, error in
            self?.handleRoomResult(room: room, error: error)
        }
    }

    // MARK: - Accept incoming challenge
    func acceptIncomingChallenge(pilotName: String, room: BattleRoom) {
        guard SupabaseConfig.current != nil else { phase = .offline; return }
        self.pilotName = pilotName
        phase = .searching(message: "Joining challenge")
        incomingChallenge = nil
        stopIncomingTimer()
        BattleService.shared.joinByCode(room.roomCode ?? "", pilotName: pilotName) { [weak self] joined, error in
            self?.handleRoomResult(room: joined ?? room, error: error)
        }
    }

    // MARK: - Submit score after game ends
    func submitMyScore(_ score: Int) {
        myScore = score
        guard let room = currentRoom else { return }
        phase = .waitingResult
        BattleService.shared.submitScore(roomID: room.id, pilotName: pilotName, score: score) { [weak self] _ in
            self?.startPolling(forResult: true)
        }
    }

    // MARK: - Check for incoming challenges (call periodically from lobby)
    func startIncomingChallengePoll(pilotName: String) {
        stopIncomingTimer()
        incomingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, case .idle = self.phase else { return }
                BattleService.shared.checkIncomingChallenge(for: pilotName) { [weak self] room in
                    if let room, self?.incomingChallenge == nil {
                        self?.incomingChallenge = room
                    }
                }
            }
        }
    }

    func dismissIncomingChallenge() {
        if let room = incomingChallenge {
            BattleService.shared.cancelRoom(roomID: room.id)
        }
        incomingChallenge = nil
    }

    // MARK: - Cancel / Reset

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
        waitingSecondsLeft = 60
        rivalryStats = nil
        phase = .idle
    }

    // MARK: - Internals

    private func handleRoomResult(room: BattleRoom?, error: Error?) {
        if let error {
            phase = .error(error.localizedDescription); return
        }
        guard let room else {
            phase = .error("Could not find or create room"); return
        }
        currentRoom = room
        if room.status == "waiting" {
            phase = .waitingForOpponent
            startWaitTimer()
            startPolling(forResult: false)
        } else {
            phase = .playing
        }
    }

    // MARK: - Polling

    private func startPolling(forResult: Bool) {
        stopPolling()
        let interval: TimeInterval = forResult ? 2.0 : 3.0
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
                if participants.count >= 2 || updatedRoom?.status == "in_progress" {
                    self.stopTimers()
                    self.phase = .playing
                } else if updatedRoom?.status == "cancelled" {
                    self.phase = .error("Match cancelled — no opponent joined")
                }

            case .waitingResult:
                let myName = self.pilotName.lowercased()
                let opponent = participants.first { $0.pilotName.lowercased() != myName }
                if let opp = opponent, opp.score != nil {
                    self.stopPolling()
                    self.finishResult(oppScore: opp.score ?? 0, oppName: opp.pilotName, roomID: room.id)
                } else if updatedRoom?.status == "completed" {
                    self.stopPolling()
                    let oppScore = opponent?.score ?? 0
                    let oppName = opponent?.pilotName ?? "Opponent"
                    self.finishResult(oppScore: oppScore, oppName: oppName, roomID: room.id)
                }

            default: break
            }
        }
    }

    private func finishResult(oppScore: Int, oppName: String, roomID: String) {
        let didWin = myScore > oppScore
        let isDraw = myScore == oppScore
        let result = BattleResult(myScore: myScore, opponentScore: oppScore,
                                  opponentName: oppName, didWin: didWin, isDraw: isDraw)
        lastOpponentName = oppName
        BattleService.shared.completeRoom(roomID: roomID) { _ in }

        // Record rivalry async
        BattleService.shared.recordRivalry(me: pilotName, opponent: oppName,
                                            didWin: isDraw ? nil : didWin,
                                            isDraw: isDraw) { _ in }
        // Fetch updated stats
        BattleService.shared.fetchRivalry(me: pilotName, opponent: oppName) { [weak self] stats in
            self?.rivalryStats = stats
        }
        phase = .result(result)
    }

    // MARK: - Wait timer

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

    private func stopIncomingTimer() {
        incomingTimer?.invalidate()
        incomingTimer = nil
    }

    private func stopTimers() {
        stopPolling()
        waitTimer?.invalidate()
        waitTimer = nil
    }

    deinit {
        pollTimer?.invalidate()
        waitTimer?.invalidate()
        incomingTimer?.invalidate()
    }
}
