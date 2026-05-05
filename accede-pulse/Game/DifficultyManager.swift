import CoreGraphics

struct DifficultySnapshot {
    let scrollMultiplier: CGFloat
    let currentGapHeight: CGFloat
}

final class DifficultyManager {
    func snapshot(forScore score: Int) -> DifficultySnapshot {
        let scrollSteps = score / GameConfig.scrollIncreaseEveryPoints
        let gapSteps    = score / GameConfig.gapDecreaseEveryPoints

        let multiplier = min(
            1.0 + CGFloat(scrollSteps) * 0.05,
            GameConfig.maxScrollMultiplier
        )
        let gap = max(
            GameConfig.baseGapHeight - CGFloat(gapSteps) * GameConfig.gapReductionStep,
            GameConfig.minGapHeight
        )
        return DifficultySnapshot(scrollMultiplier: multiplier, currentGapHeight: gap)
    }
}
