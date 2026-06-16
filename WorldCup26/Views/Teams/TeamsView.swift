import SwiftUI

/// Grid of all teams: each a flag "coin" with a World Cup title badge and a
/// favorite toggle. Favorites float to the top. Searchable.
struct TeamsView: View {
    @State private var model: TeamsViewModel

    init(store: TournamentStore) {
        _model = State(initialValue: TeamsViewModel(store: store))
    }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: DS.Spacing.md),
        count: 3
    )

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
                ForEach(model.filteredTeams) { team in
                    ZStack(alignment: .topTrailing) {
                        NavigationLink(value: team) {
                            TeamCard(team: team)
                        }
                        .buttonStyle(.plain)

                        // Overlaid as a sibling (not inside the link) so the
                        // heart's taps never trigger navigation.
                        FavoriteButton(isFavorite: model.isFavorite(team)) {
                            withAnimation(.snappy) { model.toggleFavorite(team) }
                        }
                        .padding(10)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.sm)
        }
        .background(DS.Color.groupedBackground)
        .navigationTitle(LKey("tab.teams"))
        .searchable(text: Bindable(model).searchText, prompt: Text(key: "teams.search"))
        .overlay {
            if model.filteredTeams.isEmpty {
                ContentUnavailableView.search(text: model.searchText)
            }
        }
    }
}

/// A single team "coin": circular flag, optional trophy badge, name strip.
/// Navigation-only — the favorite heart is overlaid by the parent.
private struct TeamCard: View {
    let team: Team

    var body: some View {
        VStack(spacing: 0) {
            TeamFlag(emoji: team.displayFlag, size: 52)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .overlay(alignment: .topLeading) {
                    if team.worldCupTitles > 0 {
                        TitleBadge(count: team.worldCupTitles).padding(10)
                    }
                }

            Text(verbatim: team.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 14)
                .padding(.horizontal, 6)
        }
        .background(DS.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card + 4, style: .continuous))
    }
}

/// A country flag emoji shown at its natural shape.
private struct TeamFlag: View {
    let emoji: String
    var size: CGFloat = 52

    var body: some View {
        Text(emoji.isEmpty ? "🏳️" : emoji)
            .font(.system(size: size))
    }
}

/// Gold capsule showing how many World Cup titles a nation has won.
private struct TitleBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 10, weight: .bold))
            Text(verbatim: "\(count)")
                .font(.system(size: 12, weight: .heavy))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color(red: 0.93, green: 0.74, blue: 0.18), in: Capsule())
        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        .accessibilityElement()
        .accessibilityLabel(Text("teams.titles \(count)"))
    }
}

/// Heart toggle for favoriting a team, sitting on a translucent disc.
private struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isFavorite
                    ? Color(red: 0.95, green: 0.2, blue: 0.42)
                    : .white.opacity(0.65))
                .padding(7)
                .background(.black.opacity(0.28), in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(key: isFavorite ? "teams.favorite.remove" : "teams.favorite.add"))
    }
}
