import SwiftUI
import SpriteKit
import MultipeerConnectivity

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
                onNearbyHost:   { coord.startNearbyHost(pilotName: store.pilotName, skinID: store.activeSkinID) },
                onNearbyJoin:   { coord.startNearbyBrowse(pilotName: store.pilotName, skinID: store.activeSkinID) },
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
        case .nearbyHosting:
            NearbyHostingView(onCancel: { coord.cancelNearby() })
        case .nearbyBrowsing:
            NearbyBrowsingView(
                peers: BattleNearbyService.shared.nearbyPeers,
                onConnect: { peer in coord.nearbyConnect(to: peer) },
                onCancel: { coord.cancelNearby() }
            )
        case .playing:
            if let room = coord.currentRoom {
                BattleGameView(room: room, pilotName: store.pilotName, coord: coord)
                    .environmentObject(store)
            }
        case .nearbyPlaying:
            NearbyBattleGameView(seed: coord.nearbySeed, pilotName: store.pilotName, coord: coord)
                .environmentObject(store)
        case .waitingResult:
            BattleWaitingResultView(
                myScore: coord.myScore,
                opponentName: coord.opponentName,
                opponentLastScore: coord.opponentLiveScore
            )
        case .nearbyWaitingResult:
            BattleWaitingResultView(
                myScore: coord.myScore,
                opponentName: coord.opponentName,
                opponentLastScore: coord.opponentLiveScore
            )
        case .result(let result):
            BattleResultView(
                result: result,
                pilotName: store.pilotName,
                mySkinID: store.activeSkinID,
                opponentSkinID: coord.opponentLiveSkinID,
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
    let onNearbyHost: () -> Void
    let onNearbyJoin: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)
                titleHeader
                nearbySection
                if !lastOpponent.isEmpty { rematchOption }
                onlineSection
                Button(action: onCancel) {
                    Text(L10n.battleBack)
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
                Text(L10n.battleTitle)
                    .font(.system(size: 24, weight: .black, design: .rounded)).tracking(4)
                    .foregroundStyle(Theme.textPrimary)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .black)).foregroundStyle(Theme.nebulaPink)
            }
            Text(L10n.battleChooseMode)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: Nearby section
    private var nearbySection: some View {
        VStack(spacing: 0) {
            nearbyHeader
            Divider().background(Theme.surfaceStroke).padding(.horizontal, 16)
            Button(action: onNearbyHost) {
                lobbyRow(icon: "wifi.router.fill", tint: Theme.auroraMint,
                         title: L10n.battleCreateLocal,
                         sub: L10n.battleCreateLocalSub)
            }
            .buttonStyle(.plain)
            Divider().background(Theme.surfaceStroke)
            Button(action: onNearbyJoin) {
                lobbyRow(icon: "antenna.radiowaves.left.and.right", tint: Theme.auroraMint,
                         title: L10n.battleJoinLocal,
                         sub: L10n.battleJoinLocalSub)
            }
            .buttonStyle(.plain)
        }
        .background(
            LinearGradient(colors: [Theme.auroraMint.opacity(0.10), Theme.auroraCyan.opacity(0.05)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Theme.auroraMint.opacity(0.35), lineWidth: 1.5))
    }

    private var nearbyHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.horizontal.fill")
                .font(.system(size: 11, weight: .black)).foregroundStyle(Theme.auroraMint)
            Text(L10n.battleNearbyHeader)
                .font(.system(size: 9, weight: .black, design: .rounded)).tracking(1.5)
                .foregroundStyle(Theme.auroraMint)
            Spacer()
            Text(L10n.battleNearbyNoInternet)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.auroraMint.opacity(0.7))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Theme.auroraMint.opacity(0.15), in: Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: Online section
    private var onlineSection: some View {
        VStack(spacing: 0) {
            onlineHeader
            Divider().background(Theme.surfaceStroke).padding(.horizontal, 16)
            Button(action: onPrivate) {
                lobbyRow(icon: "key.fill", tint: Theme.starGold,
                         title: L10n.battlePrivate, sub: L10n.battlePrivateSub)
            }
            .buttonStyle(.plain)
            Divider().background(Theme.surfaceStroke)
            Button(action: onJoinCode) {
                lobbyRow(icon: "qrcode", tint: Theme.auroraCyan,
                         title: L10n.battleJoinCode, sub: L10n.battleJoinCodeSub)
            }
            .buttonStyle(.plain)
            Divider().background(Theme.surfaceStroke)
            Button(action: onRandom) {
                lobbyRow(icon: "shuffle", tint: Theme.nebulaPurple,
                         title: L10n.battleRandom, sub: L10n.battleRandomSub)
            }
            .buttonStyle(.plain)
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Theme.surfaceStroke, lineWidth: 1))
    }

    private var onlineHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 11, weight: .black)).foregroundStyle(Theme.textTertiary)
            Text(L10n.battleOnlineHeader)
                .font(.system(size: 9, weight: .black, design: .rounded)).tracking(1.5)
                .foregroundStyle(Theme.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
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
                        Text(L10n.battleRematch)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(L10n.battleRematchTo) \(lastOpponent)")
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
                    rivalStat(value: r.myWins,    label: L10n.battleWins,   tint: Theme.auroraMint)
                    rivalStat(value: r.draws,     label: L10n.battleDraws,  tint: Theme.starGold)
                    rivalStat(value: r.theirWins, label: L10n.battleLosses, tint: Theme.nebulaPink)
                }
                .padding(.vertical, 10)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1))
            }
        }
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
            Text(L10n.battleRoomCreated)
                .font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(Theme.textPrimary)
            Text(roomCode != nil ? L10n.battleShareCode : L10n.battleWaitingOpponent)
                .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(Theme.textSecondary)
        }
    }

    private func codeCard(code: String) -> some View {
        VStack(spacing: 8) {
            Text(L10n.battleRoomCode)
                .font(.system(size: 10, weight: .black, design: .rounded)).tracking(2)
                .foregroundStyle(Theme.textTertiary)
            Text(code)
                .font(.system(size: 36, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.starGold)
                .tracking(8)
            Text(L10n.battleShareCodeHint)
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
            Text(L10n.battleCancel)
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

// MARK: - Nearby Hosting (advertising)

private struct NearbyHostingView: View {
    let onCancel: () -> Void
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 36) {
            Spacer()
            pulseIcon
            VStack(spacing: 10) {
                Text(L10n.battleLocalCreated)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(L10n.battleLocalWaiting)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            statusBadge
            Spacer()
            cancelButton
        }
        .onAppear { startPulse() }
    }

    private var pulseIcon: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Theme.auroraMint.opacity(pulse ? 0 : 0.4 - Double(i) * 0.1), lineWidth: 1.5)
                    .frame(width: CGFloat(90 + i * 36), height: CGFloat(90 + i * 36))
                    .scaleEffect(pulse ? 1.3 + Double(i) * 0.15 : 1.0)
                    .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)
                               .delay(Double(i) * 0.4), value: pulse)
            }
            ZStack {
                Circle().fill(Theme.auroraMint.opacity(0.18)).frame(width: 90, height: 90)
                Image(systemName: "wifi.router.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Theme.auroraMint)
            }
        }
        .frame(width: 180, height: 180)
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.auroraMint).frame(width: 8, height: 8)
                .opacity(pulse ? 1 : 0.4)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: pulse)
            Text(L10n.battleBTBadge)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.auroraMint)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Theme.auroraMint.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(Theme.auroraMint.opacity(0.3), lineWidth: 1))
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Text(L10n.battleCancel)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1))
        }
        .padding(.horizontal, 32).padding(.bottom, 48)
    }

    private func startPulse() {
        pulse = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { pulse = true }
    }
}

