import SwiftUI

/// The reusable match row used across Home, Groups, Teams and the bracket.
/// Resolves teams and venue from the store so callers only pass a `Match`.
struct MatchCardView: View {
    @Environment(TournamentStore.self) private var store
    @Environment(\.locale) private var locale

    let match: Match
    /// When true, shows the group/round + venue context line (hidden inside
    /// places that already provide that context, e.g. a group's match list).
    var showContext: Bool = true

    private var home: Team? { store.team(id: match.homeTeamId) }
    private var away: Team? { store.team(id: match.awayTeamId) }
    private var stadium: Stadium? { store.stadium(id: match.stadiumId) }

    private var hasScore: Bool { match.score?.home != nil && match.score?.away != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if showContext {
                header
            }
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                VStack(spacing: DS.Spacing.sm) {
                    teamRow(team: home, placeholder: match.homePlaceholder, isWinner: isWinner(.home))
                    teamRow(team: away, placeholder: match.awayPlaceholder, isWinner: isWinner(.away))
                }
                rightColumn
                    .frame(minWidth: 52)
            }
        }
        .card()
        .contentShape(Rectangle())
    }

    // MARK: Header (context + status)

    private var header: some View {
        HStack(spacing: DS.Spacing.sm) {
            contextLabel
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: DS.Spacing.sm)
            StatusBadge(status: match.status)
        }
    }

    /// Built via `Text` composition (not `String(localized:)`) so the localized
    /// parts follow the in-app language selection.
    private var contextLabel: Text {
        let stagePart: Text
        if let groupId = match.groupId {
            stagePart = Text(key: "group.word") + Text(verbatim: " \(groupId)")
        } else if let round = match.round {
            stagePart = Text(key: round.shortKey)
        } else {
            stagePart = Text(verbatim: "")
        }
        if let city = stadium?.city {
            return stagePart + Text(verbatim: " · \(city)")
        }
        return stagePart
    }

    // MARK: Team rows

    private func teamRow(team: Team?, placeholder: String?, isWinner: Bool) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            FlagView(emoji: team?.displayFlag ?? "", size: 26)
            Text(verbatim: team?.name ?? placeholder ?? "TBD")
                .font(.subheadline)
                .fontWeight(isWinner ? .bold : .regular)
                .foregroundStyle(team == nil ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
    }

    // MARK: Right column (scores or kickoff)

    @ViewBuilder
    private var rightColumn: some View {
        if hasScore {
            VStack(spacing: DS.Spacing.sm) {
                scoreText(match.score?.home, isWinner: isWinner(.home))
                scoreText(match.score?.away, isWinner: isWinner(.away))
            }
        } else {
            VStack(spacing: 2) {
                Text(verbatim: Formatters.kickoffTime(match.kickoff, locale: locale))
                    .font(.headline)
                    .monospacedDigit()
                Text(verbatim: Formatters.mediumDate(match.kickoff, locale: locale))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scoreText(_ value: Int?, isWinner: Bool) -> some View {
        Text(verbatim: value.map(String.init) ?? "–")
            .font(.score(22, weight: isWinner ? .bold : .semibold))
            .foregroundStyle(match.status == .live ? DS.Color.live : .primary)
    }

    // MARK: Winner detection

    private enum Side { case home, away }

    private func isWinner(_ side: Side) -> Bool {
        guard match.status == .finished, let h = match.score?.home, let a = match.score?.away else { return false }
        switch side {
        case .home: return h > a
        case .away: return a > h
        }
    }
}
