import Foundation

/// Fetches the dynamic parts of a match (status, score) from the API.
/// Everything here is best-effort: callers must keep working if it throws.
protocol MatchAPIRepositoryProtocol {
    var isConfigured: Bool { get }
    /// Latest status/score for every World Cup match the API knows about.
    func fetchMatchStates() async throws -> [MatchStateUpdate]
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
}
