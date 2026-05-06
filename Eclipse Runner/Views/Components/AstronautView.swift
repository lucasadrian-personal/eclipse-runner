import SwiftUI

/// Pure-SwiftUI astronaut illustration — clean, friendly, on-brand.
struct AstronautView: View {
    var size: CGFloat = 180
    @State private var float = false
    @State private var glow = false

    var body: some View {
        ZStack {
            // Soft glow halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.auroraCyan.opacity(0.55), .clear],
                        center: .center, startRadius: 0, endRadius: size * 0.7
                    )
                )
                .frame(width: size * 1.6, height: size * 1.6)
                .scaleEffect(glow ? 1.05 : 0.95)
                .opacity(glow ? 0.9 : 0.6)

            // Body
            astronautBody
                .frame(width: size, height: size)
                .shadow(color: Theme.auroraCyan.opacity(0.4), radius: 24, y: 8)
                .offset(y: float ? -10 : 10)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                float = true
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }

    private var astronautBody: some View {
        ZStack {
            // Backpack
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.85), Color(white: 0.75)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 70, height: 78)
                .offset(x: 0, y: 14)

            // Suit / body
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.white, Color(white: 0.88)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 110, height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
                .offset(y: 18)

            // Helmet
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.white, Color(white: 0.85)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)

                // Visor
                Circle()
                    .fill(LinearGradient(
                        colors: [
                            Theme.spaceTop,
                            Theme.nebulaPurple.opacity(0.9),
                            Theme.auroraCyan.opacity(0.8)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 86, height: 78)

                // Visor highlight
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 22, height: 8)
                    .offset(x: -18, y: -22)

                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 8, height: 8)
                    .offset(x: 22, y: -8)
            }
            .offset(y: -34)

            // Antenna
            Capsule()
                .fill(Color.white)
                .frame(width: 4, height: 16)
                .offset(y: -100)
            Circle()
                .fill(Theme.starGold)
                .frame(width: 10, height: 10)
                .offset(y: -110)
                .shadow(color: Theme.starGold, radius: 6)

            // Chest control
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.auroraCyan.opacity(0.9))
                .frame(width: 26, height: 14)
                .offset(y: 18)
                .shadow(color: Theme.auroraCyan, radius: 4)
        }
    }
}
