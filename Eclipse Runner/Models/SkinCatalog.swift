import SwiftUI

// MARK: - Skin rarity

enum SkinRarity: String, Codable {
    case standard, rare, legendary
    var label: String {
        switch self {
        case .standard:  return "STANDARD"
        case .rare:      return "RARE"
        case .legendary: return "LEGENDARY"
        }
    }
    var color: Color {
        switch self {
        case .standard:  return Color(white: 0.7)
        case .rare:      return Color(red: 0.36, green: 0.90, blue: 1.00)
        case .legendary: return Color(red: 1.00, green: 0.86, blue: 0.45)
        }
    }
}

// MARK: - Unlock type

enum SkinUnlock: Codable, Equatable {
    case free                    // owned from the start
    case lightYears(Int)         // buy with LY currency
    case iap(String)             // StoreKit product ID
}

// MARK: - Shield pack

struct ShieldPack: Identifiable {
    let id: String
    let name: String
    let count: Int
    let price: String           // display price — real IAP in ShopIAPManager
    let icon: String            // SF Symbol
}

// MARK: - Astronaut skin

struct AstronautSkin: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let rarity: SkinRarity
    let unlock: SkinUnlock

    // Suit & accent colors stored as raw components for Codable compatibility
    let suitR: Double; let suitG: Double; let suitB: Double
    let accentR: Double; let accentG: Double; let accentB: Double
    let visorR: Double; let visorG: Double; let visorB: Double
    let flameR: Double; let flameG: Double; let flameB: Double

    var suitColor:   Color { Color(red: suitR,   green: suitG,   blue: suitB) }
    var accentColor: Color { Color(red: accentR,  green: accentG,  blue: accentB) }
    var visorColor:  Color { Color(red: visorR,   green: visorG,   blue: visorB) }
    var flameColor:  Color { Color(red: flameR,   green: flameG,   blue: flameB) }

    // UIKit colours for SpriteKit texture rendering
    var uiSuitColor:   UIColor { UIColor(red: suitR,   green: suitG,   blue: suitB,   alpha: 1) }
    var uiAccentColor: UIColor { UIColor(red: accentR,  green: accentG,  blue: accentB,  alpha: 1) }
    var uiVisorColor:  UIColor { UIColor(red: visorR,   green: visorG,   blue: visorB,   alpha: 1) }
    var uiFlameColor:  UIColor { UIColor(red: flameR,   green: flameG,   blue: flameB,   alpha: 1) }
}

// MARK: - Catalog

struct SkinCatalog {

    // Free shield packs (IAP)
    static let shieldPacks: [ShieldPack] = [
        ShieldPack(id: "com.eclipserunner.shields1", name: "Shield Pack", count: 3, price: "€0.99", icon: "shield.fill"),
        ShieldPack(id: "com.eclipserunner.shields5", name: "Shield Bundle", count: 10, price: "€2.99", icon: "shield.lefthalf.filled")
    ]

    static let all: [AstronautSkin] = [

        // ── STANDARD ────────────────────────────────────────────────────────────
        AstronautSkin(id: "classic", name: "Classic White",   rarity: .standard,
                      unlock: .free,
                      suitR: 0.90, suitG: 0.93, suitB: 0.98,
                      accentR: 0.67, accentG: 0.73, accentB: 0.84,
                      visorR: 0.30, visorG: 0.82, visorB: 1.00,
                      flameR: 0.97, flameG: 0.64, flameB: 0.23),

        AstronautSkin(id: "nebula_cyan", name: "Nebula Cyan",  rarity: .standard,
                      unlock: .lightYears(50),
                      suitR: 0.12, suitG: 0.72, suitB: 0.88,
                      accentR: 0.05, accentG: 0.50, accentB: 0.74,
                      visorR: 0.80, visorG: 0.98, visorB: 1.00,
                      flameR: 0.97, flameG: 0.64, flameB: 0.23),

        AstronautSkin(id: "void_black", name: "Void Black",   rarity: .standard,
                      unlock: .lightYears(80),
                      suitR: 0.12, suitG: 0.14, suitB: 0.20,
                      accentR: 0.20, accentG: 0.22, accentB: 0.30,
                      visorR: 0.55, visorG: 0.20, visorB: 1.00,
                      flameR: 0.97, flameG: 0.64, flameB: 0.23),

        AstronautSkin(id: "aurora_pink", name: "Aurora Pink", rarity: .standard,
                      unlock: .lightYears(100),
                      suitR: 0.95, suitG: 0.62, suitB: 0.80,
                      accentR: 0.80, accentG: 0.30, accentB: 0.60,
                      visorR: 1.00, visorG: 0.78, visorB: 0.90,
                      flameR: 0.97, flameG: 0.64, flameB: 0.23),

        AstronautSkin(id: "solar_gold", name: "Solar Gold",  rarity: .standard,
                      unlock: .lightYears(150),
                      suitR: 0.92, suitG: 0.76, suitB: 0.22,
                      accentR: 0.75, accentG: 0.55, accentB: 0.10,
                      visorR: 1.00, visorG: 0.92, visorB: 0.50,
                      flameR: 0.97, flameG: 0.64, flameB: 0.23),

        // ── RARE ────────────────────────────────────────────────────────────────
        AstronautSkin(id: "plasma_red", name: "Plasma Red",  rarity: .rare,
                      unlock: .lightYears(200),
                      suitR: 0.70, suitG: 0.08, suitB: 0.12,
                      accentR: 0.90, accentG: 0.20, accentB: 0.20,
                      visorR: 1.00, visorG: 0.42, visorB: 0.42,
                      flameR: 1.00, flameG: 0.30, flameB: 0.10),

        AstronautSkin(id: "forest_green", name: "Forest Green", rarity: .rare,
                      unlock: .iap("com.eclipserunner.skin.forest"),
                      suitR: 0.12, suitG: 0.48, suitB: 0.22,
                      accentR: 0.10, accentG: 0.36, accentB: 0.18,
                      visorR: 0.55, visorG: 1.00, visorB: 0.65,
                      flameR: 0.40, flameG: 0.90, flameB: 0.20),

        // ── LEGENDARY ───────────────────────────────────────────────────────────
        AstronautSkin(id: "ghost", name: "Ghost",            rarity: .legendary,
                      unlock: .iap("com.eclipserunner.skin.ghost"),
                      suitR: 0.85, suitG: 0.88, suitB: 0.98,
                      accentR: 0.70, accentG: 0.75, accentB: 0.95,
                      visorR: 0.90, visorG: 0.96, visorB: 1.00,
                      flameR: 0.80, flameG: 0.90, flameB: 1.00),

        AstronautSkin(id: "galactic", name: "Galactic",      rarity: .legendary,
                      unlock: .iap("com.eclipserunner.skin.galactic"),
                      suitR: 0.28, suitG: 0.10, suitB: 0.55,
                      accentR: 0.50, accentG: 0.20, accentB: 0.80,
                      visorR: 0.85, visorG: 0.55, visorB: 1.00,
                      flameR: 0.80, flameG: 0.40, flameB: 1.00)
    ]

    static func skin(id: String) -> AstronautSkin {
        all.first { $0.id == id } ?? all[0]
    }
}
