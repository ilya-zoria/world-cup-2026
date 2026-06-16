import SwiftUI

/// The scoreboard header shown above the Match Detail tabs. Sits on the match
/// page's full-bleed flag-color gradient, so it draws no background of its own.
struct MatchScoreboard: View {
    @Environment(\.locale) private var locale

    let match: Match
    let home: Team?
    let away: Team?

    private let scoreSize: CGFloat = 46
    private let flagSize: CGFloat = 100

    private var hasScore: Bool { match.score?.home != nil && match.score?.away != nil }
    private var rowHeight: CGFloat { max(scoreSize, flagSize) }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            contextLabel
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(1)

            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                teamColumn(team: home, placeholder: match.homePlaceholder, side: .home)
                if hasScore { scoreText(.home) }
                centerColumn
                    .frame(minWidth: 84)
                    .frame(height: rowHeight)
                if hasScore { scoreText(.away) }
                teamColumn(team: away, placeholder: match.awayPlaceholder, side: .away)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.lg)
    }

    // MARK: Context (group / round), centered

    private var contextLabel: Text {
        if let groupId = match.groupId {
            return Text(key: "group.word") + Text(verbatim: " \(groupId)")
        } else if let round = match.round {
            return Text(key: round.displayKey)
        }
        return Text(verbatim: "")
    }

    // MARK: Team column (flag + name) — sits beside the score

    private enum Side { case home, away }

    private func teamColumn(team: Team?, placeholder: String?, side: Side) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            FlagView(emoji: team?.displayFlag ?? "", size: flagSize)
            Text(verbatim: team?.name ?? placeholder ?? "TBD")
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreText(_ side: Side) -> some View {
        Text(verbatim: score(side).map(String.init) ?? "–")
            .font(.score(scoreSize, weight: isWinner(side) ? .heavy : .semibold))
            .foregroundStyle(.white.opacity(isWinner(side) || isDraw ? 1 : 0.7))
            .frame(height: rowHeight)
    }

    // MARK: Center column (status / kickoff)

    @ViewBuilder
    private var centerColumn: some View {
        switch match.status {
        case .finished:
            VStack(spacing: 2) {
                Text(key: "status.fullTime")
                    .font(.headline)
                if let ht = halfTimeText {
                    Text(verbatim: ht)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        case .live:
            HStack(spacing: 5) {
                Circle().fill(.white).frame(width: 7, height: 7)
                Text(key: "status.live")
                    .font(.headline)
            }
        case .scheduled:
            VStack(spacing: 2) {
                Text(verbatim: Formatters.kickoffTime(match.kickoff, locale: locale))
                    .font(.score(26))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(key: "common.vs")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    // MARK: Helpers

    private func score(_ side: Side) -> Int? {
        side == .home ? match.score?.home : match.score?.away
    }

    private var isDraw: Bool {
        guard match.status == .finished, let h = match.score?.home, let a = match.score?.away else { return false }
        return h == a
    }

    private func isWinner(_ side: Side) -> Bool {
        guard match.status == .finished, let h = match.score?.home, let a = match.score?.away else { return false }
        return side == .home ? h > a : a > h
    }

    private var halfTimeText: String? {
        guard let h = match.score?.homeHalfTime, let a = match.score?.awayHalfTime else { return nil }
        return "(\(h) – \(a))"
    }
}

// MARK: - Previews

#if DEBUG
extension Team {
    static let previewHome = Team(id: "MEX", name: "Mexico", flag: "🇲🇽", isoCode: "mx",
                                  groupId: "A", confederation: "CONCACAF", fifaRanking: 13, apiTeamId: nil)
    static let previewAway = Team(id: "RSA", name: "South Africa", flag: "🇿🇦", isoCode: "za",
                                  groupId: "A", confederation: "CAF", fifaRanking: nil, apiTeamId: nil)
}

extension Match {
    /// A finished group-stage fixture for previews.
    static let previewFinished = Match(
        id: "preview-ft", stage: .group, groupId: "A", round: nil, matchNumber: 1,
        homeTeamId: "MEX", awayTeamId: "RSA", homePlaceholder: nil, awayPlaceholder: nil,
        stadiumId: nil, kickoff: Date(timeIntervalSince1970: 1_781_000_000),
        status: .finished,
        score: Score(home: 2, away: 0, homeHalfTime: 1, awayHalfTime: 0, winner: "HOME_TEAM"),
        apiMatchId: nil)

    /// An upcoming fixture (kickoff time + "vs", no score) for previews.
    static let previewScheduled = Match(
        id: "preview-sched", stage: .group, groupId: "A", round: nil, matchNumber: 2,
        homeTeamId: "MEX", awayTeamId: "RSA", homePlaceholder: nil, awayPlaceholder: nil,
        stadiumId: nil, kickoff: Date(timeIntervalSince1970: 1_781_000_000),
        status: .scheduled, score: nil, apiMatchId: nil)
}

/// A stand-in for the match page's flag-color gradient so the white text reads.
private struct PreviewBackdrop<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            LinearGradient(colors: [.green, .indigo, .red],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            content
        }
        .environment(\.colorScheme, .dark)
    }
}

#Preview("Full time") {
    PreviewBackdrop {
        MatchScoreboard(match: .previewFinished, home: .previewHome, away: .previewAway)
    }
}

#Preview("Scheduled") {
    PreviewBackdrop {
        MatchScoreboard(match: .previewScheduled, home: .previewHome, away: .previewAway)
    }
}
#endif
