import SwiftUI
import SpriteKit

// MARK: - Scene coordinator
@MainActor
final class GameCoordinator: ObservableObject, CosmicGameSceneDelegate {
    @Published var score: Int = 0
    @Published var gameOverInfo: GameOverInfo? = nil
    @Published var gustUpward: Bool = true
    @Published var showGust: Bool = false

    private(set) var scene: CosmicGameScene?
    private(set) var isReady = false
    private weak var store: GameStore?
    var gameMode: GameMode = .normal

    func setup(screenSize: CGSize, store: GameStore, mode: GameMode = .normal) {
        self.store = store
        self.gameMode = mode
        let s = CosmicGameScene(size: screenSize)
        s.scaleMode   = .resizeFill
        s.anchorPoint = .zero
        s.gameDelegate = self
        s.activeSkin   = store.activeSkin
        self.scene = s
        self.isReady = true
    }

    func reset(store: GameStore) {
        guard let oldScene = scene else { return }
        self.store = store
        let s = CosmicGameScene(size: oldScene.size)
        s.scaleMode   = .resizeFill
        s.anchorPoint = .zero
        s.gameDelegate = self
        s.activeSkin   = store.activeSkin
        self.scene = s
        self.score = 0
        self.gameOverInfo = nil
        self.showGust = false
    }

    // CosmicGameSceneDelegate
    nonisolated func sceneDidScore(_ score: Int) {
        DispatchQueue.main.async { self.score = score }
    }

    nonisolated func sceneDidEnd(score: Int, best: Int, isNewBest: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.gameMode == .daily {
                self.store?.registerDailyRun(score: score)
            } else {
                self.store?.registerRun(score: score)
            }
            self.gameOverInfo = GameOverInfo(score: score, best: best, isNewBest: isNewBest)
        }
    }

    nonisolated func sceneDidShowGust(upward: Bool) {
        DispatchQueue.main.async {
            self.gustUpward = upward
            withAnimation(.easeInOut(duration: 0.3)) { self.showGust = true }
        }
    }
    nonisolated func sceneDidHideGust() {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.4)) { self.showGust = false }
        }
    }
}

struct GameOverInfo: Equatable {
    let score: Int
    let best: Int
    let isNewBest: Bool
}

// MARK: - Game mode
enum GameMode { case normal, daily }

// MARK: - Main GameView
struct GameView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    var mode: GameMode = .normal

    @StateObject private var coord: GameCoordinator = GameCoordinator()
    @State private var showGameOver = false
    @State private var shouldDismissOnClose = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.cosmicBackground.ignoresSafeArea()
                if coord.isReady {
                    gameLayer(size: geo.size)
                }
            }
            .onAppear {
                if !coord.isReady {
                    coord.setup(screenSize: geo.size, store: store, mode: mode)
                }
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea()
        .onChange(of: coord.gameOverInfo) { _, info in
            if info != nil { showGameOver = true }
        }
        .sheet(isPresented: $showGameOver, onDismiss: {
            if shouldDismissOnClose { dismiss() }
        }) {
            if let info = coord.gameOverInfo {
                GameOverSheet(info: info, onRetry: handleRetry, onHome: handleHome)
                    .environmentObject(store)
                    .environmentObject(lang)
            }
        }
    }

    private func gameLayer(size: CGSize) -> some View {
        ZStack(alignment: .top) {
            SpriteView(scene: coord.scene!, options: [.allowsTransparency])
                .ignoresSafeArea()
            VStack(spacing: 0) {
                topHUD
                    .padding(.top, 56)
                    .padding(.horizontal, 20)
                Spacer()
                if coord.showGust {
                    GustBanner(upward: coord.gustUpward)
                        .padding(.bottom, 80)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
    }

    // MARK: - Top HUD
    private var topHUD: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            Spacer()
            Text("\(coord.score)")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
                .shadow(color: Theme.auroraCyan.opacity(0.6), radius: 10)
                .contentTransition(.numericText())
                .animation(.bouncy, value: coord.score)
            Spacer()
            VStack(spacing: 1) {
                Text(L10n.bestLabel)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textTertiary)
                Text("\(store.bestScore)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.starGold)
            }
            .frame(width: 52)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Retry / Home
    private func handleRetry() {
        shouldDismissOnClose = false
        showGameOver = false
        store.lastRunRank = nil
        coord.reset(store: store)
    }

    private func handleHome() {
        shouldDismissOnClose = true
        showGameOver = false
    }
}

// MARK: - Gust Banner
private struct GustBanner: View {
    let upward: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: upward ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(upward ? Theme.auroraMint : Theme.nebulaPink)
            Text(L10n.solarGust)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Image(systemName: "wind")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
    }
}

// MARK: - Game Over Sheet
struct GameOverSheet: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var lang: LanguageManager
    let info: GameOverInfo
    let onRetry: () -> Void
    let onHome: () -> Void

    @State private var appear = false

    var body: some View {
        ZStack {
            Theme.cosmicBackground.ignoresSafeArea()
            StarfieldView(starCount: 50, showsNebula: true).ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()
                crashIcon
                titleArea
                scoreCards
                rankBadge
                Spacer()
                actionButtons
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 28)
        }
        .presentationDetents([.large])
        .presentationBackground(Color.clear)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                appear = true
            }
        }
    }

    // MARK: Subviews
    private var crashIcon: some View {
        ZStack {
            Circle()
                .fill(Theme.nebulaPink.opacity(0.18))
                .frame(width: 110, height: 110)
            Image(systemName: "bolt.fill")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(Theme.nebulaPink)
        }
        .scaleEffect(appear ? 1 : 0.4)
        .opacity(appear ? 1 : 0)
    }

    private var titleArea: some View {
        VStack(spacing: 6) {
            Text(info.isNewBest ? L10n.newRecord : L10n.missionOver)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(info.isNewBest ? Theme.starGold : Theme.textPrimary)
            Text(info.isNewBest ? L10n.newRecordSub : L10n.missionOverSub)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
    }

    private var scoreCards: some View {
        HStack(spacing: 14) {
            ScoreCard(label: L10n.scoreLabel, value: "\(info.score)", tint: Theme.auroraCyan)
            ScoreCard(label: L10n.bestLabel,  value: "\(store.bestScore)", tint: Theme.starGold)
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 30)
    }

    @ViewBuilder
    private var rankBadge: some View {
        if let rank = store.lastRunRank {
            HStack(spacing: 8) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.nebulaPurple)
                Text(L10n.globalRank)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Text("#\(rank)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.nebulaPurple)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Theme.nebulaPurple.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(Theme.nebulaPurple.opacity(0.30), lineWidth: 1))
            .opacity(appear ? 1 : 0)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        } else if SupabaseConfig.current != nil {
            HStack(spacing: 8) {
                ProgressView().tint(Theme.nebulaPurple).scaleEffect(0.8)
                Text(L10n.fetchingRank)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            .opacity(appear ? 1 : 0)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onRetry) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .black))
                    Text(L10n.tryAgain)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .tracking(1)
                }
                .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.18))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Theme.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.auroraCyan.opacity(0.45), radius: 16, y: 8)
            }
            Button(action: onHome) {
                Text(L10n.backToHome)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.surface,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.surfaceStroke, lineWidth: 1)
                    )
            }
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 40)
    }
}

private struct ScoreCard: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1.5)
        )
    }
}
