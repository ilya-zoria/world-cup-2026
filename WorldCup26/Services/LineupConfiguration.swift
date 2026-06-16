import Foundation

/// Configuration for the static lineups feed.
///
/// Lineups aren't available on the Football-Data free tier, so they're sourced
/// from a small static JSON file published by a scheduled job (see
/// `.github/workflows/lineups.yml` + `Tools/fetch_lineups.py`). The app only
/// *reads* that file — it never calls the lineup provider directly — so usage
/// stays inside the provider's free quota no matter how many users there are.
///
/// `LineupsFeedURL` is set in `Secrets.xcconfig` (it's deployment-specific, not
/// secret) and surfaced through the generated Info.plist. When absent the
/// feature is simply off and the Lineups tab shows its empty state.
///
/// Stored **without a scheme** (e.g. `owner.github.io/repo/lineups.json`) because
/// xcconfig treats `//` as a comment — same convention as `SupabaseHost`. We
/// prepend `https://` here unless the value already carries a scheme.
struct LineupConfiguration {
    let feedURL: URL?

    var isConfigured: Bool { feedURL != nil }

    static let live: LineupConfiguration = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "LineupsFeedURL") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return LineupConfiguration(feedURL: nil) }
        let normalized = raw.contains("://") ? raw : "https://\(raw)"
        return LineupConfiguration(feedURL: URL(string: normalized))
    }()
}
