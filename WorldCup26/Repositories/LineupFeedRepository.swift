import Foundation

/// Provides match lineups by reading the static feed published by the scheduled
/// `fetch_lineups.py` job (see `Services/LineupConfiguration`). Best-effort:
/// callers fall back to an empty state if it throws or isn't configured.
protocol LineupRepositoryProtocol: Sendable {
    var isConfigured: Bool { get }
    /// Lineups for a single match, or `.empty` if the feed doesn't have them yet.
    func fetchLineups(for match: Match) async throws -> MatchLineups
}

/// Fetches the whole feed once (cached for `feedTTL`) and serves per-match
/// lookups from it — one network GET covers every match on screen.
struct LineupFeedRepository: LineupRepositoryProtocol {
    private let configuration: LineupConfiguration
    private let session: URLSession
    private let cache = InMemoryCache<String, [String: MatchLineups]>(ttl: 10 * 60)
    private let cacheKey = "feed"

    init(configuration: LineupConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    var isConfigured: Bool { configuration.isConfigured }

    func fetchLineups(for match: Match) async throws -> MatchLineups {
        let feed = try await currentFeed()
        return feed[match.id] ?? .empty
    }

    /// The published feed, keyed by our local match id. Cached so repeated tab
    /// opens don't re-download; falls back to the last good copy on a transient
    /// network error.
    private func currentFeed() async throws -> [String: MatchLineups] {
        guard let url = configuration.feedURL else { return [:] }
        if let cached = await cache.value(for: cacheKey) { return cached }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return await cache.staleValue(for: cacheKey) ?? [:]
            }
            let decoded = try JSONDecoder().decode(FeedDTO.self, from: data)
            await cache.insert(decoded.lineups, for: cacheKey)
            return decoded.lineups
        } catch {
            // Offline / transient: serve the last good feed if we have one.
            return await cache.staleValue(for: cacheKey) ?? [:]
        }
    }

    /// Only the `lineups` map is read; bookkeeping keys in the file are ignored.
    private struct FeedDTO: Decodable {
        let lineups: [String: MatchLineups]
    }
}
