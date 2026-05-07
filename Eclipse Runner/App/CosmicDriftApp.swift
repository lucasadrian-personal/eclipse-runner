import SwiftUI

@main
struct CosmicDriftApp: App {
    @StateObject private var gameStore = GameStore()
    @StateObject private var langManager = LanguageManager.shared
    @StateObject private var iapManager = ShopIAPManager.shared
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
            .environmentObject(iapManager)
            .preferredColorScheme(.dark)
        }
    }
}
