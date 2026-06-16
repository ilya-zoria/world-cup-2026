import Foundation

/// A national team participating in the tournament. Loaded from bundled JSON.
struct Team: Codable, Identifiable, Hashable {
    /// Stable internal id, the FIFA three-letter code (e.g. "ARG").
    let id: String
    let name: String
    /// Unicode regional-indicator flag emoji, e.g. "🇦🇷".
    let flag: String
    /// Two-letter ISO country code used for asset lookups, e.g. "ar".
    let isoCode: String?
    /// Group letter A–L, or nil if the team's group is undetermined.
    let groupId: String?
    let confederation: String?
    let fifaRanking: Int?
    /// Football-Data team id, used to correlate API responses with local data.
    let apiTeamId: Int?

    var displayFlag: String { flag.isEmpty ? "🏳️" : flag }

    /// Number of FIFA World Cup titles this nation has won. Drives the trophy
    /// badge on the Teams grid. Keyed by the FIFA three-letter `id`.
    var worldCupTitles: Int {
        switch id {
        case "BRA": return 5
        case "GER", "ITA": return 4
        case "ARG": return 3
        case "FRA", "URY": return 2
        case "ESP", "ENG": return 1
        default: return 0
        }
    }
}
