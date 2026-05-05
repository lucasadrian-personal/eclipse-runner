import CoreGraphics
import Foundation

enum GameConfig {
    static let gravity: CGFloat            = -9.8
    static let flapImpulse: CGFloat        = 300

    static let playerRadius: CGFloat       = 20
    static let groundHeight: CGFloat       = 44

    static let baseScrollSpeed: CGFloat    = 165
    static let maxScrollMultiplier: CGFloat = 1.35

    static let baseGapHeight: CGFloat      = 185
    static let minGapHeight: CGFloat       = 140
    static let gapReductionStep: CGFloat   = 4

    static let obstacleWidth: CGFloat      = 62
    static let obstacleSpawnInterval: TimeInterval = 1.55

    static let scrollIncreaseEveryPoints: Int = 10
    static let gapDecreaseEveryPoints: Int    = 15

    static let windDuration: TimeInterval  = 2.0
    static let windIntervalMin: TimeInterval = 8.0
    static let windIntervalMax: TimeInterval = 12.0
    static let windForceMagnitude: CGFloat = 80
}
