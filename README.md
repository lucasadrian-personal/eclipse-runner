# Eclipse Runner

An iOS endless runner set in space. Tap to propel your astronaut through asteroid fields, compete on a global leaderboard, and challenge other pilots to real-time 1v1 battles.

## Gameplay

- **Tap to thrust** — Flappy Bird-style physics with tuned gravity, impulse, and velocity clamping to prevent tunnelling.
- **Progressive difficulty** — scroll speed and asteroid gap narrow every 5 points, capped at 1.55× base speed.
- **Wind events** — random lateral wind bursts every 8–12 seconds add unpredictability.
- **Shields** — consumable protection against one collision.

## Features

| Feature | Details |
|---|---|
| Skins | 9 astronaut skins across Standard / Rare / Legendary rarities |
| Currency | Light Years (LY) earned in-game; used to unlock Standard & Rare skins |
| IAP | Rare & Legendary skins + shield packs via StoreKit |
| Leaderboard | Global top-100 via Supabase (offline-cached fallback) |
| Battle Mode | Real-time 1v1 rooms with shared seed for fair comparison |
| Daily Burst | Timed daily challenge mode |
| Onboarding | First-launch flow before entering the main hub |

## Tech Stack

- **UI** — SwiftUI (dark mode enforced)
- **Game engine** — SpriteKit (`CosmicGameScene`)
- **Backend** — Supabase (leaderboard, battle rooms, realtime)
- **Purchases** — StoreKit via `ShopIAPManager`
- **Audio / Haptics** — `AudioManager` + `HapticsManager` singletons
- **Localization** — `LanguageManager` + `L10n.swift`

## Project Structure

```
Eclipse Runner/
├── App/            # Entry point, root view, theme, localization
├── Game/           # SpriteKit scene, physics config, difficulty, audio, haptics
├── Views/          # Home, Shop, Battle, DailyBurst, Onboarding, shared components
├── Models/         # GameStore (state), SkinCatalog
└── Backend/        # Supabase config, leaderboard, battle, IAP services
```

## Requirements

- iOS 16+
- Xcode 15+
- Supabase project credentials in `SupabaseConfig`
