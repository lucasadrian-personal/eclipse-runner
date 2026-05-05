import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: GameStore
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(onPlay: { path.append(Route.play) },
                     onLeaderboard: { path.append(Route.leaderboard) },
                     onHowToPlay: { path.append(Route.howToPlay) },
                     onSettings: { path.append(Route.settings) })
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .play: PlayPlaceholderView()
                case .leaderboard: LeaderboardPlaceholderView()
                case .howToPlay: HowToPlayPlaceholderView()
                case .settings: SettingsPlaceholderView()
                }
            }
        }
        .tint(Theme.auroraCyan)
    }
}

enum Route: Hashable {
    case play, leaderboard, howToPlay, settings
}
