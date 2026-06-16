import Foundation
import Observation

/// Lists all teams with live search filtering.
@MainActor
@Observable
final class TeamsViewModel {
    private let store: TournamentStore
    var searchText: String = ""
    private(set) var favoriteIDs: Set<String>

    private let favoritesKey = "favoriteTeamIDs"

    init(store: TournamentStore) {
        self.store = store
        let stored = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        self.favoriteIDs = Set(stored)
    }

    /// Teams after search filtering, ordered favorites-first, then by World Cup
    /// pedigree, then alphabetically — matching the Teams grid design.
    var filteredTeams: [Team] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let base = query.isEmpty ? store.teams : store.teams.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.id.localizedCaseInsensitiveContains(query)
        }
        return base.sorted { lhs, rhs in
            let lFav = favoriteIDs.contains(lhs.id)
            let rFav = favoriteIDs.contains(rhs.id)
            if lFav != rFav { return lFav }
            if lhs.worldCupTitles != rhs.worldCupTitles {
                return lhs.worldCupTitles > rhs.worldCupTitles
            }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }

    func isFavorite(_ team: Team) -> Bool { favoriteIDs.contains(team.id) }

    func toggleFavorite(_ team: Team) {
        if favoriteIDs.contains(team.id) {
            favoriteIDs.remove(team.id)
        } else {
            favoriteIDs.insert(team.id)
        }
        UserDefaults.standard.set(Array(favoriteIDs), forKey: favoritesKey)
    }
}

/// Drives a single team's overview, fixtures, stats and squad.
@MainActor
@Observable
final class TeamDetailViewModel {
    let team: Team
    private let store: TournamentStore

    init(team: Team, store: TournamentStore) {
        self.team = team
        self.store = store
    }

    var group: Group? { store.group(id: team.groupId) }
    var matches: [Match] { store.matches(forTeam: team.id) }
    var stats: Standing { store.teamStats(teamId: team.id) }
    var groupmates: [Team] {
        guard let groupId = team.groupId else { return [] }
        return store.teams(inGroup: groupId).filter { $0.id != team.id }
    }

    func team(_ id: String?) -> Team? { store.team(id: id) }
}
