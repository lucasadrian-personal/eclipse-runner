import SwiftUI
import SpriteKit

// MARK: - Main BattleView

struct BattleView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coord = BattleCoordinator()
    @State private var showCodeEntry = false
    @State private var enteredCode = ""

    var body: some View {
        ZStack {
            Theme.cosmicBackground.ignoresSafeArea()
            StarfieldView(starCount: 60, showsNebula: true).ignoresSafeArea()
            phaseContent
        }
        .navigationBarHidden(true)
        .onAppear { coord.startIncomingChallengePoll(pilotName: store.pilotName) }
        .onDisappear { coord.cancel() }
        .overlay(incomingChallengeOverlay)
        .sheet(isPresented: $showCodeEntry) { codeEntrySheet }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch coord.phase {
        case .idle:
            BattleLobbyView(
                pilotName: store.pilotName,
                lastOpponent: coord.lastOpponentName,
                rivalry: coord.rivalryStats,
                onRandom:       { coord.startSearch(pilotName: store.pilotName) },
                onSameOpponent: { coord.challengeSameOpponent() },
                onPrivate:      { coord.createPrivateRoom(pilotName: store.pilotName) },
                onJoinCode:     { showCodeEntry = true },
                onCancel:       { dismiss() }
            )
        case .searching(let msg):
            BattleSearchingView(message: msg)
        case .waitingForOpponent:
            BattleWaitingView(
                secondsLeft: coord.waitingSecondsLeft,
                roomCode: coord.currentRoom?.roomCode,
                onCancel: { coord.cancel(); dismiss() }
            )
        case .playing:
            if let room = coord.currentRoom {
                BattleGameView(room: room, pilotName: store.pilotName, coord: coord)
                    .environmentObject(store)
            }
        case .waitingResult:
            BattleWaitingResultView(myScore: coord.myScore)
        case .result(let result):
            BattleResultView(
                result: result,
                pilotName: store.pilotName,
                rivalry: coord.rivalryStats,
                onSameOpponent: { coord.challengeSameOpponent() },
                onRandom:       { coord.reset() },
                onHome:         { dismiss() }
            )
        case .error(let msg):
            BattleErrorView(message: msg, onRetry: { coord.reset() }, onHome: { dismiss() })
        case .offline:
            BattleOfflineView { dismiss() }
        }
    }

    @ViewBuilder
    private var incomingChallengeOverlay: some View {
        if let challenge = coord.incomingChallenge {
            IncomingChallengeToast(
                from: challenge.hostName ?? "Unknown",
                onAccept: { coord.acceptIncomingChallenge(pilotName: store.pilotName, room: challenge) },
                onDecline: { coord.dismissIncomingChallenge() }
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: coord.incomingChallenge != nil)
            .zIndex(100)
        }
    }

    private var codeEntrySheet: some View {
        CodeEntryView(code: $enteredCode) {
            showCodeEntry = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                coord.joinByCode(enteredCode, pilotName: store.pilotName)
            }
        } onCancel: {
            showCodeEntry = false
        }
        .presentationDetents([.fraction(0.45)])
        .presentationBackground(Theme.spaceTop)
    }
}

// MARK: - Lobby

