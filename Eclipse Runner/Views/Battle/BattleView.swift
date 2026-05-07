import SwiftUI
import SpriteKit

// MARK: - Main BattleView

struct BattleView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coord = BattleCoordinator()

    var body: some View {
        ZStack {
            Theme.cosmicBackground.ignoresSafeArea()
            StarfieldView(starCount: 60, showsNebula: true).ignoresSafeArea()

            Group {
                switch coord.phase {
                case .idle:
                    BattleLobbyView(pilotName: store.pilotName) {
                        coord.startSearch(pilotName: store.pilotName)
                    } onCancel: {
                        dismiss()
                    }
                case .searching:
                    BattleSearchingView(message: "Finding room…")
                case .waitingForOpponent:
                    BattleWaitingView(secondsLeft: coord.waitingSecondsLeft) {
                        coord.cancel()
                        dismiss()
                    }
                case .playing:
                    if let room = coord.currentRoom {
                        BattleGameView(room: room, pilotName: store.pilotName, coord: coord)
                            .environmentObject(store)
                    }
                case .waitingResult:
                    BattleWaitingResultView(myScore: coord.myScore)
                case .result(let result):
                    BattleResultView(result: result, pilotName: store.pilotName) {
                        coord.reset()
                    } onHome: {
                        dismiss()
                    }
                case .error(let msg):
                    BattleErrorView(message: msg) {
                        coord.reset()
                    } onHome: {
                        dismiss()
                    }
                case .offline:
                    BattleOfflineView { dismiss() }
                }
            }
        }
        .navigationBarHidden(true)
        .onDisappear { coord.cancel() }
    }
}

// MARK: - Lobby

private struct BattleLobbyView: View {
    let pilotName: String
    let onStart: () -> Void
    let onCancel: () -> Void
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            // Title
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Theme.nebulaPink)
                    Text("BATTLE 1v1")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(Theme.textPrimary)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Theme.nebulaPink)
                }
                Text("Challenge a real pilot.\nSame obstacles. Who survives longer?")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // VS card
            HStack(spacing: 0) {
                pilotCard(name: pilotName, isMe: true)
                Text("VS")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.nebulaPink)
                    .frame(width: 52)
                pilotCard(name: "???", isMe: false)
            }
            .padding(.horizontal, 24)

            // Rules
            VStack(alignment: .leading, spacing: 10) {
                ruleRow(icon: "shuffle", text: "Same obstacle seed for both pilots")
                ruleRow(icon: "timer", text: "Survive as long as possible")
                ruleRow(icon: "trophy.fill", text: "Highest score wins the duel")
            }
            .padding(20)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.surfaceStroke, lineWidth: 1))
            .padding(.horizontal, 24)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button(action: onStart) {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill").font(.system(size: 16, weight: .black))
                        Text("FIND OPPONENT")
                            .font(.system(size: 18, weight: .black, design: .rounded)).tracking(2)
                    }
                    .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.18))
                    .frame(maxWidth: .infinity).frame(height: 60)
                    .background(
                        LinearGradient(colors: [Theme.nebulaPink, Theme.nebulaPurple],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Theme.nebulaPink.opacity(pulse ? 0.65 : 0.35), radius: pulse ? 28 : 18, y: 10)
                }
                .scaleEffect(pulse ? 1.015 : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
                }

                Button(action: onCancel) {
                    Text("Back")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity).frame(height: 44)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }

    private func pilotCard(name: String, isMe: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(isMe ? Theme.auroraCyan.opacity(0.18) : Theme.surface)
                    .frame(width: 64, height: 64)
                Image(systemName: isMe ? "person.fill" : "questionmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(isMe ? Theme.auroraCyan : Theme.textTertiary)
            }
            Text(isMe ? name : "Searching…")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(isMe ? Theme.textPrimary : Theme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func ruleRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.nebulaPink)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
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
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
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
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text("sec").font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            VStack(spacing: 8) {
                Text("Room Created!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("Waiting for an opponent to join…")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.surfaceStroke, lineWidth: 1))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
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
    let onPlayAgain: () -> Void
    let onHome: () -> Void
    @State private var appear = false

    private var didWin: Bool { result.didWin }
    private var isDraw: Bool { result.isDraw }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            // Outcome badge
            outcomeHeader
                .scaleEffect(appear ? 1 : 0.5).opacity(appear ? 1 : 0)

            Spacer().frame(height: 32)

            // Score comparison
            HStack(spacing: 0) {
                scoreColumn(name: pilotName, score: result.myScore, isWinner: didWin || isDraw, isMe: true)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .black)).foregroundStyle(Theme.nebulaPink)
                    .frame(width: 44)
                scoreColumn(name: result.opponentName, score: result.opponentScore,
                            isWinner: !didWin || isDraw, isMe: false)
            }
            .padding(.horizontal, 24)
            .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 30)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button(action: onPlayAgain) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 15, weight: .black))
                        Text("REMATCH")
                            .font(.system(size: 17, weight: .black, design: .rounded)).tracking(2)
                    }
                    .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.18))
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .background(
                        LinearGradient(colors: [Theme.nebulaPink, Theme.nebulaPurple],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Theme.nebulaPink.opacity(0.5), radius: 16, y: 8)
                }
                Button(action: onHome) {
                    Text("Back to Home")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.surfaceStroke, lineWidth: 1))
                }
            }
            .padding(.horizontal, 28).padding(.bottom, 44)
            .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 40)
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
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
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
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.starGold)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isMe ? Theme.auroraCyan : Theme.textSecondary)
                }
            }
            Text(name)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isMe ? Theme.auroraCyan : Theme.textSecondary)
                .lineLimit(1)
            Text("\(score)")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(isWinner ? Theme.textPrimary : Theme.textTertiary)
                .monospacedDigit()
            if isWinner && !isDraw {
                Text("WINNER")
                    .font(.system(size: 9, weight: .black, design: .rounded)).tracking(2)
                    .foregroundStyle(Theme.starGold)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.starGold.opacity(0.18), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
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