// MARK: - Nearby Browsing (peer discovery)

private struct NearbyBrowsingView: View {
    let peers: [MCPeerID]
    let onConnect: (MCPeerID) -> Void
    let onCancel: () -> Void
    @State private var scanning = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)
            header
            Spacer().frame(height: 28)
            if peers.isEmpty {
                emptyState
            } else {
                peerList
            }
            Spacer()
            cancelButton
        }
        .onAppear { scanning = true }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.auroraMint.opacity(0.15)).frame(width: 72, height: 72)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 28, weight: .bold)).foregroundStyle(Theme.auroraMint)
            }
            Text(L10n.battleSearchingHosts)
                .font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(Theme.textPrimary)
            Text(L10n.battleSearchingHint)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                ProgressView().tint(Theme.auroraMint).scaleEffect(0.9)
                Text(L10n.battleScanning)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 32)
        }
    }

    private var peerList: some View {
        VStack(spacing: 0) {
            ForEach(peers, id: \.self) { peer in
                Button { onConnect(peer) } label: {
                    peerRow(peer)
                }
                .buttonStyle(.plain)
                if peer != peers.last {
                    Divider().background(Theme.surfaceStroke).padding(.horizontal, 16)
                }
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Theme.auroraMint.opacity(0.3), lineWidth: 1.5))
        .padding(.horizontal, 24)
    }

    private func peerRow(_ peer: MCPeerID) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.auroraMint.opacity(0.18)).frame(width: 44, height: 44)
                Image(systemName: "person.fill")
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.auroraMint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(peer.displayName)
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.textPrimary)
                Text(L10n.battleTapToJoin)
                    .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "wifi")
                .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.auroraMint)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textTertiary)
        }
        .padding(16)
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Text(L10n.battleCancel)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1))
        }
        .padding(.horizontal, 32).padding(.bottom, 48)
    }
}

