import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: GameStore
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                onPlay:        { path.append(Route.play) },
                onDailyBurst:  { path.append(Route.dailyBurst) },
                onLeaderboard: { path.append(Route.leaderboard) },
                onHowToPlay:   { path.append(Route.howToPlay) },
                onSettings:    { path.append(Route.settings) },
                onShop:        { path.append(Route.shop) }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .play:
                    GameView(mode: .normal)
                case .dailyBurst:
                    DailyBurstView(onPlay: { path.append(Route.playDaily) })
                case .playDaily:
                    GameView(mode: .daily)
                case .leaderboard:
                    LeaderboardPlaceholderView()
                case .howToPlay:
                    HowToPlayPlaceholderView()
                case .settings:
                    SettingsPlaceholderView()
                case .shop:
                    ShopView()
                }
            }
        }
        .tint(Theme.auroraCyan)
    }
}

enum Route: Hashable {
    case play, dailyBurst, playDaily, leaderboard, howToPlay, settings, shop
}
