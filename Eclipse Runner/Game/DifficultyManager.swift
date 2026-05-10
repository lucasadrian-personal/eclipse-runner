import CoreGraphics

struct DifficultySnapshot {
    let scrollMultiplier: CGFloat
    let currentGapHeight: CGFloat
}

final class DifficultyManager {
    func snapshot(forScore score: Int) -> DifficultySnapshot {
        // Puntos 0–5: zona de gracia — velocidad y hueco máximos fijos
        guard score > 5 else {
            return DifficultySnapshot(scrollMultiplier: 1.0,
                                      currentGapHeight: GameConfig.baseGapHeight)
        }
        // A partir del punto 6, la dificultad escala un 10% más rápido
        let s           = score - 5
        let scrollSteps = s / GameConfig.scrollIncreaseEveryPoints
        let gapSteps    = s / GameConfig.gapDecreaseEveryPoints

        let multiplier = min(
            1.0 + CGFloat(scrollSteps) * 0.055,
            GameConfig.maxScrollMultiplier
        )
        let gap = max(
            GameConfig.baseGapHeight - CGFloat(gapSteps) * GameConfig.gapReductionStep,
            GameConfig.minGapHeight
        )
        return DifficultySnapshot(scrollMultiplier: multiplier, currentGapHeight: gap)
    }
}
