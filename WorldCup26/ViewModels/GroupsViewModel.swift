import Foundation
import Observation

/// Lists all 12 groups.
@MainActor
@Observable
final class GroupsViewModel {
    private let store: TournamentStore

    init(store: TournamentStore) {
        self.store = store
    }

    var groups: [Group] { store.groups }

    func teams(in group: Group) -> [Team] { store.teams(inGroup: group.id) }

    /// Teams paired with their points, ordered by group ranking — the same
    /// order shown in the group's standings table.
    func standingRows(in group: Group) -> [GroupStandingRow] {
        store.standings(forGroup: group.id).compactMap { standing in
            store.team(id: standing.teamId).map { GroupStandingRow(team: $0, points: standing.points) }
        }
    }
}

/// A single row in a group card: a team and its current points.
struct GroupStandingRow: Identifiable {
    let team: Team
    let points: Int
    var id: String { team.id }
}

/// Drives a single group's standings + fixtures.
@MainActor
@Observable
final class GroupDetailViewModel {
    let group: Group
    private let store: TournamentStore

    init(group: Group, store: TournamentStore) {
        self.group = group
        self.store = store
    }

    var standings: [Standing] { store.standings(forGroup: group.id) }
    var matches: [Match] { store.matches(inGroup: group.id) }

    func team(_ id: String?) -> Team? { store.team(id: id) }
}
