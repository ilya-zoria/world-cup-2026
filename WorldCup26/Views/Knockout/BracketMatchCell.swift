import SwiftUI

/// A single fixture cell in the knockout bracket. Compact two-row layout that
/// works for both decided matches and "TBD" slots with placeholders.
struct BracketMatchCell: View {
    @Environment(TournamentStore.self) private var store
    @Environment(\.locale) private var locale

    let match: Match
    let width: CGFloat
    let height: CGFloat

    private var home: Team? { store.team(id: match.homeTeamId) }
    private var away: Team? { store.team(id: match.awayTeamId) }
    private var hasScore: Bool { match.score?.home != nil && match.score?.away != nil }

    var body: some View {
        VStack(spacing: 0) {
            row(team: home, placeholder: match.homePlaceholder, score: match.score?.home)
            Divider()
            row(team: away, placeholder: match.awayPlaceholder, score: match.score?.away)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .frame(width: width, height: height)
        .background(DS.Color.cardBackground, in: RoundedRectangle(cornerRadius: DS.Radius.chip))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.chip)
                .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
        )
        .overlay(alignment: .topTrailing) {
            if match.status == .live {
                Circle().fill(DS.Color.live).frame(width: 6, height: 6).padding(5)
            }
        }
    }

    private func row(team: Team?, placeholder: String?, score: Int?) -> some View {
        HStack(spacing: 6) {
            FlagView(emoji: team?.displayFlag ?? "", size: 18)
            Text(verbatim: team?.id ?? placeholder ?? "TBD")
                .font(.caption.weight(team == nil ? .regular : .semibold))
                .foregroundStyle(team == nil ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 2)
            if hasScore {
                Text(verbatim: score.map(String.init) ?? "–")
                    .font(.caption.monospacedDigit().weight(.bold))
            }
        }
        .frame(maxHeight: .infinity)
    }
}
