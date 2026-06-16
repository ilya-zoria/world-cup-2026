import SwiftUI

/// Lineups tab: formation, starting XI and substitutes for each side. Sourced
/// from the API; shows a graceful empty state offline / on free API tiers.
struct LineupsTab: View {
    @Bindable var model: MatchDetailViewModel

    var body: some View {
        if model.isLoadingLineups {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(DS.Spacing.xl)
        } else if model.lineupsAvailable {
            VStack(spacing: DS.Spacing.lg) {
                if let home = model.lineups.home {
                    TeamLineupView(teamName: model.homeTeam?.name ?? "", flag: model.homeTeam?.displayFlag, lineup: home)
                }
                if let away = model.lineups.away {
                    TeamLineupView(teamName: model.awayTeam?.name ?? "", flag: model.awayTeam?.displayFlag, lineup: away)
                }
            }
        } else {
            EmptyStateView(
                systemImage: "person.3.sequence",
                titleKey: "match.lineups.empty.title",
                messageKey: "match.lineups.empty.message"
            )
            .glassCard()
        }
    }
}

private struct TeamLineupView: View {
    let teamName: String
    let flag: String?
    let lineup: TeamLineup

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                FlagView(emoji: flag ?? "", size: 26)
                Text(verbatim: teamName).font(.headline)
                Spacer()
                if let formation = lineup.formation {
                    Text(verbatim: formation)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
            }

            if !lineup.startingXI.isEmpty {
                Text(key: "match.lineups.starting")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(lineup.startingXI) { player in
                    playerRow(player)
                }
            }

            if !lineup.bench.isEmpty {
                Divider()
                Text(key: "match.lineups.bench")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(lineup.bench) { player in
                    playerRow(player)
                }
            }
        }
        .glassCard()
    }

    private func playerRow(_ player: Player) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text(verbatim: player.shirtNumber.map(String.init) ?? "–")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            Text(verbatim: player.name)
                .font(.subheadline)
            Spacer()
            if let position = player.position {
                Text(verbatim: position)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
