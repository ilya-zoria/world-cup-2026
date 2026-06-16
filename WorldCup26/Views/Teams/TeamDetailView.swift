import SwiftUI

/// A team page with Overview / Matches / Stats / Players tabs.
struct TeamDetailView: View {
    enum Tab: Hashable, CaseIterable {
        case overview, matches, stats, players
        var titleKey: String {
            switch self {
            case .overview: return "team.tab.overview"
            case .matches: return "team.tab.matches"
            case .stats: return "team.tab.stats"
            case .players: return "team.tab.players"
            }
        }
    }

    @State private var model: TeamDetailViewModel
    @State private var tab: Tab = .overview

    init(team: Team, store: TournamentStore) {
        _model = State(initialValue: TeamDetailViewModel(team: team, store: store))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                header

                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text(key: $0.titleKey).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                switch tab {
                case .overview: overview
                case .matches: matches
                case .stats: stats
                case .players: players
                }
            }
            .padding(DS.Spacing.lg)
        }
        .background(DS.Color.groupedBackground)
        .navigationTitle(Text(verbatim: model.team.name))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: DS.Spacing.sm) {
            FlagView(emoji: model.team.displayFlag, size: 72)
            Text(verbatim: model.team.name).font(.title2.bold())
            if let groupId = model.team.groupId {
                (Text(key: "group.word") + Text(verbatim: " \(groupId)"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: Overview

    private var overview: some View {
        VStack(spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.md) {
                if let groupId = model.team.groupId {
                    HStack {
                        Text(key: "group.word").foregroundStyle(.secondary)
                        Spacer()
                        Text(verbatim: groupId).fontWeight(.medium)
                    }
                    .font(.subheadline)
                    Divider()
                }
                if let conf = model.team.confederation {
                    InfoRow(labelKey: "team.confederation", value: conf)
                    Divider()
                }
                if let rank = model.team.fifaRanking {
                    InfoRow(labelKey: "team.ranking", value: "#\(rank)")
                }
            }
            .card()

            if !model.groupmates.isEmpty {
                SectionCard(titleKey: "team.groupmates") {
                    ForEach(model.groupmates) { mate in
                        NavigationLink(value: mate) {
                            TeamRow(team: mate)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Matches

    private var matches: some View {
        VStack(spacing: DS.Spacing.md) {
            ForEach(model.matches) { match in
                NavigationLink(value: match) {
                    MatchCardView(match: match)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Stats

    private var stats: some View {
        SectionCard(titleKey: "team.stats.record") {
            HStack {
                StatTile(value: "\(model.stats.won)", captionKey: "group.table.won")
                StatTile(value: "\(model.stats.drawn)", captionKey: "group.table.drawn")
                StatTile(value: "\(model.stats.lost)", captionKey: "group.table.lost")
            }
            Divider()
            HStack {
                StatTile(value: "\(model.stats.played)", captionKey: "team.stats.played")
                StatTile(value: "\(model.stats.goalsFor)", captionKey: "group.table.gf")
                StatTile(value: "\(model.stats.goalsAgainst)", captionKey: "group.table.ga")
            }
        }
    }

    // MARK: Players

    private var players: some View {
        EmptyStateView(systemImage: "person.crop.circle", titleKey: "team.tab.players", messageKey: "team.players.empty")
            .card()
    }
}

/// A compact team row: flag, name, and its group badge. Used in the groupmates
/// list on a team's detail screen.
struct TeamRow: View {
    let team: Team

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            FlagView(emoji: team.displayFlag, size: 30)
            Text(verbatim: team.name)
                .font(.body)
            Spacer()
            if let groupId = team.groupId {
                (Text(key: "group.word") + Text(verbatim: " \(groupId)"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
