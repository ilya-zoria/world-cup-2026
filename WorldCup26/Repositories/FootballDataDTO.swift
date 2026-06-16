import Foundation

/// Data-transfer objects mirroring the Football-Data v4 JSON shape.
/// Kept separate from domain models so the API contract can change
/// independently of the rest of the app.
enum FootballDataDTO {

    struct MatchesResponse: Decodable {
        let matches: [MatchDTO]
    }

    struct MatchDTO: Decodable {
        let id: Int
        let status: String
        let score: ScoreDTO?
    }

    struct ScoreDTO: Decodable {
        let winner: String?
        let fullTime: GoalsDTO?
        let halfTime: GoalsDTO?
    }

    struct GoalsDTO: Decodable {
        let home: Int?
        let away: Int?
    }
}

// MARK: - Mapping to domain models

extension FootballDataDTO.MatchDTO {
    func toStateUpdate() -> MatchStateUpdate {
        let domainScore = Score(
            home: score?.fullTime?.home,
            away: score?.fullTime?.away,
            homeHalfTime: score?.halfTime?.home,
            awayHalfTime: score?.halfTime?.away,
            winner: score?.winner
        )
        return MatchStateUpdate(
            apiMatchId: id,
            status: MatchStatus(apiStatus: status),
            score: domainScore
        )
    }
}

/// A minimal status/score patch keyed by the API match id, applied onto local matches.
struct MatchStateUpdate: Hashable {
    let apiMatchId: Int
    let status: MatchStatus
    let score: Score
}
