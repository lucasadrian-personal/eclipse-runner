import SwiftUI

/// Cosmic Drift visual identity — deep space indigos, electric cyan, warm aurora.
enum Theme {
    // Backgrounds
    static let spaceTop = Color(red: 0.04, green: 0.06, blue: 0.18)
    static let spaceMid = Color(red: 0.07, green: 0.04, blue: 0.24)
    static let spaceBottom = Color(red: 0.02, green: 0.10, blue: 0.22)

    // Accents
    static let nebulaPink = Color(red: 1.00, green: 0.42, blue: 0.78)
    static let nebulaPurple = Color(red: 0.62, green: 0.40, blue: 1.00)
    static let auroraCyan = Color(red: 0.36, green: 0.90, blue: 1.00)
    static let auroraMint = Color(red: 0.40, green: 1.00, blue: 0.78)
    static let starGold = Color(red: 1.00, green: 0.86, blue: 0.45)

    // Text / surfaces
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.66)
    static let textTertiary = Color.white.opacity(0.42)
    static let surface = Color.white.opacity(0.06)
    static let surfaceStroke = Color.white.opacity(0.10)

    static let cosmicBackground = LinearGradient(
        colors: [spaceTop, spaceMid, spaceBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryGradient = LinearGradient(
        colors: [auroraCyan, nebulaPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [nebulaPink, nebulaPurple],
        startPoint: .leading,
        endPoint: .trailing
    )
}
