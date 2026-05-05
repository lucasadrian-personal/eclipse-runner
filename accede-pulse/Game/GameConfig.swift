import CoreGraphics
import Foundation

enum GameConfig {
    // ── Physics ─────────────────────────────────────────────────────────────
    // SpriteKit's physicsWorld works in metres but renders in points.
    // A strong negative gravity (-28) gives a crisp Flappy-Bird-style arc:
    // fast fall when you stop tapping, snappy rise on each tap.
    static let gravity: CGFloat            = -28.0
    // Impulse is paired with mass=0.022 so one tap = ~1.8 s of rise time.
    static let flapImpulse: CGFloat        = 310.0

    static let playerRadius: CGFloat       = 18
    static let playerMass: CGFloat         = 0.022
    // Clamp maximum downward speed so the astronaut never tunnels through thin gaps.
    static let maxFallSpeed: CGFloat       = -420
    // Cap upward speed so a rapid double-tap can't rocket off screen.
    static let maxRiseSpeed: CGFloat       =  380

    static let groundHeight: CGFloat       = 44

    static let baseScrollSpeed: CGFloat    = 160
    static let maxScrollMultiplier: CGFloat = 1.35

    static let baseGapHeight: CGFloat      = 185
    static let minGapHeight: CGFloat       = 140
    static let gapReductionStep: CGFloat   = 4

    static let obstacleWidth: CGFloat      = 68
    static let obstacleSpawnInterval: TimeInterval = 1.55

    static let scrollIncreaseEveryPoints: Int = 10
    static let gapDecreaseEveryPoints: Int    = 15

    static let windDuration: TimeInterval  = 2.0
    static let windIntervalMin: TimeInterval = 8.0
    static let windIntervalMax: TimeInterval = 12.0
    static let windForceMagnitude: CGFloat = 110
}
