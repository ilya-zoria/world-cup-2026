import Foundation
import Observation

/// Coordinates the "Who will win?" poll.
///
/// Tallies are real, aggregated across all users by the Supabase backend
/// (`VoteServicing`) — never seeded or hardcoded. Each user casts a single,
/// immutable vote (one row per user per match); the choice is remembered
/// on-device so the UI can show their pick and prevent re-voting. Last-known
/// tallies are cached so results still render offline and on next launch.
///
/// When Supabase isn't configured (`isRemoteEnabled == false`) the poll
/// degrades to a local-only pick: the user can still vote and see their own
/// choice reflected, but there are no cross-user counts.
@MainActor
@Observable
final class VoteStore {
    private static let choicesKey = "matchVoteChoices"
    private static let talliesKey = "matchVoteTallies"
    private static let voterIdKey = "anonVoterId"

    /// This user's own immutable pick per match.
    private var choices: [String: MatchVote.Choice] = [:]
    /// Last-known global tallies per match, cached for offline display.
    private var tallies: [String: MatchVote] = [:]
    /// Matches whose tally we've already fetched this session.
    private var loaded: Set<String> = []

    private let service: VoteServicing?
    /// Stable anonymous id identifying this install as a voter.
    let voterId: String

    var isRemoteEnabled: Bool { service != nil }

    init(service: VoteServicing? = nil) {
        if let service {
            self.service = service
        } else if let config = VoteConfiguration.live {
            self.service = SupabaseVoteService(configuration: config)
        } else {
            self.service = nil
        }
        self.voterId = Self.loadOrCreateVoterId()
        load()
    }

    // MARK: Reads

    /// Global tally for a match (zeros until the first vote / fetch).
    func tally(forMatch id: String) -> MatchVote {
        tallies[id] ?? MatchVote()
    }

    func userChoice(forMatch id: String) -> MatchVote.Choice? {
        choices[id]
    }

    func hasVoted(forMatch id: String) -> Bool {
        choices[id] != nil
    }

    // MARK: Fetch

    /// Loads the latest global tally for a match. No-op when the backend is
    /// unconfigured or (unless `force`) already fetched this session. Network
    /// failures are swallowed so the cached/last-known tally keeps showing.
    func loadTally(forMatch id: String, force: Bool = false) async {
        guard let service else { return }
        guard force || !loaded.contains(id) else { return }
        do {
            let fresh = try await service.fetchTally(matchId: id)
            tallies[id] = fresh
            loaded.insert(id)
            persistTallies()
        } catch {
            // Keep whatever we had; the poll stays usable offline.
        }
    }

    // MARK: Vote

    /// Records this user's single, immutable vote. Re-voting is ignored (the
    /// pick can't be changed). The local tally is bumped optimistically, then
    /// reconciled with the authoritative server count.
    func castVote(_ choice: MatchVote.Choice, forMatch id: String) async {
        guard choices[id] == nil else { return }

        choices[id] = choice
        var optimistic = tally(forMatch: id)
        optimistic.add(choice)
        tallies[id] = optimistic
        persistChoices()
        persistTallies()

        guard let service else { return }
        do {
            try await service.submitVote(matchId: id, userId: voterId, choice: choice)
            await loadTally(forMatch: id, force: true)
        } catch {
            // Vote stays recorded locally and optimistically counted; it will
            // reconcile on the next successful fetch.
        }
    }

    // MARK: Persistence

    private static func loadOrCreateVoterId() -> String {
        if let existing = UserDefaults.standard.string(forKey: voterIdKey) {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: voterIdKey)
        return id
    }

    private func load() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: Self.choicesKey),
           let decoded = try? decoder.decode([String: MatchVote.Choice].self, from: data) {
            choices = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.talliesKey),
           let decoded = try? decoder.decode([String: MatchVote].self, from: data) {
            tallies = decoded
        }
    }

    private func persistChoices() {
        if let data = try? JSONEncoder().encode(choices) {
            UserDefaults.standard.set(data, forKey: Self.choicesKey)
        }
    }

    private func persistTallies() {
        if let data = try? JSONEncoder().encode(tallies) {
            UserDefaults.standard.set(data, forKey: Self.talliesKey)
        }
    }
}
