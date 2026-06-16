import SwiftUI

/// Lists all 12 groups as a two-column grid of cards.
struct GroupsView: View {
    @State private var model: GroupsViewModel

    init(store: TournamentStore) {
        _model = State(initialValue: GroupsViewModel(store: store))
    }

    private let columns = [GridItem(.flexible(), spacing: DS.Spacing.md),
                           GridItem(.flexible(), spacing: DS.Spacing.md)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
                ForEach(model.groups) { group in
                    NavigationLink(value: group) {
                        GroupCard(group: group, rows: model.standingRows(in: group))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DS.Spacing.lg)
        }
        .background(DS.Color.groupedBackground)
        .navigationTitle(LKey("tab.groups"))
    }
}

/// Compact group preview: letter + the four teams.
private struct GroupCard: View {
    let group: Group
    /// Teams with points, ordered by group ranking.
    let rows: [GroupStandingRow]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            (Text(key: "group.word") + Text(verbatim: " \(group.id)"))
                .font(.headline)
                .padding(.bottom, 2)
            ForEach(rows) { row in
                HStack(spacing: DS.Spacing.sm) {
                    FlagView(emoji: row.team.displayFlag, size: 22)
                    Text(verbatim: row.team.name)
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Text(verbatim: "\(row.points)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