private struct BattleLobbyView: View {
    let pilotName: String
    let lastOpponent: String
    let rivalry: RivalryStats?
    let onRandom: () -> Void
    let onSameOpponent: () -> Void
    let onPrivate: () -> Void
    let onJoinCode: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)
                titleHeader
                if !lastOpponent.isEmpty {
                    rematchOption
                }
                privateOption
                randomOption
                Button(action: onCancel) {
                    Text("Back")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity).frame(height: 44)
                }
                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 24)
        }
    }

    private var titleHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .black)).foregroundStyle(Theme.nebulaPink)
                Text("BATTLE 1v1")
                    .font(.system(size: 24, weight: .black, design: .rounded)).tracking(4)
                    .foregroundStyle(Theme.textPrimary)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .black)).foregroundStyle(Theme.nebulaPink)
            }
            Text("Choose your challenge mode")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var rematchOption: some View {
        VStack(spacing: 10) {
            Button(action: onSameOpponent) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Theme.nebulaPink.opacity(0.2)).frame(width: 48, height: 48)
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.nebulaPink)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Retar de nuevo")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text("a \(lastOpponent)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.nebulaPink)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.textTertiary)
                }
                .padding(16)
                .background(
                    LinearGradient(colors: [Theme.nebulaPink.opacity(0.15), Theme.nebulaPurple.opacity(0.08)],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.nebulaPink.opacity(0.4), lineWidth: 1.5))
            }
            .buttonStyle(.plain)

            if let r = rivalry, r.total > 0 {
                HStack(spacing: 0) {
                    rivalStat(value: r.myWins,    label: "WINS",   tint: Theme.auroraMint)
                    rivalStat(value: r.draws,     label: "DRAWS",  tint: Theme.starGold)
                    rivalStat(value: r.theirWins, label: "LOSSES", tint: Theme.nebulaPink)
                }
                .padding(.vertical, 10)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1))
            }
        }
    }

    private var privateOption: some View {
        VStack(spacing: 0) {
            Button(action: onPrivate) {
                lobbyRow(icon: "key.fill", tint: Theme.starGold,
                         title: "Duelo privado", sub: "Crea sala y comparte el código")
            }
            .buttonStyle(.plain)
            Divider().background(Theme.surfaceStroke)
            Button(action: onJoinCode) {
                lobbyRow(icon: "qrcode", tint: Theme.auroraCyan,
                         title: "Unirse con código", sub: "Introduce el código de 6 caracteres")
            }
            .buttonStyle(.plain)
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Theme.surfaceStroke, lineWidth: 1))
    }

    private var randomOption: some View {
        Button(action: onRandom) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.nebulaPurple.opacity(0.2)).frame(width: 48, height: 48)
                    Image(systemName: "shuffle")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.nebulaPurple)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Rival aleatorio")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.textPrimary)
                    Text("Cualquier piloto online ahora")
                        .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.textTertiary)
            }
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.surfaceStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func lobbyRow(icon: String, tint: Color, title: String, sub: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold)).foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(Theme.textPrimary)
                Text(sub).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textTertiary)
        }
        .padding(16)
    }

    private func rivalStat(value: Int, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(tint)
            Text(label).font(.system(size: 8, weight: .bold, design: .rounded)).tracking(1.5).foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Searching

private struct BattleSearchingView: View {
    let message: String
    @State private var dots = ""
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .tint(Theme.nebulaPink)
                .scaleEffect(1.6)
            Text(message + dots)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .onReceive(timer) { _ in
            dots = dots.count < 3 ? dots + "." : ""
        }
    }
}

// MARK: - Waiting for Opponent

private struct BattleWaitingView: View {
    let secondsLeft: Int
    let roomCode: String?
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            countdownRing
            waitingInfo
            if let code = roomCode {
                codeCard(code: code)
            }
            Spacer()
            cancelButton
        }
    }

    private var countdownRing: some View {
        ZStack {
            Circle().stroke(Theme.nebulaPink.opacity(0.2), lineWidth: 4).frame(width: 120, height: 120)
            Circle().trim(from: 0, to: CGFloat(secondsLeft) / 60.0)
                .stroke(Theme.nebulaPink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: secondsLeft)
            VStack(spacing: 2) {
                Text("\(secondsLeft)")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.textPrimary).monospacedDigit()
                Text("sec").font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var waitingInfo: some View {
        VStack(spacing: 8) {
            Text("Room Created!")
                .font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(Theme.textPrimary)
            Text(roomCode != nil ? "Share the code below" : "Waiting for an opponent to join…")
                .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(Theme.textSecondary)
        }
    }

    private func codeCard(code: String) -> some View {
        VStack(spacing: 8) {
            Text("ROOM CODE")
                .font(.system(size: 10, weight: .black, design: .rounded)).tracking(2)
                .foregroundStyle(Theme.textTertiary)
            Text(code)
                .font(.system(size: 36, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.starGold)
                .tracking(8)
            Text("Share this code with your opponent")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 20).padding(.horizontal, 24)
        .background(Theme.starGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Theme.starGold.opacity(0.3), lineWidth: 1.5))
        .padding(.horizontal, 32)
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Text("Cancel")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1))
        }
        .padding(.horizontal, 32).padding(.bottom, 48)
    }
}

// MARK: - Battle Game (actual gameplay)

struct BattleGameView: View {
    let room: BattleRoom
    let pilotName: String
    let coord: BattleCoordinator

