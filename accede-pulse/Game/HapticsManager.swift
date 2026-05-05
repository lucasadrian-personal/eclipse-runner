import UIKit

final class HapticsManager {
    static let shared = HapticsManager()
    private init() {}

    /// Persisted haptics mute state — when true, all vibrations are silenced.
    var isDisabled: Bool {
        get { UserDefaults.standard.bool(forKey: "cd.hapticsDisabled") }
        set { UserDefaults.standard.set(newValue, forKey: "cd.hapticsDisabled") }
    }

    func impactLight() {
        guard !isDisabled else { return }
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare(); g.impactOccurred()
    }

    func impactMedium() {
        guard !isDisabled else { return }
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare(); g.impactOccurred()
    }

    func impactHeavy() {
        guard !isDisabled else { return }
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.prepare(); g.impactOccurred()
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard !isDisabled else { return }
        let g = UINotificationFeedbackGenerator()
        g.prepare(); g.notificationOccurred(type)
    }
}
