import Foundation

/// Configuration for the Supabase backend that powers the "Who will win?" poll.
///
/// Like `APIConfiguration`, this is OPTIONAL: when the host or anon key is
/// missing, `isConfigured` is false, `VoteStore` skips all networking, and the
/// poll degrades to a local-only pick (no cross-user tallies).
///
/// The values come from Info.plist (`SupabaseHost`, `SupabaseAnonKey`), which
/// Config.xcconfig fills from the gitignored Secrets.xcconfig. We store the
/// host WITHOUT a scheme because xcconfig treats `//` as a comment — the
/// `https://` prefix is added here.
struct VoteConfiguration {
    /// Base URL of the PostgREST endpoint, e.g. `https://<ref>.supabase.co/rest/v1`.
    let restURL: URL
    /// Public anon/publishable key. Safe to ship; RLS limits what it can do.
    let anonKey: String

    static let live: VoteConfiguration? = {
        let host = (Bundle.main.object(forInfoDictionaryKey: "SupabaseHost") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let key = (Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !host.isEmpty, !key.isEmpty,
              let url = URL(string: "https://\(host)/rest/v1") else { return nil }

        return VoteConfiguration(restURL: url, anonKey: key)
    }()
}
