import SwiftUI

/// The app shell: four tabs, each in its own navigation stack. Settings and the
/// Support link live in the Home header rather than the tab bar. Applies the
/// user's chosen language (via the environment locale) and appearance.
struct RootView: View {
    @Environment(TournamentStore.self) private var store
    @Environment(LocalizationManager.self) private var localization
    @Environment(ThemeManager.self) private var theme

    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeView(store: store)
                    .appNavigationDestinations()
            }
            .tabItem { Label(LKey("tab.home"), systemImage: "house.fill") }
            .tag(0)

            NavigationStack {
                GroupsView(store: store)
                    .appNavigationDestinations()
            }
            .tabItem { Label(LKey("tab.groups"), systemImage: "tablecells") }
            .tag(1)

            NavigationStack {
                KnockoutView(store: store)
                    .appNavigationDestinations()
            }
            .tabItem { Label(LKey("tab.knockout"), systemImage: "trophy.fill") }
            .tag(2)

            NavigationStack {
                TeamsView(store: store)
                    .appNavigationDestinations()
            }
            .tabItem { Label(LKey("tab.teams"), systemImage: "flag.2.crossed.fill") }
            .tag(3)
        }
        .environment(\.locale, localization.locale)
        .preferredColorScheme(theme.colorScheme)
    }
}