    @EnvironmentObject private var store: GameStore
    @StateObject private var gameCoord = GameCoordinator()
    @State private var sceneID = 0
    @State private var showOver = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Theme.cosmicBackground.ignoresSafeArea()
                if gameCoord.isReady {
                    SpriteView(scene: gameCoord.scene!, options: [.allowsTransparency])
                        .ignoresSafeArea()
                        .id(sceneID)
                }
                battleHUD
                    .padding(.top, 56).padding(.horizontal, 20)
            }
            .onAppear {
                if !gameCoord.isReady {
                    gameCoord.setup(screenSize: geo.size, store: store, mode: .normal)
                    // Apply room seed for deterministic obstacles
                    gameCoord.scene?.battleSeed = room.seed
                }
            }
        }
        .onChange(of: gameCoord.gameOverInfo) { _, info in
            guard let info else { return }
            Task { @MainActor in
                coord.submitMyScore(info.score)
            }
        }
        .navigationBarHidden(true)
    }

    private var battleHUD: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("YOU")
                    .font(.system(size: 9, weight: .black, design: .rounded)).tracking(1.5)
                    .foregroundStyle(Theme.auroraCyan)
                Text("\(gameCoord.score)")
                    .font(.system(size: 26, weight: .black, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.bouncy, value: gameCoord.score)
            }
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: "bolt.fill").font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.nebulaPink)
                Text("BATTLE").font(.system(size: 9, weight: .black, design: .rounded)).tracking(2)
                    .foregroundStyle(Theme.nebulaPink)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("OPP").font(.system(size: 9, weight: .black, design: .rounded)).tracking(1.5)
                    .foregroundStyle(Theme.nebulaPink)
                Text("?")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Waiting for Result

private struct BattleWaitingResultView: View {
    let myScore: Int
    @State private var dots = ""
    private let timer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().fill(Theme.nebulaPurple.opacity(0.15)).frame(width: 120, height: 120)
                ProgressView().tint(Theme.nebulaPurple).scaleEffect(1.8)
            }
            VStack(spacing: 8) {
                Text("Your score: \(myScore)")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.auroraCyan)
                Text("Waiting for opponent" + dots)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .onReceive(timer) { _ in dots = dots.count < 3 ? dots + "." : "" }
    }
}

// MARK: - Result Screen

private struct BattleResultView: View {
    let result: BattleResult
    let pilotName: String
    let rivalry: RivalryStats?
    let onSameOpponent: () -> Void
    let onRandom: () -> Void
    let onHome: () -> Void
    @State private var appear = false

    private var didWin: Bool { result.didWin }
    private var isDraw: Bool { result.isDraw }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)
                outcomeHeader
                    .scaleEffect(appear ? 1 : 0.5).opacity(appear ? 1 : 0)
                Spacer().frame(height: 28)
                scoreComparison
                    .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 30)
                if let r = rivalry, r.total > 0 {
                    Spacer().frame(height: 20)
                    rivalryCard(r)
                        .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 40)
                        .padding(.horizontal, 28)
                }
                Spacer().frame(height: 32)
                actionButtons
                    .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 40)
                    .padding(.horizontal, 28).padding(.bottom, 44)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) { appear = true }
        }
    }

    private var outcomeHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill((isDraw ? Theme.starGold : didWin ? Theme.auroraMint : Theme.nebulaPink).opacity(0.18))
                    .frame(width: 100, height: 100)
                Image(systemName: isDraw ? "equal.circle.fill" : didWin ? "crown.fill" : "xmark.circle.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(isDraw ? Theme.starGold : didWin ? Theme.auroraMint : Theme.nebulaPink)
            }
            Text(isDraw ? "IT'S A DRAW!" : didWin ? "YOU WON!" : "YOU LOST")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(isDraw ? Theme.starGold : didWin ? Theme.auroraMint : Theme.nebulaPink)
            Text(isDraw ? "An epic tie between pilots!" :
                 didWin ? "Dominant performance, \(pilotName)!" :
                 "\(result.opponentName) flew further this time.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
    }

    private var scoreComparison: some View {
        HStack(spacing: 0) {
            scoreColumn(name: pilotName, score: result.myScore, isWinner: didWin || isDraw, isMe: true)
            Image(systemName: "bolt.fill")
                .font(.system(size: 20, weight: .black)).foregroundStyle(Theme.nebulaPink)
                .frame(width: 44)
            scoreColumn(name: result.opponentName, score: result.opponentScore,
                        isWinner: !didWin || isDraw, isMe: false)
        }
        .padding(.horizontal, 24)
    }

    private func rivalryCard(_ r: RivalryStats) -> some View {
        VStack(spacing: 10) {
            Text("HEAD TO HEAD")
                .font(.system(size: 10, weight: .black, design: .rounded)).tracking(2)
                .foregroundStyle(Theme.textTertiary)
            HStack(spacing: 0) {
                rivalStat(value: r.myWins,    label: "WINS",   tint: Theme.auroraMint)
                rivalStat(value: r.draws,     label: "DRAWS",  tint: Theme.starGold)
                rivalStat(value: r.theirWins, label: "LOSSES", tint: Theme.nebulaPink)
            }
            .padding(.vertical, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.surfaceStroke, lineWidth: 1))
        }
    }

    private func rivalStat(value: Int, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(value)").font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(tint)
            Text(label).font(.system(size: 8, weight: .bold, design: .rounded)).tracking(1.5)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onSameOpponent) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 15, weight: .black))
                    Text("Retar de nuevo a \(result.opponentName)")
                        .font(.system(size: 15, weight: .black, design: .rounded)).lineLimit(1)
                }
                .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.18))
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(
                    LinearGradient(colors: [Theme.nebulaPink, Theme.nebulaPurple],
                                   startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.nebulaPink.opacity(0.45), radius: 14, y: 7)
            }
            Button(action: onRandom) {
                HStack(spacing: 8) {
                    Image(systemName: "shuffle").font(.system(size: 14, weight: .bold))
                    Text("Nuevo rival")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1))
            }
            Button(action: onHome) {
                Text("Back to Home")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 46)
            }
        }
    }

    private func scoreColumn(name: String, score: Int, isWinner: Bool, isMe: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isMe ? Theme.auroraCyan.opacity(0.18) : Theme.nebulaPink.opacity(0.12))
                    .frame(width: 56, height: 56)
                if isWinner && !isDraw {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.starGold)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isMe ? Theme.auroraCyan : Theme.textSecondary)
                }
            }
            Text(name).font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isMe ? Theme.auroraCyan : Theme.textSecondary).lineLimit(1)
            Text("\(score)").font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(isWinner ? Theme.textPrimary : Theme.textTertiary).monospacedDigit()
            if isWinner && !isDraw {
                Text("WINNER")
                    .font(.system(size: 9, weight: .black, design: .rounded)).tracking(2)
                    .foregroundStyle(Theme.starGold).padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.starGold.opacity(0.18), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Incoming Challenge Toast

private struct IncomingChallengeToast: View {
    let from: String
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.nebulaPink.opacity(0.25)).frame(width: 40, height: 40)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .black)).foregroundStyle(Theme.nebulaPink)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Challenge received!")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(from) is challenging you")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.nebulaPink)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: onAccept) {
                        Text("Accept")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.18))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Theme.nebulaPink, in: Capsule())
                    }
                    Button(action: onDecline) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(Theme.surface, in: Circle())
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.nebulaPink.opacity(0.3), lineWidth: 1))
            .shadow(color: Theme.nebulaPink.opacity(0.2), radius: 16, y: 6)
            .padding(.horizontal, 16).padding(.top, 56)
            Spacer()
        }
    }
}

