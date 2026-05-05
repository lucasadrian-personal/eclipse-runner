import UIKit

final class HapticsManager {
    static let shared = HapticsManager()
    private init() {}

    func impactLight() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare(); g.impactOccurred()
    }

    func impactMedium() {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare(); g.impactOccurred()
    }

    func impactHeavy() {
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.prepare(); g.impactOccurred()
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let g = UINotificationFeedbackGenerator()
        g.prepare(); g.notificationOccurred(type)
    }
}
