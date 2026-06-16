import Foundation

enum VoteError: LocalizedError {
    case invalidResponse
    case http(status: Int, body: String)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The vote server returned an unexpected response."
        case .http(let status, _): return "The vote server responded with status \(status)."
        case .transport(let error): return error.localizedDescription
        case .decoding(let error): return "Could not read the vote tally: \(error)"
        }
    }
}

/// Talks to Supabase (PostgREST) for the "Who will win?" poll.
///
/// Votes are immutable, one row per user per match (`match_votes`). Tallies are
/// read from the `match_vote_tallies` view, which aggregates those rows into
/// per-choice counts. See `Tools/supabase_setup.sql` for the schema + RLS.
protocol VoteServicing: Sendable {
    /// Global counts for a match, aggregated across all users. Returns a
    /// zeroed tally when no one has voted yet.
    func fetchTally(matchId: String) async throws -> MatchVote
    /// Records this user's single, immutable vote. Idempotent: a repeated vote
    /// for the same (match, user) is ignored server-side, so this never throws
    /// for a duplicate.
    func submitVote(matchId: String, userId: String, choice: MatchVote.Choice) async throws
}

struct SupabaseVoteService: VoteServicing {
    let configuration: VoteConfiguration
    private let session: URLSession

    init(configuration: VoteConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    private static let decoder = JSONDecoder()

    // MARK: Read

    private struct TallyRow: Decodable {
        let home: Int
        let draw: Int
        let away: Int
    }

    func fetchTally(matchId: String) async throws -> MatchVote {
        var components = URLComponents(
            url: configuration.restURL.appendingPathComponent("match_vote_tallies"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "match_id", value: "eq.\(matchId)"),
            URLQueryItem(name: "select", value: "home,draw,away"),
        ]
        guard let url = components?.url else { throw VoteError.invalidResponse }

        var request = baseRequest(url: url)
        request.httpMethod = "GET"

        let (data, http) = try await perform(request)
        guard (200..<300).contains(http.statusCode) else {
            throw VoteError.http(status: http.statusCode, body: String(decoding: data, as: UTF8.self))
        }
        do {
            let rows = try Self.decoder.decode([TallyRow].self, from: data)
            guard let row = rows.first else { return MatchVote() }
            return MatchVote(home: row.home, draw: row.draw, away: row.away)
        } catch {
            throw VoteError.decoding(error)
        }
    }

    // MARK: Write

    private struct VoteRow: Encodable {
        let match_id: String
        let user_id: String
        let choice: String
    }

    func submitVote(matchId: String, userId: String, choice: MatchVote.Choice) async throws {
        let url = configuration.restURL.appendingPathComponent("match_votes")
        var request = baseRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Insert-or-ignore on the (match_id, user_id) primary key: re-voting is a
        // no-op, which enforces "one immutable vote per user".
        request.setValue("resolution=ignore-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(
            VoteRow(match_id: matchId, user_id: userId, choice: choice.rawValue)
        )

        let (data, http) = try await perform(request)
        guard (200..<300).contains(http.statusCode) else {
            throw VoteError.http(status: http.statusCode, body: String(decoding: data, as: UTF8.self))
        }
    }

    // MARK: Plumbing

    private func baseRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw VoteError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else { throw VoteError.invalidResponse }
        return (data, http)
    }
}
