import SwiftUI

/// Overview tab: kickoff/venue details and the "Who will win?" poll.
struct OverviewTab: View {
    @Environment(\.locale) private var locale
    @Bindable var model: MatchDetailViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            details
            if model.showsPoll {
                VotingCard(model: model)
            }
        }
    }

    private var details: some View {
        VStack(spacing: DS.Spacing.md) {
            if let match = model.match {
                InfoRow(labelKey: "match.kickoff", value: Formatters.dateTime(match.kickoff, locale: locale))
            }
            if let stadium = model.stadium {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    InfoRow(labelKey: "match.venue", value: stadium.name)
                    HStack {
                        Spacer()
                        Text(verbatim: stadium.location)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .glassCard()
    }
}

/// "Who will win?" voting card. Shows tappable options before voting and
/// percentage bars afterwards (or immediately once the match is finished).
private struct VotingCard: View {
    @Bindable var model: MatchDetailViewModel

    private var showButtons: Bool {
        model.isVotingOpen && model.userChoice == nil
    }

    var body: some View {
        GlassSection(titleKey: "match.whoWillWin") {
            if showButtons {
                HStack(spacing: DS.Spacing.sm) {
                    optionButton(.home, label: model.homeTeam?.id, flag: model.homeTeam?.displayFlag)
                    optionButton(.draw, label: nil, flag: nil)
                    optionButton(.away, label: model.awayTeam?.id, flag: model.awayTeam?.displayFlag)
                }
            } else if model.isAwaitingTally {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
            } else {
                VStack(spacing: DS.Spacing.md) {
                    resultBar(.home, label: model.homeTeam?.name ?? "")
                    resultBar(.draw, label: nil)
                    resultBar(.away, label: model.awayTeam?.name ?? "")
                }
                footer
            }
        }
        .animation(.snappy, value: model.userChoice)
        .task(id: model.matchId) { await model.loadVotesIfNeeded() }
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            if model.userChoice != nil {
                Text(key: "match.voted")
            }
            Spacer()
            if model.totalVotes > 0 {
                Text("\(model.totalVotes) votes")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func optionButton(_ choice: MatchVote.Choice, label: String?, flag: String?) -> some View {
        Button {
            Task { await model.castVote(choice) }
        } label: {
            VStack(spacing: DS.Spacing.xs) {
                if let flag {
                    Text(verbatim: flag).font(.title2)
                } else {
                    Image(systemName: "equal").font(.title3)
                }
                if let label {
                    Text(verbatim: label).font(.caption.weight(.semibold))
                } else {
                    Text(key: "match.vote.draw").font(.caption.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.chip))
        }
        .buttonStyle(.plain)
    }

    private func resultBar(_ choice: MatchVote.Choice, label: String?) -> some View {
        let fraction = model.vote.fraction(for: choice)
        let percent = Int((fraction * 100).rounded())
        let isPick = model.userChoice == choice
        return VStack(spacing: 4) {
            HStack {
                if let label, !label.isEmpty {
                    Text(verbatim: label).lineLimit(1)
                } else {
                    Text(key: "match.vote.draw")
                }
                Spacer()
                Text(verbatim: "\(percent)%").monospacedDigit().fontWeight(isPick ? .bold : .regular)
            }
            .font(.subheadline)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule()
                        .fill(isPick ? Color.accentColor : Color.accentColor.opacity(0.5))
                        .frame(width: max(4, geo.size.width * fraction))
                }
            }
            .frame(height: 8)
        }
    }
}
