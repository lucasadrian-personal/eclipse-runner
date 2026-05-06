import SwiftUI

// MARK: - Shared empty-state container
struct ComingSoonScreen: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        ZStack {
            CosmicBackground()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .frame(width: 120, height: 120)
                    Image(systemName: icon)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - Live Leaderboard View
struct LeaderboardPlaceholderView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var lang: LanguageManager
    @State private var isRefreshing = false

    var body: some View {
        ZStack {
            CosmicBackground()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    podium
                    restOfBoard
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .refreshable {
                store.refreshLeaderboard()
                try? await Task.sleep(nanoseconds: 800_000_000)
            }

            if store.leaderboardLoading && store.leaderboard == LeaderboardEntry.sample {
                loadingOverlay
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                statusBadge
            }
        }
        .onAppear { store.refreshLeaderboard() }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 4) {
            Text(L10n.galacticLB)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(store.isOnline ? L10n.liveGlobal : L10n.cachedRankings)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(store.isOnline ? Theme.auroraMint : Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Top 3 podium
    @ViewBuilder
    private var podium: some View {
        if store.leaderboard.count >= 3 {
            HStack(alignment: .bottom, spacing: 10) {
                PodiumCard(entry: store.leaderboard[1], height: 100)
                PodiumCard(entry: store.leaderboard[0], height: 128)
                PodiumCard(entry: store.leaderboard[2], height: 82)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Ranks 4+
    @ViewBuilder
    private var restOfBoard: some View {
        let rest = store.leaderboard.dropFirst(3)
        if !rest.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rest)) { entry in
                    LeaderboardRow(entry: entry)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 2)
                    if entry.id != rest.last?.id {
                        Divider()
                            .background(Theme.surfaceStroke)
                            .padding(.horizontal, 14)
                    }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(store.isOnline ? Theme.auroraMint : Theme.textTertiary)
                .frame(width: 7, height: 7)
            Text(store.isOnline ? L10n.liveLabel : L10n.cachedLabel)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundStyle(store.isOnline ? Theme.auroraMint : Theme.textTertiary)
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Theme.auroraCyan)
                .scaleEffect(1.3)
            Text(L10n.scanningGalaxy)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Podium card
private struct PodiumCard: View {
    let entry: LeaderboardEntry
    let height: CGFloat

    private var medalColor: Color {
        switch entry.rank {
        case 1: return Theme.starGold
        case 2: return Theme.auroraCyan
        default: return Theme.nebulaPink
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(rankEmoji)
                .font(.system(size: 22))
            Text(entry.name)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(entry.isYou ? Theme.auroraCyan : Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(entry.score)")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(medalColor)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            ZStack {
                Theme.surface
                medalColor.opacity(0.07)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(medalColor.opacity(entry.rank == 1 ? 0.55 : 0.22), lineWidth: 1.5)
        )
        .shadow(color: entry.rank == 1 ? medalColor.opacity(0.3) : .clear, radius: 12, y: 6)
    }

    private var rankEmoji: String {
        switch entry.rank {
        case 1: return "🥇"
        case 2: return "🥈"
        default: return "🥉"
        }
    }
}

// MARK: - How to Play
struct HowToPlayPlaceholderView: View {
    @EnvironmentObject private var lang: LanguageManager
    var body: some View {
        ZStack {
            CosmicBackground()
            VStack(alignment: .leading, spacing: 18) {
                Text(L10n.htpTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 8)

                tipCard(icon: "hand.tap.fill", tint: Theme.auroraCyan,
                        title: L10n.htpTap,   body: L10n.htpTapBody)
                tipCard(icon: "arrow.left.and.right", tint: Theme.nebulaPink,
                        title: L10n.htpGap,   body: L10n.htpGapBody)
                tipCard(icon: "wind", tint: Theme.auroraMint,
                        title: L10n.htpWind,  body: L10n.htpWindBody)
                tipCard(icon: "flame.fill", tint: Theme.starGold,
                        title: L10n.htpSpeed, body: L10n.htpSpeedBody)
                tipCard(icon: "bolt.circle.fill", tint: Theme.starGold,
                        title: L10n.htpDailyBurst, body: L10n.htpDailyBurstBody)
                Spacer()
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func tipCard(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(body)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.surfaceStroke, lineWidth: 1)
        )
    }
}

// MARK: - Settings
struct SettingsPlaceholderView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var lang: LanguageManager
    @State private var nameInput: String = ""
    @State private var showSaved = false
    @FocusState private var nameFocused: Bool

    @State private var soundOn: Bool = !AudioManager.shared.isMuted
    @State private var hapticsOn: Bool = !HapticsManager.shared.isDisabled

    var body: some View {
        ZStack {
            CosmicBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(L10n.missionSettings)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 8)

                    pilotSection
                    languageSection
                    audioSection
                    statsSection
                    aboutSection
                    Spacer(minLength: 40)
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { nameInput = store.pilotName }
    }

    // MARK: Language
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(L10n.language, icon: "globe")
            HStack(spacing: 10) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    let isSelected = lang.current == language
                    Button {
                        lang.current = language
                    } label: {
                        HStack(spacing: 8) {
                            Text(language.flag)
                                .font(.system(size: 20))
                            Text(language.displayName)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(isSelected ? Color(red: 0.04, green: 0.06, blue: 0.18) : Theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            isSelected ? AnyShapeStyle(Theme.primaryGradient) : AnyShapeStyle(Theme.surface),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? Theme.auroraCyan.opacity(0.5) : Theme.surfaceStroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3), value: lang.current)
                }
            }
        }
    }

    // MARK: Pilot name
    private var pilotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(L10n.pilotIdentity, icon: "person.fill")

            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.auroraCyan)
                        .frame(width: 36, height: 36)
                        .background(Theme.auroraCyan.opacity(0.15), in: Circle())

                    TextField(L10n.pilotNamePH, text: $nameInput)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.auroraCyan)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { saveName() }

