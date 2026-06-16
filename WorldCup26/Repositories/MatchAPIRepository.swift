import Foundation

/// Fetches the dynamic parts of a match (status, score, lineups) from the API.
/// Everything here is best-effort: callers must keep working if it throws.
protocol MatchAPIRepositoryProtocol {
    var isConfigured: Bool { get }
    /// Latest status/score for every World Cup match the API knows about.
    func fetchMatchStates() async throws -> [MatchStateUpdate]
    /// Lineups for a single match, or `.empty` if the tier doesn't expose them.
    func fetchLineups(apiMatchId: Int) async throws -> MatchLineups
}

struct MatchAPIRepository: MatchAPIRepositoryProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    var isConfigured: Bool { client.configuration.isConfigured }

    func fetchMatchStates() async throws -> [MatchStateUpdate] {
        let code = client.configuration.competitionCode
        let response = try await client.get(
            FootballDataDTO.MatchesResponse.self,
            path: "competitions/\(code)/matches"
        )
        return response.matches.map { $0.toStateUpdate() }
    }

    func fetchLineups(apiMatchId: Int) async throws -> MatchLineups {
        let detail = try await client.get(
            FootballDataDTO.MatchDetailDTO.self,
            path: "matches/\(apiMatchId)"
        )
        return MatchLineups(
            home: detail.homeTeam?.toDomain(),
            away: detail.awayTeam?.toDomain()
        )
    }
}
