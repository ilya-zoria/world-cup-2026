import Foundation

/// A single fixture. The static parts (teams, venue, kickoff) come from bundled
/// JSON; `status` and `score` are enriched from the API at runtime.
struct Match: Codable, Identifiable, Hashable {
    let id: String

    // MARK: Stage

    /// "group" or "knockout".
    let stage: Stage
    /// Group letter when `stage == .group`.
    let groupId: String?
    /// Round when `stage == .knockout`.
    let round: KnockoutRound?
    /// Match number within the tournament (1...104), used for bracket ordering.
    let matchNumber: Int?

    // MARK: Participants

    /// Home team id. Nil for knockout fixtures whose teams aren't decided yet.
    let homeTeamId: String?
    let awayTeamId: String?
    /// Human-readable placeholder for an undecided slot, e.g. "Winner Group A"
    /// or "Runner-up Group C". Localization key when it matches a known token.
    let homePlaceholder: String?
    let awayPlaceholder: String?

    // MARK: Context

    let stadiumId: String?
    /// Kickoff time in UTC.
    let kickoff: Date

    // MARK: Dynamic (API-enriched, defaults from JSON)

    var status: MatchStatus
    var score: Score?

    /// Football-Data match id used to fetch live data.
    let apiMatchId: Int?

    enum Stage: String, Codable, Hashable {
        case group
        case knockout
    }

    var isGroupStage: Bool { stage == .group }
}

extension Match {
    /// Returns a copy with API-sourced dynamic fields applied.
    func applying(status: MatchStatus, score: Score?) -> Match {
        var copy = self
        copy.status = status
        if let score { copy.score = score }
        return copy
    }
}
