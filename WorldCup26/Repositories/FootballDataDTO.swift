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

    // MARK: Lineups (single-match endpoint)

    struct MatchDetailDTO: Decodable {
        let id: Int
        let homeTeam: TeamLineupDTO?
        let awayTeam: TeamLineupDTO?
    }

    struct TeamLineupDTO: Decodable {
        let formation: String?
        let lineup: [PlayerDTO]?
        let bench: [PlayerDTO]?
    }

    struct PlayerDTO: Decodable {
        let id: Int
        let name: String
        let position: String?
        let shirtNumber: Int?
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

extension FootballDataDTO.TeamLineupDTO {
    func toDomain() -> TeamLineup {
        TeamLineup(
            formation: formation,
            startingXI: (lineup ?? []).map { $0.toDomain() },
            bench: (bench ?? []).map { $0.toDomain() }
        )
    }
}

extension FootballDataDTO.PlayerDTO {
    func toDomain() -> Player {
        Player(id: id, name: name, position: position, shirtNumber: shirtNumber)
    }
}

/// A minimal status/score patch keyed by the API match id, applied onto local matches.
struct MatchStateUpdate: Hashable {
    let apiMatchId: Int
    let status: MatchStatus
    let score: Score
}