                    if showSaved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.auroraMint)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(nameFocused ? Theme.auroraCyan.opacity(0.55) : Theme.surfaceStroke,
                                lineWidth: 1)
                )

                Button(action: saveName) {
                    Text(L10n.savePilotName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.18))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Theme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            Text(L10n.pilotNameHint)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func saveName() {
        store.savePilotName(nameInput)
        nameFocused = false
        withAnimation(.spring()) { showSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showSaved = false }
        }
    }

    // MARK: Sound & Haptics
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(L10n.soundHaptics, icon: "speaker.wave.2.fill")
            VStack(spacing: 0) {
                toggleRow(
                    icon: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    tint: Theme.auroraCyan,
                    label: L10n.soundEffects,
                    sublabel: soundOn ? L10n.soundOn : L10n.soundOff,
                    isOn: $soundOn
                ) {
                    AudioManager.shared.isMuted = !soundOn
                    if soundOn { AudioManager.shared.playScore() }
                }
                Divider().background(Theme.surfaceStroke).padding(.horizontal, 14)
                toggleRow(
                    icon: hapticsOn ? "iphone.radiowaves.left.and.right" : "iphone.slash",
                    tint: Theme.nebulaPink,
                    label: L10n.hapticFeedback,
                    sublabel: hapticsOn ? L10n.hapticOn : L10n.hapticOff,
                    isOn: $hapticsOn
                ) {
                    HapticsManager.shared.isDisabled = !hapticsOn
                    if hapticsOn { HapticsManager.shared.impactMedium() }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
        }
    }

    private func toggleRow(
        icon: String,
        tint: Color,
        label: String,
        sublabel: String,
        isOn: Binding<Bool>,
        onChange: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(sublabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(tint)
                .onChange(of: isOn.wrappedValue) { _, _ in onChange() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: Stats
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(L10n.yourStats, icon: "chart.bar.fill")
            HStack(spacing: 12) {
                statTile(L10n.bestScore, value: "\(store.bestScore)", tint: Theme.starGold)
                statTile(L10n.totalRuns,  value: "\(store.totalRuns)",  tint: Theme.auroraCyan)
                statTile(L10n.lightYrs,   value: "\(store.totalDistance)", tint: Theme.nebulaPink)
            }
        }
    }

    private func statTile(_ label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.surfaceStroke, lineWidth: 1)
        )
    }

    // MARK: About
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(L10n.about, icon: "info.circle")
            VStack(spacing: 0) {
                aboutRow(icon: "globe", label: L10n.leaderboard,
                         value: SupabaseConfig.current != nil ? L10n.online : L10n.offline)
                Divider().background(Theme.surfaceStroke).padding(.horizontal, 14)
                aboutRow(icon: "tag", label: L10n.version, value: "1.0")
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
        }
    }

    private func aboutRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.nebulaPurple)
                .frame(width: 28)
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(Theme.textTertiary)
    }
}
