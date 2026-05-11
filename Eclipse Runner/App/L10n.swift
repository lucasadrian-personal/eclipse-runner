import Foundation
import SwiftUI

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

// MARK: - LanguageManager (ObservableObject — drives cross-app re-render)

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var current: AppLanguage {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "appLanguage") }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? ""
        current = AppLanguage(rawValue: raw) ?? .english
    }
}

// MARK: - Localized strings

struct L10n {
    // Reading always from LanguageManager.shared so it stays in sync
    static var lang: AppLanguage {
        get { LanguageManager.shared.current }
        set { LanguageManager.shared.current = newValue }
    }

    // Helper
    static func t(_ en: String, _ es: String) -> String {
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
    static var noRankingsYet:     String { t("No rankings yet", "Sin clasificaciones aún") }
    static var playToAppear:      String { t("Play a game to appear\non the Galactic Leaderboard!", "¡Juega para aparecer\nen la Clasificación Galáctica!") }
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
    static var htpSpeedBody:      String { t("Every 10 points speed increases. Every 8 points the gap narrows — down to a razor-thin opening. Stay sharp.",
                                             "Cada 10 puntos aumenta la velocidad. Cada 8, el hueco se estrecha — hasta quedar casi sin margen. Mantente alerta.") }
    static var htpDailyBurst:     String { t("Daily Burst",   "Reto Diario") }
    static var htpDailyBurstBody: String { t("Every day a fresh world challenge resets at midnight UTC. You get 2 attempts — only your best score counts. Climb the daily ranking!",
                                             "Cada día un nuevo reto mundial se reinicia a medianoche UTC. Tienes 2 intentos — solo cuenta tu mejor puntuación. ¡Sube en el ranking diario!") }

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
    static var privacyPolicy:     String { t("Privacy Policy",         "Política de Privacidad") }

    // MARK: Settings – pilot name validation
    static var pilotNameTaken:     String { t("Pilot name already taken", "Nombre de piloto no disponible") }
    static var pilotNameAvailable: String { t("Name is available",       "Nombre disponible") }
    static var pilotNameChecking:  String { t("Checking…",               "Comprobando…") }

    // MARK: Shop
    static var shopTitle:         String { t("Pilot Shop",               "Tienda del Piloto") }
    static var shopSubtitle:      String { t("Spend your light-years",   "Gasta tus años luz") }
    static var shopTabSkins:      String { t("Skins",                    "Skins") }
    static var shopTabShields:    String { t("Shields",                  "Escudos") }
    static var shopFree:          String { t("FREE",                     "GRATIS") }
    static var shopLYCost:        String { t("light-yrs",                "a. luz") }
    static var shopPremium:       String { t("PREMIUM",                  "PREMIUM") }
    static var shopGetPremium:    String { t("Get Premium",              "Obtener Premium") }
    static var shopEquip:         String { t("Equip",                    "Equipar") }
    static var shopEquipped:      String { t("✓ Equipped",               "✓ Equipado") }
    static var shopBuyTitle:      String { t("Buy",                      "Comprar") }
    static var shopBuyConfirm:    String { t("Confirm Purchase",         "Confirmar Compra") }
    static var shopNotEnoughLY:   String { t("Not enough light-years. Keep flying!",
                                             "No tienes suficientes años luz. ¡Sigue volando!") }
    static var shopShieldsOwned:  String { t("Shields owned",            "Escudos disponibles") }
    static var shopShieldsHint:   String { t("A shield absorbs one collision per run. Activate before you play.",
                                             "Un escudo absorbe una colisión por partida. Actívalo antes de jugar.") }
    static var shopShieldsUnit:   String { t("shields",                  "escudos") }
    static var shopActiveShield:  String { t("Shield active",            "Escudo activo") }
    static var shopUseShield:     String { t("Use Shield",               "Usar Escudo") }

    // MARK: Onboarding
    static var onboardTitle1:   String { t("Welcome to Eclipse Runner", "Bienvenido a Eclipse Runner") }
    static var onboardSub1:     String { t("Navigate the cosmos.\nDodge asteroid gates.\nSurvive as long as you can.",
                                           "Navega el cosmos.\nEsquiva puertas de asteroides.\nSobrevive todo lo que puedas.") }
    static var onboardTitle2:   String { t("Simple Controls", "Controles simples") }
    static var onboardSub2:     String { t("Tap to thrust upward.\nRelease and gravity pulls you down.\nTime your taps perfectly.",
                                           "Toca para impulsarte hacia arriba.\nSuelta para caer con la gravedad.\nCalcula bien tus toques.") }
    static var onboardTitle3:   String { t("Speed Increases", "La velocidad aumenta") }
    static var onboardSub3:     String { t("Speed increases every 10 points.\nThe gap narrows every 8 — until there's barely room to breathe.\nSolar gusts add unpredictable wind. Stay sharp.",
                                           "La velocidad sube cada 10 puntos.\nEl hueco se estrecha cada 8 — hasta que apenas hay margen.\nRáfagas solares añaden viento impredecible. Mantente alerta.") }
    static var onboardTitle4:   String { t("Daily Burst", "Reto Diario") }
    static var onboardSub4:     String { t("A new world challenge every day.\nYou get 2 attempts — best score counts.\nClimb the global daily ranking!",
                                           "Un nuevo reto mundial cada día.\nTienes 2 intentos — cuenta tu mejor puntuación.\n¡Sube en el ranking diario global!") }
    static var onboardNameTitle:String { t("Choose Your Pilot Name", "Elige tu nombre de piloto") }
    static var onboardNameSub:  String { t("This is how you'll appear on the\nglobal leaderboard. Make it legendary.",
                                           "Así apareceréis en el\nranking global. Hazlo legendario.") }
    static var onboardNext:     String { t("Continue", "Continuar") }
    static var onboardLaunch:   String { t("Enter the Void 🚀", "Entrar al Vacío 🚀") }
    static var onboardSkip:     String { t("Skip for now", "Omitir por ahora") }

    // MARK: Misc
    static var cancel:            String { t("Cancel",                   "Cancelar") }
    static var ok:                String { t("OK",                       "OK") }

    // MARK: Battle
    static var battleTitle:           String { t("BATTLE 1v1",                    "DUELO 1v1") }
    static var battleChooseMode:      String { t("Choose your challenge mode",    "Elige tu modo de duelo") }
    static var battleBack:            String { t("Back",                          "Volver") }
    static var battleNearbyHeader:    String { t("IN PERSON · BLUETOOTH / DIRECT WIFI", "EN PERSONA · BLUETOOTH / WIFI DIRECTO") }
    static var battleNearbyNoInternet:String { t("No internet needed",            "Sin internet") }
    static var battleCreateLocal:     String { t("Create local game",             "Crear partida local") }
    static var battleCreateLocalSub:  String { t("Be the host — no internet",     "Sé el anfitrión — sin internet") }
    static var battleJoinLocal:       String { t("Join local game",               "Unirse a partida local") }
    static var battleJoinLocalSub:    String { t("Find the nearby host",          "Busca al anfitrión cercano") }
    static var battleOnlineHeader:    String { t("ONLINE · REQUIRES INTERNET",    "ONLINE · REQUIERE INTERNET") }
    static var battlePrivate:         String { t("Private duel",                  "Duelo privado") }
    static var battlePrivateSub:      String { t("Create room and share the code","Crea sala y comparte el código") }
    static var battleJoinCode:        String { t("Join with code",                "Unirse con código") }
    static var battleJoinCodeSub:     String { t("Enter the 6-character code",    "Introduce el código de 6 caracteres") }
    static var battleRandom:          String { t("Random rival",                  "Rival aleatorio") }
    static var battleRandomSub:       String { t("Any pilot online right now",    "Cualquier piloto online ahora") }
    static var battleRematch:         String { t("Challenge again",               "Retar de nuevo") }
    static var battleRematchTo:       String { t("to",                            "a") }
    static var battleLocalCreated:    String { t("Local game created",            "Sala local creada") }
    static var battleLocalWaiting:    String { t("Waiting for a nearby\nplayer to join…", "Esperando que un\njugador cercano se una…") }
    static var battleBTBadge:         String { t("Bluetooth / Direct WiFi · No internet", "Bluetooth / WiFi Directo · Sin internet") }
    static var battleSearchingHosts:  String { t("Searching for hosts",           "Buscando anfitriones") }
    static var battleSearchingHint:   String { t("Make sure the host has\nthe local game created", "Asegúrate de que el anfitrión tenga\nla sala local creada") }
    static var battleScanning:        String { t("Scanning…",                     "Escaneando…") }
    static var battleTapToJoin:       String { t("Tap to join",                   "Toca para unirte") }
    static var battleRoomCreated:     String { t("Room Created!",                 "¡Sala creada!") }
    static var battleShareCode:       String { t("Share the code below",          "Comparte el código a continuación") }
    static var battleWaitingOpponent: String { t("Waiting for an opponent to join…", "Esperando que se una un rival…") }
    static var battleRoomCode:        String { t("ROOM CODE",                     "CÓDIGO DE SALA") }
    static var battleShareCodeHint:   String { t("Share this code with your opponent", "Comparte este código con tu rival") }
    static var battleCancel:          String { t("Cancel",                        "Cancelar") }
    static var battleWon:             String { t("YOU WON!",                      "¡GANASTE!") }
    static var battleLost:            String { t("YOU LOST",                      "PERDISTE") }
    static var battleDraw:            String { t("IT'S A DRAW!",                  "¡EMPATE!") }
    static var battleDrawSub:         String { t("An epic tie between pilots!",   "¡Un empate épico entre pilotos!") }
    static var battleWonSub:          String { t("Dominant performance",          "Actuación dominante") }
    static var battleLostSub:         String { t("flew further this time.",       "voló más lejos esta vez.") }
    static var battleWaitingResult:   String { t("Waiting for opponent",          "Esperando al rival") }
    static var battleYourScore:       String { t("Your score:",                   "Tu puntuación:") }
    static var battleHeadToHead:      String { t("HEAD TO HEAD",                  "CARA A CARA") }
    static var battleWins:            String { t("WINS",                          "VICTORIAS") }
    static var battleDraws:           String { t("DRAWS",                         "EMPATES") }
    static var battleLosses:          String { t("LOSSES",                        "DERROTAS") }
    static var battleNewRival:        String { t("New rival",                     "Nuevo rival") }
    static var battleBackHome:        String { t("Back to Home",                  "Volver al inicio") }
    static var battleWinner:          String { t("WINNER",                        "GANADOR") }
    static var battleChallengeReceived: String { t("Challenge received!",         "¡Reto recibido!") }
    static var battleIsChallengingYou:  String { t("is challenging you",          "te está retando") }
    static var battleAccept:          String { t("Accept",                        "Aceptar") }
    static var battleJoinRoom:        String { t("JOIN ROOM",                     "ENTRAR A SALA") }
    static var battleJoinPrivate:     String { t("Join Private Room",             "Unirse a sala privada") }
    static var battleEnterCode:       String { t("Enter the 6-character room code", "Introduce el código de 6 caracteres") }
    static var battleConnectionIssue: String { t("Connection Issue",              "Problema de conexión") }
    static var battleTryAgain:        String { t("Try Again",                     "Intentar de nuevo") }
    static var battleRequiresInternet:String { t("Battle requires internet",      "La batalla requiere internet") }
    static var battleGoOnline:        String { t("Connect to WiFi or mobile data\nto challenge other pilots.", "Conéctate al WiFi o datos móviles\npara retar a otros pilotos.") }
    static var battleLocalBadge:      String { t("LOCAL",                         "LOCAL") }

    // MARK: Daily Burst – attempts
    static var dailyAttemptsLeft:  String { t("attempts left",          "intentos restantes") }
    static var dailyNoAttemptsLeft:String { t("No attempts left",       "Sin intentos") }
}
