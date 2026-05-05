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

                Text("COMING SOON")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(tint.opacity(0.15), in: Capsule())
                    .padding(.top, 4)
            }
            .padding(24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - Specific placeholders

struct LeaderboardPlaceholderView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        ZStack {
            CosmicBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Galactic Leaderboard")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 8)

                    Text("Top pilots across the galaxy")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)

                    VStack(spacing: 4) {
                        ForEach(store.leaderboard) { entry in
                            LeaderboardRow(entry: entry)
                            if entry.id != store.leaderboard.last?.id {
                                Divider().background(Theme.surfaceStroke)
                            }
                        }
                    }
                    .padding(16)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Theme.surfaceStroke, lineWidth: 1)
                    )
                    .padding(.top, 8)
                }
                .padding(20)
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct HowToPlayPlaceholderView: View {
    var body: some View {
        ZStack {
            CosmicBackground()
            VStack(alignment: .leading, spacing: 18) {
                Text("How to Play")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 8)

                tipCard(icon: "hand.tap.fill", tint: Theme.auroraCyan,
                        title: "Tap to fly",
                        body: "Each tap gives a gentle thrust upward. Release to drift down with gravity.")
                tipCard(icon: "arrow.left.and.right", tint: Theme.nebulaPink,
                        title: "Mind the gap",
                        body: "Slip through asteroid gates. Touching anything ends the run.")
                tipCard(icon: "wind", tint: Theme.auroraMint,
                        title: "Solar gusts",
                        body: "Cosmic winds will nudge you up or down. Adjust on the fly.")
                tipCard(icon: "flame.fill", tint: Theme.starGold,
                        title: "Speed climbs",
                        body: "Every 10 points cranks the difficulty. Stay sharp.")

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

struct SettingsPlaceholderView: View {
    var body: some View {
        ComingSoonScreen(
            title: "Mission Settings",
            subtitle: "Sounds, haptics, pilot name and visual options will live here.",
            icon: "gearshape.fill",
            tint: Theme.nebulaPurple
        )
    }
}
