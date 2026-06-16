import Foundation

/// Local "Who will win?" poll tally for a match. Persisted on-device only;
/// there is no backend, so these reflect this user's taps plus seeded numbers.
struct MatchVote: Codable, Hashable {
    var home: Int = 0
    var draw: Int = 0
    var away: Int = 0

    enum Choice: String, Codable, CaseIterable { case home, draw, away }

    var total: Int { home + draw + away }

    func count(for choice: Choice) -> Int {
        switch choice {
        case .home: return home
        case .draw: return draw
        case .away: return away
        }
    }

    /// Fraction 0...1 for a choice, 0 when no votes yet.
    func fraction(for choice: Choice) -> Double {
        guard total > 0 else { return 0 }
        return Double(count(for: choice)) / Double(total)
    }

    mutating func add(_ choice: Choice) {
        switch choice {
        case .home: home += 1
        case .draw: draw += 1
        case .away: away += 1
        }
    }
}
