import SwiftUI

/// A compact group standings table. Top two positions (which advance) are
/// tinted; `highlightTeamIds` emphasizes specific rows (used on match stats).
struct StandingsTableView: View {
    @Environment(TournamentStore.self) private var store

    let standings: [Standing]
    var highlightTeamIds: Set<String> = []

    var body: some View {
        Grid(alignment: .center, horizontalSpacing: DS.Spacing.sm, verticalSpacing: DS.Spacing.md) {
            GridRow {
                Text(verbatim: "#").gridColumnAlignment(.center)
                Text(verbatim: "").frame(maxWidth: .infinity, alignment: .leading)
                headerCell("group.table.played")
                headerCell("group.table.won")
                headerCell("group.table.drawn")
                headerCell("group.table.lost")
                headerCell("group.table.gd")
                headerCell("group.table.points")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)

            ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                GridRow {
                    Text(verbatim: "\(index + 1)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(index < 2 ? Color.accentColor : .secondary)

                    teamCell(standing.teamId)

                    numberCell(standing.played)
                    numberCell(standing.won)
                    numberCell(standing.drawn)
                    numberCell(standing.lost)
                    numberCell(standing.goalDifference, signed: true)
                    Text(verbatim: "\(standing.points)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                .padding(.vertical, 2)
                .background(
                    highlightTeamIds.contains(standing.teamId)
                        ? Color.accentColor.opacity(0.08)
                        : .clear
                )
            }
        }
    }

    private func headerCell(_ key: String) -> some View {
        Text(key: key).gridColumnAlignment(.center)
    }

    private func teamCell(_ teamId: String) -> some View {
        let team = store.team(id: teamId)
        return HStack(spacing: DS.Spacing.sm) {
            FlagView(emoji: team?.displayFlag ?? "", size: 22)
            Text(verbatim: team?.name ?? teamId)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func numberCell(_ value: Int, signed: Bool = false) -> some View {
        Text(verbatim: signed && value > 0 ? "+\(value)" : "\(value)")
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }
}
