import CoreGraphics
import Foundation

enum GameConfig {
    // ── Physics ─────────────────────────────────────────────────────────────
    // Gravity -9.8 with mass 0.018 and impulse 300 gives a proven Flappy-Bird
    // feel: snappy upward arc, natural fall. Paired with velocity clamps.
    static let gravity: CGFloat            = -9.8
    static let flapImpulse: CGFloat        = 200.0

    static let playerRadius: CGFloat       = 18
    static let playerMass: CGFloat         = 0.018
    // Clamp vertical speed to prevent tunnelling and off-screen rockets.
    static let maxFallSpeed: CGFloat       = -320
    static let maxRiseSpeed: CGFloat       =  280

    // Grace period before first obstacle arrives (gives player time to settle)
    static let firstSpawnDelay: TimeInterval = 2.2

    static let groundHeight: CGFloat       = 44

    static let baseScrollSpeed: CGFloat    = 160
    static let maxScrollMultiplier: CGFloat = 1.55

    static let baseGapHeight: CGFloat      = 210
    static let minGapHeight: CGFloat       = 120
    static let gapReductionStep: CGFloat   = 10

    static let obstacleWidth: CGFloat      = 68
    static let obstacleSpawnInterval: TimeInterval = 1.80

    static let scrollIncreaseEveryPoints: Int = 5
    static let gapDecreaseEveryPoints: Int    = 5

    static let windDuration: TimeInterval  = 2.0
    static let windIntervalMin: TimeInterval = 8.0
    static let windIntervalMax: TimeInterval = 12.0
    static let windForceMagnitude: CGFloat = 60
}