// MARK: - Code Entry Sheet

private struct CodeEntryView: View {
    @Binding var code: String
    let onJoin: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Text("Join Private Room")
                    .font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(Theme.textPrimary)
                Text("Enter the 6-character room code")
                    .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 28)

            TextField("", text: $code)
                .font(.system(size: 34, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.starGold)
                .multilineTextAlignment(.center)
                .tracking(10)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .onChange(of: code) { _, new in
                    let filtered = String(new.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                    if filtered != code { code = filtered }
                }
                .focused($isFocused)
                .frame(height: 64)
                .padding(.horizontal, 20)
                .background(Theme.starGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(code.count == 6 ? Theme.starGold.opacity(0.5) : Theme.surfaceStroke, lineWidth: 1.5))
                .padding(.horizontal, 28)
                .onAppear { isFocused = true }

            VStack(spacing: 10) {
                Button(action: onJoin) {
                    Text("JOIN ROOM")
                        .font(.system(size: 17, weight: .black, design: .rounded)).tracking(2)
                        .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.18))
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(
                            LinearGradient(colors: code.count == 6
                                           ? [Theme.starGold, Theme.auroraCyan]
                                           : [Theme.textTertiary.opacity(0.4), Theme.textTertiary.opacity(0.4)],
                                           startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(code.count < 6)
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity).frame(height: 44)
                }
            }
            .padding(.horizontal, 28)
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Error

private struct BattleErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onHome: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 52, weight: .bold)).foregroundStyle(Theme.nebulaPink)
            VStack(spacing: 8) {
                Text("Connection Issue")
                    .font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            }
            Spacer()
            VStack(spacing: 12) {
                Button(action: onRetry) {
                    Text("Try Again")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.18))
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Theme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                Button(action: onHome) {
                    Text("Back to Home")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.surfaceStroke, lineWidth: 1))
                }
            }
            .padding(.horizontal, 28).padding(.bottom, 48)
        }
    }
}

// MARK: - Offline

private struct BattleOfflineView: View {
    let onHome: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 52, weight: .bold)).foregroundStyle(Theme.textTertiary)
            VStack(spacing: 8) {
                Text("Battle requires internet")
                    .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Theme.textPrimary)
                Text("Connect to WiFi or mobile data\nto challenge other pilots.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            }
            Spacer()
            Button(action: onHome) {
                Text("Back")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.surfaceStroke, lineWidth: 1))
            }
            .padding(.horizontal, 28).padding(.bottom, 48)
        }
    }
}
