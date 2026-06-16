import SwiftUI

/// The large, symmetric match layout used by the Home feed segments.
///
/// Flags sit on the outer edges with the team name beneath. The inner columns
/// show the scoreline (finished / live) or each team's tournament W–D–L record
/// (scheduled), and the dead-center column shows the match state or kickoff time.
struct FeaturedMatchCard: View {
    @Environment(TournamentStore.self) private var store
    @Environment(\.locale) private var locale

    let match: Match

    private let flagSize: CGFloat = 56

    private var home: Team? { store.team(id: match.homeTeamId) }
    private var away: Team? { store.team(id: match.awayTeamId) }
    private var hasScore: Bool { match.score?.home != nil && match.score?.away != nil }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            contextLabel
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                teamColumn(team: home, placeholder: match.homePlaceholder, isWinner: isWinner(.home))
                innerValue(for: .home)
                centerColumn
                    .frame(minWidth: 88)
                    .frame(height: flagSize)
                innerValue(for: .away)
                teamColumn(team: away, placeholder: match.awayPlaceholder, isWinner: isWinner(.away))
            }
        }
        .frame(maxWidth: .infinity)
        .card()
        .contentShape(Rectangle())
    }

    // MARK: Context (stage / group / round), centered

    private var contextLabel: Text {
        if let groupId = match.groupId {
            return Text(key: "group.word") + Text(verbatim: " \(groupId)")
        } else if let round = match.round {
            return Text(key: round.displayKey)
        }
        return Text(verbatim: "")
    }

    // MARK: Team column (flag + name)

    private func teamColumn(team: Team?, placeholder: String?, isWinner: Bool) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            flag(team?.displayFlag ?? "")
            Text(verbatim: team?.name ?? placeholder ?? "TBD")
                .font(.subheadline)
                .fontWeight(isWinner ? .bold : .semibold)
                .foregroundStyle(team == nil ? .secondary : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func flag(_ emoji: String) -> some View {
        Text(emoji.isEmpty ? "🏳️" : emoji)
            .font(.system(size: 44))
            .frame(width: flagSize, height: flagSize)
    }

    // MARK: Inner value (score; empty for scheduled matches)

    @ViewBuilder
    private func innerValue(for side: Side) -> some View {
        if hasScore {
            Text(verbatim: score(side).map(String.init) ?? "–")
                .font(.score(34, weight: isWinner(side) ? .bold : .semibold))
                .foregroundStyle(match.status == .live ? DS.Color.live : .primary)
                .frame(height: flagSize)
        }
    }

    // MARK: Center column (status / kickoff time)

    @ViewBuilder
    private var centerColumn: some View {
        switch match.status {
        case .finished:
            Text(key: "status.fullTime")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        case .live:
            HStack(spacing: 4) {
                Circle().fill(DS.Color.live).frame(width: 7, height: 7)
                Text(key: "status.live")
                    .font(.headline)
                    .foregroundStyle(DS.Color.live)
            }
        case .scheduled:
            Text(verbatim: Formatters.kickoffTime(match.kickoff, locale: locale))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: Helpers

    private enum Side { case home, away }

    private func score(_ side: Side) -> Int? {
        side == .home ? match.score?.home : match.score?.away
    }

    private func isWinner(_ side: Side) -> Bool {
        guard match.status == .finished, let h = match.score?.home, let a = match.score?.away else { return false }
        return side == .home ? h > a : a > h
    }
}
