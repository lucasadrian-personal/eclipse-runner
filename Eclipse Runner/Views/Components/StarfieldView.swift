import SwiftUI

/// Layered animated starfield using TimelineView + Canvas. Lightweight, no images.
struct StarfieldView: View {
    var starCount: Int = 80
    var showsNebula: Bool = true

    private let stars: [Star] = (0..<140).map { _ in Star.random() }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate

                if showsNebula {
                    drawNebula(ctx: &ctx, size: size, t: t)
                }

                for (i, star) in stars.prefix(starCount).enumerated() {
                    let x = star.x * size.width
                    let y = (star.y * size.height + CGFloat(t * star.driftSpeed * 8)).truncatingRemainder(dividingBy: size.height)
                    let twinkle = 0.55 + 0.45 * sin(t * star.twinkleSpeed + Double(i))
                    let r = star.radius
                    var path = Path()
                    path.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                    ctx.fill(path, with: .color(.white.opacity(twinkle * star.alpha)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func drawNebula(ctx: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let pulse = CGFloat(sin(t * 0.15)) * 0.04
        let blob1 = Path(ellipseIn: CGRect(
            x: size.width * 0.55,
            y: size.height * 0.18,
            width: size.width * (0.85 + pulse),
            height: size.height * (0.55 + pulse)
        ))
        ctx.fill(blob1, with: .radialGradient(
            Gradient(colors: [Theme.nebulaPurple.opacity(0.45), .clear]),
            center: CGPoint(x: size.width * 0.78, y: size.height * 0.36),
            startRadius: 0, endRadius: size.width * 0.55
        ))

        let blob2 = Path(ellipseIn: CGRect(
            x: -size.width * 0.25,
            y: size.height * 0.45,
            width: size.width * (0.95 + pulse),
            height: size.height * (0.5 + pulse)
        ))
        ctx.fill(blob2, with: .radialGradient(
            Gradient(colors: [Theme.nebulaPink.opacity(0.32), .clear]),
            center: CGPoint(x: size.width * 0.18, y: size.height * 0.65),
            startRadius: 0, endRadius: size.width * 0.55
        ))
    }
}

private struct Star {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let alpha: Double
    let twinkleSpeed: Double
    let driftSpeed: Double

    static func random() -> Star {
        Star(
            x: .random(in: 0...1),
            y: .random(in: 0...1),
            radius: .random(in: 0.4...1.8),
            alpha: .random(in: 0.4...1.0),
            twinkleSpeed: .random(in: 0.8...3.2),
            driftSpeed: .random(in: 0.05...0.45)
        )
    }
}
