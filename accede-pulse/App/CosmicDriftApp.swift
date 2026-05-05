import SwiftUI

@main
struct CosmicDriftApp: App {
    @StateObject private var gameStore = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(gameStore)
                .preferredColorScheme(.dark)
        }
    }
}