// MARK: - Nearby Battle Game

private struct NearbyBattleGameView: View {
    let seed: Int
    let pilotName: String
    let coord: BattleCoordinator

    @EnvironmentObject private var store: GameStore
    @StateObject private var gameCoord = GameCoordinator()
    @State private var sceneID = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Theme.cosmicBackground.ignoresSafeArea()
                if gameCoord.isReady {
                    SpriteView(scene: gameCoord.scene!, options: [.allowsTransparency])
                        .ignoresSafeArea()
                        .id(sceneID)
                }
                nearbyBattleHUD
                    .padding(.top, 56).padding(.horizontal, 20)
                opponentLivePanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 16).padding(.bottom, 56)
            }
            .onAppear {
                if !gameCoord.isReady {
                    gameCoord.setup(screenSize: geo.size, store: store, mode: .battle)
                    gameCoord.scene?.battleSeed = seed
                }
            }
        }
        .onChange(of: gameCoord.score) { _, newScore in
            coord.broadcastLiveScore(newScore, skinID: store.activeSkinID)
        }
        .onChange(of: gameCoord.gameOverInfo) { _, info in
            guard let info else { return }
            Task { @MainActor in coord.submitNearbyScore(info.score) }
        }
        .navigationBarHidden(true)
    }

    private var nearbyBattleHUD: some View {
        HStack(alignment: .center, spacing: 0) {
            myScorePill
            Spacer()
            ZStack {
                VStack(spacing: 2) {
                    Image(systemName: "wifi").font(.system(size: 11, weight: .black))
                        .foregroundStyle(Theme.auroraMint)
                    Text("LOCAL").font(.system(size: 9, weight: .black, design: .rounded)).tracking(1.5)
                        .foregroundStyle(Theme.auroraMint)
                }
            }
            Spacer()
            opponentTopScore
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var myScorePill: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("YOU")
                .font(.system(size: 8, weight: .black, design: .rounded)).tracking(1.5)
                .foregroundStyle(Theme.auroraCyan)
            Text("\(gameCoord.score)")
                .font(.system(size: 28, weight: .black, design: .rounded)).monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
                .animation(.bouncy, value: gameCoord.score)
        }
        .frame(minWidth: 64, alignment: .leading)
    }

    private var opponentTopScore: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(coord.opponentName.isEmpty ? "OPP" : String(coord.opponentName.prefix(6)).uppercased())
                .font(.system(size: 8, weight: .black, design: .rounded)).tracking(1.5)
                .foregroundStyle(Theme.nebulaPink)
            Group {
                if coord.opponentName.isEmpty {
                    Text("···").font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    Text("\(coord.opponentLiveScore)")
                        .font(.system(size: 28, weight: .black, design: .rounded)).monospacedDigit()
                        .foregroundStyle(coord.opponentScoreJustUpdated ? Theme.nebulaPink : Theme.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.bouncy, value: coord.opponentLiveScore)
                }
            }
        }
        .frame(minWidth: 64, alignment: .trailing)
    }

    private var opponentLivePanel: some View {
        Group {
            if !coord.opponentName.isEmpty {
                OpponentLivePanelView(
                    name: coord.opponentName,
                    score: coord.opponentLiveScore,
                    skinID: coord.opponentLiveSkinID,
                    justUpdated: coord.opponentScoreJustUpdated
                )
                .transition(.scale(scale: 0.7, anchor: .bottomTrailing).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: coord.opponentName.isEmpty)
            }
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
                // Floating opponent panel — bottom right, non-intrusive
                opponentLivePanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 16).padding(.bottom, 56)
            }
            .onAppear {
                if !gameCoord.isReady {
                    gameCoord.setup(screenSize: geo.size, store: store, mode: .battle)
                    gameCoord.scene?.battleSeed = room.seed
                }
                coord.connectRealtime(skinID: store.activeSkinID)
            }
        }
        .onChange(of: gameCoord.score) { _, newScore in
            coord.broadcastLiveScore(newScore, skinID: store.activeSkinID)
        }
        .onChange(of: gameCoord.gameOverInfo) { _, info in
            guard let info else { return }
            Task { @MainActor in
                coord.submitMyScore(info.score)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: Top HUD
    private var battleHUD: some View {
        HStack(alignment: .center, spacing: 0) {
            myScorePill
            Spacer()
            battleBadge
            Spacer()
            opponentTopScore
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var myScorePill: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("YOU")
                .font(.system(size: 8, weight: .black, design: .rounded)).tracking(1.5)
                .foregroundStyle(Theme.auroraCyan)
            Text("\(gameCoord.score)")
                .font(.system(size: 28, weight: .black, design: .rounded)).monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
                .animation(.bouncy, value: gameCoord.score)
        }
        .frame(minWidth: 64, alignment: .leading)
    }

    private var battleBadge: some View {
        VStack(spacing: 2) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .black)).foregroundStyle(Theme.nebulaPink)
            Text("VS").font(.system(size: 10, weight: .black, design: .rounded)).tracking(2)
                .foregroundStyle(Theme.nebulaPink)
        }
    }

    private var opponentTopScore: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(coord.opponentName.isEmpty ? "OPP" : String(coord.opponentName.prefix(6)).uppercased())
                .font(.system(size: 8, weight: .black, design: .rounded)).tracking(1.5)
                .foregroundStyle(Theme.nebulaPink)
            Group {
                if coord.opponentName.isEmpty {
                    Text("···")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    Text("\(coord.opponentLiveScore)")
                        .font(.system(size: 28, weight: .black, design: .rounded)).monospacedDigit()
                        .foregroundStyle(coord.opponentScoreJustUpdated ? Theme.nebulaPink : Theme.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.bouncy, value: coord.opponentLiveScore)
                }
            }
        }
        .frame(minWidth: 64, alignment: .trailing)
    }

    // MARK: Floating opponent mini-panel
    private var opponentLivePanel: some View {
        Group {
            if !coord.opponentName.isEmpty {
                OpponentLivePanelView(
                    name: coord.opponentName,
                    score: coord.opponentLiveScore,
                    skinID: coord.opponentLiveSkinID,
                    justUpdated: coord.opponentScoreJustUpdated
                )
                .transition(.scale(scale: 0.7, anchor: .bottomTrailing).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: coord.opponentName.isEmpty)
            }
        }
    }
}

