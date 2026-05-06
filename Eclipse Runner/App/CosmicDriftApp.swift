import SwiftUI

@main
struct CosmicDriftApp: App {
    @StateObject private var gameStore = GameStore()
    @StateObject private var langManager = LanguageManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        _ = AudioManager.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootView()
                } else {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                }
            }
            .environmentObject(gameStore)
            .environmentObject(langManager)
            .preferredColorScheme(.dark)
        }
    }
}
