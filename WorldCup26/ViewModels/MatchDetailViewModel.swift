import Foundation
import Observation

/// Drives the Match Detail screen and its tabs (Overview, Stats).
@MainActor
@Observable
final class MatchDetailViewModel {
    enum Tab: Hashable, CaseIterable {
        case overview, stats
        var titleKey: String {
            switch self {
            case .overview: return "match.tab.overview"
            case .stats: return "match.tab.stats"
            }
        }
    }

    let matchId: String
    private let store: TournamentStore
    private let votes: VoteStore

    var selectedTab: Tab = .overview
    private(set) var isLoadingVotes = false

    init(matchId: String, store: TournamentStore, votes: VoteStore) {
        self.matchId = matchId
        self.store = store
        self.votes = votes
    }

    // MARK: Resolved entities (recompute from the store so live updates show)

    var match: Match? { store.match(id: matchId) }
    var homeTeam: Team? { store.team(id: match?.homeTeamId) }
    var awayTeam: Team? { store.team(id: match?.awayTeamId) }
    var stadium: Stadium? { store.stadium(id: match?.stadiumId) }
    var group: Group? { store.group(id: match?.groupId) }
    var standings: [Standing] {
        guard let groupId = match?.groupId else { return [] }
        return store.standings(forGroup: groupId)
    }

    var isGroupStage: Bool { match?.isGroupStage ?? false }
    var isAPIConfigured: Bool { store.isAPIConfigured }

    /// Both participants are known. Knockout fixtures whose slots aren't decided
    /// yet (e.g. "Winner Group A") carry no team ids, so the poll stays hidden
    /// until the bracket resolves them.
    var teamsDecided: Bool { match?.homeTeamId != nil && match?.awayTeamId != nil }

    /// Whether the "Who will win?" poll should be shown at all. Group-stage
    /// fixtures always qualify; knockout fixtures only once both teams exist.
    var showsPoll: Bool { teamsDecided }

    /// Whether to offer voting buttons — only before a result exists.
    var isVotingOpen: Bool {
        guard let match else { return false }
        return match.status != .finished
    }

    // MARK: Voting

    /// Global tally aggregated across all users (zeros until loaded/voted).
    var vote: MatchVote { votes.tally(forMatch: matchId) }
    var userChoice: MatchVote.Choice? { votes.userChoice(forMatch: matchId) }
    var hasVoted: Bool { votes.hasVoted(forMatch: matchId) }
    var totalVotes: Int { vote.total }
    var isRemoteVotingEnabled: Bool { votes.isRemoteEnabled }

    /// True while we're fetching the first tally and have nothing to show yet.
    var isAwaitingTally: Bool { isLoadingVotes && totalVotes == 0 }

    /// Fetches the latest global tally once the poll is on screen.
    func loadVotesIfNeeded() async {
        guard showsPoll, isRemoteVotingEnabled else { return }
        isLoadingVotes = true
        defer { isLoadingVotes = false }
        await votes.loadTally(forMatch: matchId)
    }

    func castVote(_ choice: MatchVote.Choice) async {
        await votes.castVote(choice, forMatch: matchId)
    }
}