// MARK: - Opponent Live Panel

private struct OpponentLivePanelView: View {
    let name: String
    let score: Int
    let skinID: String
    let justUpdated: Bool

    private var skin: AstronautSkin { SkinCatalog.skin(id: skinID) }

    var body: some View {
        VStack(spacing: 0) {
            // Avatar
            MiniAstronautView(skin: skin, size: 72)
                .overlay(
                    Circle()
                        .stroke(justUpdated ? Theme.nebulaPink : Color.clear, lineWidth: 2)
                        .scaleEffect(justUpdated ? 1.15 : 1.0)
                        .animation(.easeOut(duration: 0.4), value: justUpdated)
                )
                .padding(.top, 10)

            // Name tag
            Text(name.prefix(10))
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .padding(.top, 4)

            // Score
            Text("\(score)")
                .font(.system(size: 22, weight: .black, design: .rounded)).monospacedDigit()
                .foregroundStyle(justUpdated ? Theme.nebulaPink : Theme.textPrimary)
                .contentTransition(.numericText())
                .animation(.bouncy, value: score)
                .padding(.bottom, 10)
        }
        .frame(width: 88)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(justUpdated ? Theme.nebulaPink.opacity(0.6) : Theme.surfaceStroke, lineWidth: 1.5)
                .animation(.easeOut(duration: 0.4), value: justUpdated)
        )
        .shadow(color: Theme.nebulaPink.opacity(justUpdated ? 0.35 : 0.1), radius: 12, y: 4)
    }
}

// MARK: - Mini Astronaut (skin-aware, no float animation)

struct MiniAstronautView: View {
    let skin: AstronautSkin
    let size: CGFloat

