import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var lang: LanguageManager

    let onPlay: () -> Void
    let onDailyBurst: () -> Void
    let onLeaderboard: () -> Void
    let onHowToPlay: () -> Void
    let onSettings: () -> Void
    let onShop: () -> Void

    @State private var pulse = false

    var body: some View {
        ZStack {
            CosmicBackground()
            content
        }
        .navigationBarHidden(true)
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                topBar
                heroSection
                statsRow
                playButton
                secondaryRow
                leaderboardCard
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.welcomeBack)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Text(store.pilotName)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            // Shield badge (only shown when player has shields)
            if store.shieldCount > 0 {
                Button(action: onShop) {
                    HStack(spacing: 5) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.auroraCyan)
                        Text("\(store.shieldCount)")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.auroraCyan)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Theme.auroraCyan.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(Theme.auroraCyan.opacity(0.3), lineWidth: 1))
                }
                .padding(.trailing, 8)
            }
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(Theme.surface, in: Circle())
                    .overlay(Circle().stroke(Theme.surfaceStroke, lineWidth: 1))
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 6) {
            Text("ECLIPSE RUNNER")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .tracking(6)
                .foregroundStyle(Theme.auroraCyan)

            ZStack {
                // Show the active skin astronaut
                SkinAstronautPreview(skin: store.activeSkin, size: 200)
                    .frame(height: 260)

                // Score badge top-right
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L10n.bestLabel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(Theme.textTertiary)
                    Text("\(store.bestScore)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.starGold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.surfaceStroke, lineWidth: 1)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 8)

                // Skin badge bottom-center
                Button(action: onShop) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(store.activeSkin.visorColor)
                            .frame(width: 10, height: 10)
                        Text(store.activeSkin.name)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 8)

                // Shield indicator bottom-right (only if shields, complementary to top bar)
                if store.shieldCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkmark.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.auroraCyan)
                        Text("Shield ready")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.auroraCyan)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Theme.auroraCyan.opacity(0.35), lineWidth: 1))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.bottom, 8)
                }
            }

            Text(L10n.tagline)
                .multilineTextAlignment(.center)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 4)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatPill(icon: "flame.fill",  tint: Theme.nebulaPink,
                     title: L10n.statRuns,     value: "\(store.totalRuns)",
                     tooltip: L10n.tooltipRuns)
            StatPill(icon: "sparkles",    tint: Theme.auroraCyan,
                     title: L10n.statLightYrs, value: "\(store.totalDistance)",
                     tooltip: L10n.tooltipLightYrs)
            StatPill(icon: "trophy.fill", tint: Theme.starGold,
                     title: L10n.statBest,     value: "\(store.bestScore)",
                     tooltip: L10n.tooltipBest)
        }
    }

    // MARK: - Play

    private var playButton: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .black))
                Text(L10n.launch)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .tracking(3)
            }
            .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.18))
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                ZStack {
                    Theme.primaryGradient
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), .clear],
                        startPoint: .top, endPoint: .center
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Theme.auroraCyan.opacity(pulse ? 0.65 : 0.35), radius: pulse ? 28 : 18, y: 10)
        }
        .scaleEffect(pulse ? 1.015 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - Leaderboard

    private var leaderboardCard: some View {
        Button(action: onLeaderboard) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(L10n.galacticLB, systemImage: "star.circle.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                }

                VStack(spacing: 8) {
                    ForEach(store.leaderboard.prefix(3)) { entry in
                        LeaderboardRow(entry: entry, compact: true)
                    }
                }
            }
            .padding(18)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Secondary

    private var secondaryRow: some View {
        HStack(alignment: .top, spacing: 12) {
            SecondaryTile(icon: "questionmark.circle.fill",
                          title: L10n.howToPlay,
                          subtitle: L10n.oneTapControls,
                          tint: Theme.auroraMint,
                          action: onHowToPlay)
            DailyBurstTile(action: onDailyBurst)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Subviews

private struct StatPill: View {
    @EnvironmentObject private var lang: LanguageManager
    let icon: String
    let tint: Color
    let title: String
    let value: String
    let tooltip: String

    @State private var showTooltip = false

    var body: some View {
        let bg = showTooltip ? tint.opacity(0.13) : Theme.surface
        let border = showTooltip ? tint.opacity(0.45) : Theme.surfaceStroke

        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                Image(systemName: showTooltip ? "chevron.up.circle" : "info.circle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(tint.opacity(0.8))
            }
            if showTooltip {
                Text(tooltip)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.textPrimary.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(bg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: showTooltip)
        .onTapGesture { showTooltip.toggle() }
    }
}

private struct DailyBurstTile: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var lang: LanguageManager
    let action: () -> Void

    private var subtitle: String {
        if store.dailyExhausted { return L10n.dailyNoAttemptsLeft }
        if store.dailyCompleted { return store.lastDailyRank.map { "#\($0) · 1 \(L10n.dailyAttemptsLeft)" } ?? "1 \(L10n.dailyAttemptsLeft)" }
        return L10n.dailyBurstSubtitleShort
    }

    private var subtitleColor: Color {
        if store.dailyExhausted { return Theme.textTertiary }
        if store.dailyCompleted { return Theme.starGold }
        return Theme.textSecondary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.starGold)
                        .frame(width: 38, height: 38)
                        .background(Theme.starGold.opacity(0.15), in: Circle())
                    if store.dailyExhausted {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                            .offset(x: 4, y: -4)
                    } else if store.dailyCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.auroraMint)
                            .offset(x: 4, y: -4)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.dailyBurst)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                store.dailyCompleted ? Theme.starGold.opacity(0.08) : Theme.surface,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(store.dailyCompleted ? Theme.starGold.opacity(0.35) : Theme.surfaceStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SecondaryTile: View {
    @EnvironmentObject private var lang: LanguageManager
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.18))
                Text("\(entry.rank)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(rankColor)
            }
            .frame(width: 28, height: 28)

            Text(entry.name)
                .font(.system(size: 14, weight: entry.isYou ? .bold : .medium, design: .rounded))
                .foregroundStyle(entry.isYou ? Theme.auroraCyan : Theme.textPrimary)
            if entry.isYou {
                Text("YOU")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Theme.spaceTop)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.auroraCyan, in: Capsule())
            }
            Spacer()
            Text("\(entry.score)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
        .padding(.vertical, compact ? 4 : 8)
    }

    private var rankColor: Color {
        switch entry.rank {
        case 1: return Theme.starGold
        case 2: return Theme.auroraCyan
        case 3: return Theme.nebulaPink
        default: return Theme.textSecondary
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(onPlay: {}, onDailyBurst: {}, onLeaderboard: {}, onHowToPlay: {}, onSettings: {}, onShop: {})
            .environmentObject(GameStore())
            .environmentObject(LanguageManager.shared)
    }
}
