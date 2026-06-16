import Foundation

/// A single player entry in a lineup. Sourced from the API when available.
struct Player: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let position: String?
    let shirtNumber: Int?
}

/// One team's lineup for a match.
struct TeamLineup: Codable, Hashable {
    let formation: String?
    let startingXI: [Player]
    let bench: [Player]

    var isEmpty: Bool { startingXI.isEmpty && bench.isEmpty }
}

/// Both lineups for a match. `nil` sides mean the API didn't provide them.
struct MatchLineups: Codable, Hashable {
    let home: TeamLineup?
    let away: TeamLineup?

    var isEmpty: Bool { (home?.isEmpty ?? true) && (away?.isEmpty ?? true) }

    static let empty = MatchLineups(home: nil, away: nil)
}
