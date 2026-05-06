import SwiftUI

// MARK: - Daily Burst Entry Point
struct DailyBurstView: View {
    @EnvironmentObject private var store: GameStore
    let onPlay: () -> Void

    @State private var timeLeft: TimeInterval = 0
    @State private var timer: Timer? = nil

    var body: some View {
        ZStack {
            CosmicBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                    challengeCard
                    leaderboardSection
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(L10n.dailyBurst)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            timeLeft = DailyBurstService.shared.secondsUntilReset
            store.refreshDailyLeaderboard()
            startTimer()
        }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: Header
    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.starGold)
                Text(L10n.dailyBurst)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(L10n.dailyBurstSubtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            countdownBadge
        }
        .padding(.top, 8)
    }

    private var countdownBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.nebulaPink)
            Text(L10n.dailyResetsIn + " " + formattedTime)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Theme.nebulaPink.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(Theme.nebulaPink.opacity(0.3), lineWidth: 1))
    }

    // MARK: Challenge Card
    private var challengeCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                statBox(icon: "flame.fill", tint: Theme.nebulaPink,
                        label: L10n.statBest, value: "\(store.dailyBestScore)")
                statBox(icon: "trophy.fill", tint: Theme.starGold,
                        label: L10n.dailyRankLabel,
                        value: store.lastDailyRank.map { "#\($0)" } ?? "—")
            }
            attemptsIndicator
            playBurstButton
            if store.dailyCompleted {
                completedBadge
            }
        }
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(store.dailyCompleted
                        ? Theme.starGold.opacity(0.4) : Theme.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: store.dailyCompleted
                ? Theme.starGold.opacity(0.15) : .clear, radius: 20, y: 6)
    }

    private func statBox(icon: String, tint: Color, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var playBurstButton: some View {
        let exhausted = store.dailyExhausted
        let label: String = {
            if exhausted { return L10n.dailyNoAttemptsLeft }
            if store.dailyCompleted { return L10n.dailyPlayAgain }
            return L10n.dailyStartBurst
        }()
        let icon: String = {
            if exhausted { return "xmark.circle.fill" }
            if store.dailyCompleted { return "arrow.counterclockwise" }
            return "bolt.fill"
        }()
        return Button(action: { if !exhausted { onPlay() } }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .black))
                Text(label)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .tracking(2)
            }
            .foregroundStyle(exhausted
                ? Theme.textTertiary
                : Color(red: 0.04, green: 0.06, blue: 0.18))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    if exhausted {
                        Theme.surfaceStroke
                    } else {
                        LinearGradient(colors: [Theme.starGold, Theme.nebulaPink],
                                       startPoint: .leading, endPoint: .trailing)
                        LinearGradient(colors: [Color.white.opacity(0.3), .clear],
                                       startPoint: .top, endPoint: .center)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: exhausted ? .clear : Theme.starGold.opacity(0.5), radius: 16, y: 8)
        }
        .disabled(exhausted)
    }

    private var attemptsIndicator: some View {
        HStack(spacing: 10) {
            ForEach(0..<GameStore.dailyMaxAttempts, id: \.self) { i in
                Circle()
                    .fill(i < store.dailyAttempts ? Theme.textTertiary : Theme.starGold)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle().stroke(Theme.starGold.opacity(0.5), lineWidth: 1)
                    )
                    .animation(.spring(duration: 0.3), value: store.dailyAttempts)
            }
            Text(store.dailyExhausted
                 ? L10n.dailyNoAttemptsLeft
                 : "\(store.dailyAttemptsLeft) \(L10n.dailyAttemptsLeft)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(store.dailyExhausted ? Theme.nebulaPink : Theme.textSecondary)
        }
    }

    private var completedBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Theme.starGold)
            Text(L10n.dailyCompleted)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.starGold.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(Theme.starGold.opacity(0.3), lineWidth: 1))
    }

    // MARK: Leaderboard
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(L10n.dailyRankingTitle, systemImage: "bolt.circle.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if store.dailyLeaderboardLoading {
                    ProgressView().tint(Theme.starGold).scaleEffect(0.8)
                } else {
                    Text(L10n.dailyTodayOnly)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            if store.dailyLeaderboard.isEmpty {
                emptyState
            } else {
                dailyPodium
                dailyRestList
            }
        }
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.surfaceStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var dailyPodium: some View {
        if store.dailyLeaderboard.count >= 3 {
            HStack(alignment: .bottom, spacing: 8) {
                DailyPodiumCard(entry: store.dailyLeaderboard[1], height: 88)
                DailyPodiumCard(entry: store.dailyLeaderboard[0], height: 112)
                DailyPodiumCard(entry: store.dailyLeaderboard[2], height: 72)
            }
        } else if !store.dailyLeaderboard.isEmpty {
            ForEach(store.dailyLeaderboard) { entry in
                LeaderboardRow(entry: entry)
            }
        }
    }

    @ViewBuilder
    private var dailyRestList: some View {
        let rest = store.dailyLeaderboard.dropFirst(3)
        if !rest.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rest)) { entry in
                    LeaderboardRow(entry: entry)
                        .padding(.horizontal, 4)
                    if entry.id != rest.last?.id {
                        Divider().background(Theme.surfaceStroke)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.slash.circle")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
            Text(L10n.dailyNoEntries)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: Helpers
    private var formattedTime: String {
        let h = Int(timeLeft) / 3600
        let m = (Int(timeLeft) % 3600) / 60
        let s = Int(timeLeft) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            timeLeft = max(0, DailyBurstService.shared.secondsUntilReset)
        }
    }
}

// MARK: - Podium card for daily
private struct DailyPodiumCard: View {
    let entry: LeaderboardEntry
    let height: CGFloat

    private var medalColor: Color {
        switch entry.rank {
        case 1: return Theme.starGold
        case 2: return Theme.auroraCyan
        default: return Theme.nebulaPink
        }
    }
    private var rankEmoji: String {
        switch entry.rank { case 1: return "🥇"; case 2: return "🥈"; default: return "🥉" }
    }

    var body: some View {
        VStack(spacing: 5) {
            Text(rankEmoji).font(.system(size: 20))
            Text(entry.name)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(entry.isYou ? Theme.auroraCyan : Theme.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text("\(entry.score)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(medalColor)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(ZStack { Theme.surface; medalColor.opacity(0.08) })
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(medalColor.opacity(entry.rank == 1 ? 0.55 : 0.22), lineWidth: 1.5)
        )
        .shadow(color: entry.rank == 1 ? medalColor.opacity(0.28) : .clear, radius: 10, y: 5)
    }
}
