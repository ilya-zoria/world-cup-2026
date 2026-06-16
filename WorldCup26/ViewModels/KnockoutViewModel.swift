import Foundation
import Observation

/// Provides the knockout bracket as ordered columns of matches.
@MainActor
@Observable
final class KnockoutViewModel {
    private let store: TournamentStore

    init(store: TournamentStore) {
        self.store = store
    }

    struct Column: Identifiable {
        let round: KnockoutRound
        let matches: [Match]
        var id: String { round.rawValue }
    }

    /// The five bracket columns (R32 → Final).
    var columns: [Column] {
        KnockoutRound.bracketColumns.map { round in
            Column(round: round, matches: store.knockoutMatches(round: round))
        }
    }

    /// The third-place play-off, shown separately under the bracket.
    var thirdPlace: Match? {
        store.knockoutMatches(round: .thirdPlace).first
    }
}
