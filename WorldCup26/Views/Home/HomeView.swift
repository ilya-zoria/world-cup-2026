import SwiftUI

/// The "what's happening now" feed, split into Yesterday / Today / Upcoming
/// segments. Yesterday and Today show a flat list; Upcoming groups matches into
/// collapsible day sections.
struct HomeView: View {
    @Environment(\.locale) private var locale
    @State private var model: HomeViewModel
    @State private var showingSettings = false
    @State private var segment: HomeSegment = .today

    init(store: TournamentStore) {
        _model = State(initialValue: HomeViewModel(store: store))
    }

    var body: some View {
        SwiftUI.Group {
            if model.loadError != nil {
                EmptyStateView(systemImage: "exclamationmark.icloud", titleKey: "error.dataMissing")
            } else if !model.hasContent {
                EmptyStateView(systemImage: "sportscourt", titleKey: "home.empty")
            } else {
                content
            }
        }
        .navigationTitle(LKey("home.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Link(destination: SupportLink.url) {
                    HStack(spacing: 4) {
                        Image(systemName: "cup.and.saucer.fill")
                        Text(key: "support.me").fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
                .tint(.orange)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel(Text(key: "tab.settings"))
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button { showingSettings = false } label: {
                                Text(key: "common.done")
                            }
                        }
                    }
            }
        }
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 0) {
            HomeSegmentControl(selection: $segment)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.xs)
                .padding(.bottom, DS.Spacing.sm)

            ScrollView {
                segmentContent
            }
            .refreshable { await model.refresh() }
        }
        .background(DS.Color.groupedBackground)
    }

    @ViewBuilder
    private var segmentContent: some View {
        switch segment {
        case .yesterday: matchList(model.yesterdayMatches)
        case .today: matchList(model.todayMatches)
        case .upcoming: upcomingList
        }
    }

    private func matchList(_ matches: [Match]) -> some View {
        LazyVStack(spacing: DS.Spacing.md) {
            if matches.isEmpty {
                inlineEmpty
            } else {
                ForEach(matches) { match in
                    matchLink(match)
                }
            }
        }
        .padding(DS.Spacing.lg)
    }

    private var upcomingList: some View {
        LazyVStack(alignment: .leading, spacing: DS.Spacing.md, pinnedViews: [.sectionHeaders]) {
            if model.upcomingDays.isEmpty {
                inlineEmpty
            } else {
                ForEach(model.upcomingDays) { section in
                    Section {
                        ForEach(section.matches) { match in
                            matchLink(match)
                                .padding(.horizontal, DS.Spacing.lg)
                        }
                    } header: {
                        dayHeader(section)
                    }
                }
            }
        }
        .padding(.bottom, DS.Spacing.lg)
    }

    private func matchLink(_ match: Match) -> some View {
        NavigationLink(value: match) {
            FeaturedMatchCard(match: match)
        }
        .buttonStyle(.plain)
    }

    private func dayHeader(_ section: MatchDaySection) -> some View {
        Text(verbatim: Formatters.mediumDate(section.date, locale: locale))
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
            .padding(.horizontal, DS.Spacing.lg)
            .background(DS.Color.groupedBackground)
    }

    private var inlineEmpty: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "sportscourt")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(key: "home.empty")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl * 2)
    }
}
