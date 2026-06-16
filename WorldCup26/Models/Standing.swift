import Foundation

/// A computed row in a group standings table. Derived locally from finished
/// matches — we never depend on the API for this so groups work fully offline.
struct Standing: Identifiable, Hashable {
    let teamId: String
    var played: Int = 0
    var won: Int = 0
    var drawn: Int = 0
    var lost: Int = 0
    var goalsFor: Int = 0
    var goalsAgainst: Int = 0

    var id: String { teamId }
    var points: Int { won * 3 + drawn }
    var goalDifference: Int { goalsFor - goalsAgainst }

    /// Registers the outcome of a single match for this team.
    mutating func register(scored: Int, conceded: Int) {
        played += 1
        goalsFor += scored
        goalsAgainst += conceded
        if scored > conceded { won += 1 }
        else if scored == conceded { drawn += 1 }
        else { lost += 1 }
    }
}

extension Array where Element == Standing {
    /// Sorts by the standard group-stage tiebreakers: points, goal difference,
    /// goals scored, then team id for stable ordering.
    func ranked() -> [Standing] {
        sorted { a, b in
            if a.points != b.points { return a.points > b.points }
            if a.goalDifference != b.goalDifference { return a.goalDifference > b.goalDifference }
            if a.goalsFor != b.goalsFor { return a.goalsFor > b.goalsFor }
            return a.teamId < b.teamId
        }
    }
}
