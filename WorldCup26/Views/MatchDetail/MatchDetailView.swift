import SwiftUI

/// The core screen: a scoreboard header plus Overview / Lineups / Stats tabs.
struct MatchDetailView: View {
    @State private var model: MatchDetailViewModel

    init(matchId: String, store: TournamentStore, votes: VoteStore) {
        _model = State(initialValue: MatchDetailViewModel(matchId: matchId, store: store, votes: votes))
    }

    var body: some View {
        SwiftUI.Group {
            if let match = model.match {
                content(match)
            } else {
                EmptyStateView(systemImage: "questionmark.circle", titleKey: "error.dataMissing")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: model.selectedTab) {
            if model.selectedTab == .lineups {
                await model.loadLineupsIfNeeded()
            }
        }
    }

    private var homeColors: [Color] { FlagPalette.colors(for: model.homeTeam?.displayFlag ?? "") }
    private var awayColors: [Color] { FlagPalette.colors(for: model.awayTeam?.displayFlag ?? "") }

    private func content(_ match: Match) -> some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                MatchScoreboard(match: match, home: model.homeTeam, away: model.awayTeam)
                    .padding(.top, DS.Spacing.sm)

                VStack(spacing: DS.Spacing.lg) {
                    Picker(LKey("match.tab.overview"), selection: Bindable(model).selectedTab) {
                        ForEach(MatchDetailViewModel.Tab.allCases, id: \.self) { tab in
                            Text(key: tab.titleKey).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    switch model.selectedTab {
                    case .overview: OverviewTab(model: model)
                    case .lineups: LineupsTab(model: model)
                    case .stats: StatsTab(model: model)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
            .padding(.bottom, DS.Spacing.lg)
        }
        .background {
            FlagGradientBackground(homeColors: homeColors, awayColors: awayColors)
                .overlay(Color.black.opacity(0.32))
                .ignoresSafeArea()
        }
        .environment(\.colorScheme, .dark)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
