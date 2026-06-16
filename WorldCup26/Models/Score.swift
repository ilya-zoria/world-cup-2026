import Foundation

/// The score of a match. All fields optional because they only exist once a
/// match is live or finished, and may be enriched from the API.
struct Score: Codable, Hashable {
    var home: Int?
    var away: Int?
    var homeHalfTime: Int?
    var awayHalfTime: Int?
    /// "HOME_TEAM" | "AWAY_TEAM" | "DRAW" | nil
    var winner: String?

    var hasResult: Bool { home != nil && away != nil }

    /// Formatted full-time score, e.g. "2 – 1". Returns nil when not available.
    var display: String? {
        guard let home, let away else { return nil }
        return "\(home) – \(away)"
    }

    static let empty = Score(home: nil, away: nil, homeHalfTime: nil, awayHalfTime: nil, winner: nil)
}
