import SwiftUI

@main
struct CosmicDriftApp: App {
    @StateObject private var gameStore = GameStore()

    init() {
        // Warm up audio engine on launch so first flap has no latency
        _ = AudioManager.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(gameStore)
                .preferredColorScheme(.dark)
        }
    }
}
