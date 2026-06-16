import SwiftUI

/// A single group: standings table + chronological fixtures.
struct GroupDetailView: View {
    @State private var model: GroupDetailViewModel

    init(group: Group, store: TournamentStore) {
        _model = State(initialValue: GroupDetailViewModel(group: group, store: store))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                SectionCard(titleKey: "group.standings") {
                    StandingsTableView(standings: model.standings)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text(key: "group.matches")
                        .font(.headline)
                    ForEach(model.matches) { match in
                        NavigationLink(value: match) {
                            MatchCardView(match: match)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(DS.Spacing.lg)
        }
        .background(DS.Color.groupedBackground)
        .navigationTitle(Text(key: "group.word") + Text(verbatim: " \(model.group.id)"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
