import SwiftUI

@main
struct CosmicDriftApp: App {
    @StateObject private var gameStore = GameStore()
    @StateObject private var langManager = LanguageManager.shared

    init() {
        _ = AudioManager.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(gameStore)
                .environmentObject(langManager)
                .preferredColorScheme(.dark)
        }
    }
}
