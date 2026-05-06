import Foundation

// MARK: - Language

enum AppLanguage: String, CaseIterable, Codable {
    case english = "en"
    case spanish = "es"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        }
    }
    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .spanish: return "🇪🇸"
        }
    }
}

// MARK: - Localized strings

struct L10n {
    static var lang: AppLanguage {
        get {
            let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? ""
            return AppLanguage(rawValue: raw) ?? .english
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "appLanguage") }
    }

    // Helper
    private static func t(_ en: String, _ es: String) -> String {
        lang == .spanish ? es : en
    }

    // MARK: Home
    static var welcomeBack:       String { t("Welcome back",              "Bienvenido de nuevo") }
    static var tagline:           String { t("Drift through the void.\nDodge. Survive. Repeat.",
                                             "Navega el vacío.\nEsquiva. Sobrevive. Repite.") }
    static var launch:            String { t("LAUNCH",                    "EMPEZAR") }
    static var galacticLB:        String { t("Galactic Leaderboard",      "Clasificación Galáctica") }
    static var howToPlay:         String { t("How to Play",               "Cómo Jugar") }
    static var oneTapControls:    String { t("One-tap controls",          "Control de un toque") }
    static var dailyBurst:        String { t("Daily Burst",               "Reto Diario") }
    static var resetsIn6h:        String { t("Resets in 6h",              "Se reinicia en 6h") }
    static var dailyBurstSubtitle:String { t("A new challenge every day.\nCompete for the world top spot.",
                                             "Un nuevo reto cada día.\nCompite por el puesto número 1 mundial.") }
    static var dailyResetsIn:     String { t("Resets in",                 "Se reinicia en") }
    static var dailyRankLabel:    String { t("Today Rank",                "Rank de Hoy") }
    static var dailyStartBurst:   String { t("START BURST",               "EMPEZAR RETO") }
    static var dailyPlayAgain:    String { t("PLAY AGAIN",                "JUGAR DE NUEVO") }
    static var dailyCompleted:    String { t("Today's burst completed!",  "¡Reto de hoy completado!") }
    static var dailyRankingTitle: String { t("Today's World Ranking",     "Ranking Mundial de Hoy") }
    static var dailyTodayOnly:    String { t("Resets at midnight UTC",    "Se reinicia a medianoche UTC") }
    static var dailyNoEntries:    String { t("No pilots yet today.\nBe the first to set a score!",
                                             "Ningún piloto aún hoy.\n¡Sé el primero en puntuar!") }
    static var dailyBurstSubtitleShort: String { t("New challenge every day",
                                                    "Nuevo reto cada día") }

    // MARK: Stat pills
    static var statRuns:          String { t("Runs",       "Partidas") }
    static var statLightYrs:      String { t("Light-yrs",  "A. Luz") }
    static var statBest:          String { t("Best",       "Récord") }
    static var tooltipRuns:       String { t("Total games played. Every time you start and finish a run it counts as 1.",
                                             "Partidas jugadas en total. Cada vez que empiezas y terminas cuenta como 1.") }
    static var tooltipLightYrs:   String { t("Light-years travelled across all runs. Each gate you pass adds 1 light-year to your cosmic odometer. ✨",
                                             "Años luz recorridos en total. Cada gate que atraviesas suma 1 año luz a tu odómetro cósmico. ✨") }
    static var tooltipBest:       String { t("Your personal best: the most gates you crossed in a single run. 🏆",
                                             "Tu récord personal: el mayor número de gates en una sola partida. 🏆") }

    // MARK: HUD / Game
    static var bestLabel:         String { t("BEST",        "RÉC.") }
    static var solarGust:         String { t("Solar gust",  "Viento solar") }

    // MARK: Game Over
    static var newRecord:         String { t("🏆 New Record!",           "🏆 ¡Nuevo Récord!") }
    static var missionOver:       String { t("Mission Over",              "Misión Terminada") }
    static var newRecordSub:      String { t("You crushed your personal best!",
                                             "¡Has superado tu récord personal!") }
    static var missionOverSub:    String { t("The void claims another pilot…",
                                             "El vacío reclama a otro piloto…") }
    static var tryAgain:          String { t("Try Again",  "Intentar de nuevo") }
    static var backToHome:        String { t("Back to Home", "Volver al inicio") }
    static var scoreLabel:        String { t("SCORE",  "SCORE") }
    static var globalRank:        String { t("Global rank",   "Ranking global") }
    static var fetchingRank:      String { t("Fetching rank…", "Buscando ranking…") }

    // MARK: Leaderboard
    static var liveGlobal:        String { t("Live global rankings",
                                             "Rankings globales en directo") }
    static var cachedRankings:    String { t("Showing cached rankings · Go online to refresh",
                                             "Rankings en caché · Conéctate para actualizar") }
    static var scanningGalaxy:    String { t("Scanning the galaxy…", "Escaneando la galaxia…") }
    static var liveLabel:         String { t("LIVE",   "LIVE") }
    static var cachedLabel:       String { t("CACHED", "CACHÉ") }

    // MARK: How to Play
    static var htpTitle:          String { t("How to Play",   "Cómo Jugar") }
    static var htpTap:            String { t("Tap to fly",    "Toca para volar") }
    static var htpTapBody:        String { t("Each tap gives a gentle thrust upward. Release to drift down with gravity.",
                                             "Cada toque impulsa hacia arriba. Suelta para caer con la gravedad.") }
    static var htpGap:            String { t("Mind the gap",  "Cuida el hueco") }
    static var htpGapBody:        String { t("Slip through asteroid gates. Touching anything ends the run.",
                                             "Pasa por las puertas de asteroides. Tocar algo termina la partida.") }
    static var htpWind:           String { t("Solar gusts",   "Vientos solares") }
    static var htpWindBody:       String { t("Cosmic winds will nudge you up or down. Adjust on the fly.",
                                             "El viento cósmico te empujará arriba o abajo. Adáptate rápido.") }
    static var htpSpeed:          String { t("Speed climbs",  "La velocidad aumenta") }
    static var htpSpeedBody:      String { t("Every 10 points cranks the difficulty. Stay sharp.",
                                             "Cada 10 puntos aumenta la dificultad. Mantente alerta.") }

    // MARK: Settings
    static var missionSettings:   String { t("Mission Settings",       "Ajustes de Misión") }
    static var pilotIdentity:     String { t("PILOT IDENTITY",         "IDENTIDAD DEL PILOTO") }
    static var pilotNamePH:       String { t("Pilot name",             "Nombre del piloto") }
    static var savePilotName:     String { t("Save Pilot Name",        "Guardar nombre") }
    static var pilotNameHint:     String { t("Your name appears on the global leaderboard after each run.",
                                             "Tu nombre aparece en el ranking global tras cada partida.") }
    static var soundHaptics:      String { t("SOUND & HAPTICS",        "SONIDO Y VIBRACIÓN") }
    static var soundEffects:      String { t("Sound Effects",          "Efectos de sonido") }
    static var soundOn:           String { t("Flap, score & crash sounds on", "Sonidos de aleteo, puntos y choque activados") }
    static var soundOff:          String { t("All sounds muted",       "Todos los sonidos silenciados") }
    static var hapticFeedback:    String { t("Haptic Feedback",        "Vibración táctil") }
    static var hapticOn:          String { t("Vibrations enabled",     "Vibraciones activadas") }
    static var hapticOff:         String { t("Vibrations disabled",    "Vibraciones desactivadas") }
    static var yourStats:         String { t("YOUR STATS",             "TUS ESTADÍSTICAS") }
    static var bestScore:         String { t("Best Score",             "Mejor Puntuación") }
    static var totalRuns:         String { t("Total Runs",             "Partidas Totales") }
    static var lightYrs:          String { t("Light-yrs",              "Años Luz") }
    static var about:             String { t("ABOUT",                  "ACERCA DE") }
    static var leaderboard:       String { t("Leaderboard",            "Clasificación") }
    static var version:           String { t("Version",                "Versión") }
    static var online:            String { t("Online",                 "Conectado") }
    static var offline:           String { t("Offline",                "Sin conexión") }
    static var language:          String { t("LANGUAGE",               "IDIOMA") }

    // MARK: Daily Burst – attempts
    static var dailyAttemptsLeft:  String { t("attempts left",          "intentos restantes") }
    static var dailyNoAttemptsLeft:String { t("No attempts left",       "Sin intentos") }
}