    var body: some View {
        ZStack {
            // Subtle glow behind
            Circle()
                .fill(skin.visorColor.opacity(0.3))
                .frame(width: size * 1.1, height: size * 1.1)
                .blur(radius: 8)

            // Helmet
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [skin.suitColor, skin.accentColor],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: size, height: size)

                // Visor
                Ellipse()
                    .fill(LinearGradient(
                        colors: [skin.visorColor.opacity(0.9), skin.visorColor.opacity(0.6)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: size * 0.6, height: size * 0.52)
                    .offset(y: -size * 0.04)

                // Visor highlight
                Capsule()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: size * 0.14, height: size * 0.07)
                    .offset(x: -size * 0.14, y: -size * 0.18)

                // Antenna
                Capsule()
                    .fill(skin.suitColor)
                    .frame(width: size * 0.05, height: size * 0.18)
                    .offset(y: -size * 0.54)
                Circle()
                    .fill(Theme.starGold)
                    .frame(width: size * 0.1, height: size * 0.1)
                    .offset(y: -size * 0.64)
                    .shadow(color: Theme.starGold, radius: 4)

                // Chest panel
                RoundedRectangle(cornerRadius: 3)
                    .fill(skin.accentColor.opacity(0.9))
                    .frame(width: size * 0.18, height: size * 0.1)
                    .offset(y: size * 0.14)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Waiting for Result

private struct BattleWaitingResultView: View {
    let myScore: Int
    let opponentName: String
    let opponentLastScore: Int
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
                Text("\(L10n.battleYourScore) \(myScore)")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.auroraCyan)
                if !opponentName.isEmpty {
                    Text("\(opponentName): \(opponentLastScore)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.nebulaPink)
                }
                Text(L10n.battleWaitingResult + dots)
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
    let mySkinID: String
    let opponentSkinID: String
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
            Text(isDraw ? L10n.battleDraw : didWin ? L10n.battleWon : L10n.battleLost)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(isDraw ? Theme.starGold : didWin ? Theme.auroraMint : Theme.nebulaPink)
            Text(isDraw ? L10n.battleDrawSub :
                 didWin ? "\(L10n.battleWonSub), \(pilotName)!" :
                 "\(result.opponentName) \(L10n.battleLostSub)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
    }

    private var scoreComparison: some View {
        HStack(spacing: 0) {
            scoreColumn(name: pilotName, score: result.myScore,
                        skinID: mySkinID, isWinner: didWin || isDraw, isMe: true)
            Image(systemName: "bolt.fill")
                .font(.system(size: 20, weight: .black)).foregroundStyle(Theme.nebulaPink)
                .frame(width: 44)
            scoreColumn(name: result.opponentName, score: result.opponentScore,
                        skinID: opponentSkinID, isWinner: !didWin || isDraw, isMe: false)
        }
        .padding(.horizontal, 24)
    }

    private func rivalryCard(_ r: RivalryStats) -> some View {
        VStack(spacing: 10) {
            Text(L10n.battleHeadToHead)
                .font(.system(size: 10, weight: .black, design: .rounded)).tracking(2)
                .foregroundStyle(Theme.textTertiary)
            HStack(spacing: 0) {
                rivalStat(value: r.myWins,    label: L10n.battleWins,   tint: Theme.auroraMint)
                rivalStat(value: r.draws,     label: L10n.battleDraws,  tint: Theme.starGold)
                rivalStat(value: r.theirWins, label: L10n.battleLosses, tint: Theme.nebulaPink)
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
                    Text("\(L10n.battleRematch) \(L10n.battleRematchTo) \(result.opponentName)")
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
                    Text(L10n.battleNewRival)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1))
            }
            Button(action: onHome) {
                Text(L10n.battleBackHome)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 46)
            }
        }
    }

    private func scoreColumn(name: String, score: Int, skinID: String, isWinner: Bool, isMe: Bool) -> some View {
        let skin = SkinCatalog.skin(id: skinID)
        return VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                MiniAstronautView(skin: skin, size: 64)
                if isWinner && !isDraw {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.starGold)
                        .offset(x: 6, y: -6)
                }
            }
            Text(name).font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isMe ? Theme.auroraCyan : Theme.textSecondary).lineLimit(1)
            Text("\(score)").font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(isWinner ? Theme.textPrimary : Theme.textTertiary).monospacedDigit()
            if isWinner && !isDraw {
                Text(L10n.battleWinner)
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
                    Text(L10n.battleChallengeReceived)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(from) \(L10n.battleIsChallengingYou)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.nebulaPink)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: onAccept) {
                        Text(L10n.battleAccept)
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
                Text(L10n.battleJoinPrivate)
                    .font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(Theme.textPrimary)
                Text(L10n.battleEnterCode)
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
                    Text(L10n.battleJoinRoom)
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
                    Text(L10n.battleCancel)
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
                Text(L10n.battleConnectionIssue)
                    .font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            }
            Spacer()
            VStack(spacing: 12) {
                Button(action: onRetry) {
                    Text(L10n.battleTryAgain)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.18))
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Theme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                Button(action: onHome) {
                    Text(L10n.battleBackHome)
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
                Text(L10n.battleRequiresInternet)
                    .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Theme.textPrimary)
                Text(L10n.battleGoOnline)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            }
            Spacer()
            Button(action: onHome) {
                Text(L10n.battleBack)
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
