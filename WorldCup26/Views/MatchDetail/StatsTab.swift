import SwiftUI

/// Stats / Context tab: group-standings impact and any basic stats available
/// from the result.
struct StatsTab: View {
    @Bindable var model: MatchDetailViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            if model.isGroupStage {
                groupImpact
            }
            basicStats
        }
    }

    // MARK: Group impact

    private var groupImpact: some View {
        GlassSection(titleKey: "match.stats.groupImpact") {
            StandingsTableView(
                standings: model.standings,
                highlightTeamIds: Set([model.match?.homeTeamId, model.match?.awayTeamId].compactMap { $0 })
            )
        }
    }

    // MARK: Basic stats

    @ViewBuilder
    private var basicStats: some View {
        if let score = model.match?.score, score.home != nil {
            GlassSection(titleKey: "match.tab.stats") {
                InfoRow(labelKey: "match.stats.fulltime", value: score.display ?? "–")
                if let h = score.homeHalfTime, let a = score.awayHalfTime {
                    Divider()
                    InfoRow(labelKey: "match.stats.halftime", value: "\(h) – \(a)")
                }
            }
        } else {
            EmptyStateView(systemImage: "chart.bar", titleKey: "match.stats.none")
                .glassCard()
        }
    }
}
