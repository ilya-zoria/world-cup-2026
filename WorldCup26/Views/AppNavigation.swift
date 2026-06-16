import SwiftUI

/// Registers the app's push destinations once, so any `NavigationLink(value:)`
/// using a `Match`, `Team` or `Group` works inside every tab's stack.
private struct AppNavigationDestinations: ViewModifier {
    @Environment(TournamentStore.self) private var store
    @Environment(VoteStore.self) private var votes

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Match.self) { match in
                MatchDetailView(matchId: match.id, store: store, votes: votes)
            }
            .navigationDestination(for: Team.self) { team in
                TeamDetailView(team: team, store: store)
            }
            .navigationDestination(for: Group.self) { group in
                GroupDetailView(group: group, store: store)
            }
    }
}

extension View {
    func appNavigationDestinations() -> some View {
        modifier(AppNavigationDestinations())
    }
}
