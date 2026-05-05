import Foundation

/// Reads Supabase credentials injected via Info.plist at build time.
/// The anon key is intentionally public — RLS on the table enforces security.
struct SupabaseConfig {
    let projectURL: String
    let anonKey: String
    let table = "cd_leaderboard"

    static var current: SupabaseConfig? {
        guard
            let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !url.isEmpty, !key.isEmpty,
            url != "$(SUPABASE_URL)"
        else { return nil }
        return SupabaseConfig(projectURL: url.trimmingCharacters(in: .whitespacesAndNewlines),
                              anonKey: key.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
