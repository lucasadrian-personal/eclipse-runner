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

    // Live opponent data via Realtime Broadcast
    @Published var opponentLiveScore: Int = 0
    @Published var opponentLiveSkinID: String = "classic"
    @Published var opponentName: String = ""
    @Published var opponentScoreJustUpdated: Bool = false

    private(set) var pilotName: String = ""
    private(set) var lastOpponentName: String = ""

    private var pollTimer: Timer?
    private var waitTimer: Timer?
    private var incomingTimer: Timer?
    private var scorePulseTimer: Timer?

    // MARK: - Random matchmaking
    func startSearch(pilotName: String) {
        guard SupabaseConfig.current != nil else { phase = .offline; return }
        self.pilotName = pilotName
        phase = .searching(message: "Finding opponent")
        NSLog("[Coord] startSearch: pilot=%@", pilotName)
        BattleService.shared.findOrCreateRoom(pilotName: pilotName) { [weak self] room, error in
            Task { @MainActor [weak self] in
                NSLog("[Coord] startSearch callback: room=%@ error=%@",
                      room?.id ?? "nil", error?.localizedDescription ?? "nil")
                self?.handleRoomResult(room: room, error: error)
            }
        }
    }

    // MARK: - Challenge same opponent
    func challengeSameOpponent() {
        guard SupabaseConfig.current != nil else { phase = .offline; return }
        guard !lastOpponentName.isEmpty else { return }
        let opp = lastOpponentName
        phase = .searching(message: "Challenging \(opp)")
        BattleService.shared.challengeSameOpponent(myName: pilotName, opponentName: opp) { [weak self] room, error in
            Task { @MainActor [weak self] in self?.handleRoomResult(room: room, error: error) }
        }
    }

    // MARK: - Create private room (share code)
    func createPrivateRoom(pilotName: String) {
        guard SupabaseConfig.current != nil else { phase = .offline; return }
        self.pilotName = pilotName
        phase = .searching(message: "Creating private room")
        NSLog("[Coord] createPrivateRoom: pilot=%@", pilotName)
        BattleService.shared.createPrivateRoom(pilotName: pilotName) { [weak self] room, error in
            Task { @MainActor [weak self] in
                NSLog("[Coord] createPrivateRoom callback: room=%@ error=%@",
                      room?.id ?? "nil", error?.localizedDescription ?? "nil")
                self?.handleRoomResult(room: room, error: error)
            }
        }
    }

    // MARK: - Join by code
    func joinByCode(_ code: String, pilotName: String) {
        guard SupabaseConfig.current != nil else { phase = .offline; return }
        self.pilotName = pilotName
        phase = .searching(message: "Joining room")
        NSLog("[Coord] joinByCode: code=%@ pilot=%@", code, pilotName)
        BattleService.shared.joinByCode(code, pilotName: pilotName) { [weak self] room, error in
            Task { @MainActor [weak self] in
                NSLog("[Coord] joinByCode callback: room=%@ error=%@",
                      room?.id ?? "nil", error?.localizedDescription ?? "nil")
                self?.handleRoomResult(room: room, error: error)
            }
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
            Task { @MainActor [weak self] in
                NSLog("[Coord] acceptIncomingChallenge callback: room=%@ error=%@",
                      joined?.id ?? "nil", error?.localizedDescription ?? "nil")
                self?.handleRoomResult(room: joined ?? room, error: error)
            }
        }
    }

    // MARK: - Connect Realtime for live scores
    func connectRealtime(skinID: String) {
        guard let room = currentRoom else { return }
        BattleRealtimeService.shared.connect(roomID: room.id, myPilotName: pilotName)
        BattleRealtimeService.shared.onOpponentScore = { [weak self] broadcast in
            guard let self else { return }
            self.opponentLiveScore = broadcast.score
            self.opponentLiveSkinID = broadcast.skinID
            if self.opponentName.isEmpty { self.opponentName = broadcast.pilot }
            // Trigger pulse animation
            self.opponentScoreJustUpdated = true
            self.scorePulseTimer?.invalidate()
            self.scorePulseTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in self?.opponentScoreJustUpdated = false }
            }
        }
    }

    // MARK: - Broadcast my live score (called from game loop)
    func broadcastLiveScore(_ score: Int, skinID: String) {
        BattleRealtimeService.shared.broadcastScore(score, skinID: skinID)
    }

    // MARK: - Submit score after game ends
    func submitMyScore(_ score: Int) {
        myScore = score
        BattleRealtimeService.shared.disconnect()
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
        BattleRealtimeService.shared.disconnect()
        if let room = currentRoom, room.status == "waiting" {
            BattleService.shared.cancelRoom(roomID: room.id)
        }
        currentRoom = nil
        phase = .idle
    }

    func reset() {
        stopTimers()
        BattleRealtimeService.shared.disconnect()
        currentRoom = nil
        myScore = 0
        waitingSecondsLeft = 60
        rivalryStats = nil
        opponentLiveScore = 0
        opponentLiveSkinID = "classic"
        opponentName = ""
        opponentScoreJustUpdated = false
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

    private func stopTimers() {
        stopPolling()
        waitTimer?.invalidate()
        waitTimer = nil
        scorePulseTimer?.invalidate()
        scorePulseTimer = nil
    }

    private func stopIncomingTimer() {
        incomingTimer?.invalidate()
        incomingTimer = nil
    }

    deinit {
        pollTimer?.invalidate()
        waitTimer?.invalidate()
        incomingTimer?.invalidate()
        scorePulseTimer?.invalidate()
        BattleRealtimeService.shared.disconnect()
    }
}
