import Foundation
import Observation

/// The single source of truth for tournament data and the app's main model layer.
///
/// - Loads the bundled static dataset synchronously at init so every screen has
///   data instantly and the app is fully usable offline.
/// - Enriches match `status`/`score` from the API on demand, throttled by an
///   in-memory cache so the UI never triggers redundant network calls.
///
/// ViewModels receive this store and derive their screen-specific data from it.
@MainActor
@Observable
final class TournamentStore {

    // MARK: Static data (offline-first)

    private(set) var teams: [Team] = []
    private(set) var groups: [Group] = []
    private(set) var stadiums: [Stadium] = []
    private(set) var matches: [Match] = []

    // MARK: Indexes

    private var teamsById: [String: Team] = [:]
    private var stadiumsById: [String: Stadium] = [:]
    private var groupsById: [String: Group] = [:]

    // MARK: State

    /// Set when the bundled data could not be loaded (a packaging error).
    private(set) var loadError: String?
    /// Last successful API refresh, or nil if never / not configured.
    private(set) var lastUpdated: Date?
    /// Non-fatal message from the most recent failed refresh.
    private(set) var refreshError: String?
    private(set) var isRefreshing = false

    /// Date treated as "now" for the Home feed. Overridable for previews/tests.
    var referenceDate: Date = Date()

    // MARK: Dependencies

    private let local: LocalDataRepositoryProtocol
    private let api: MatchAPIRepositoryProtocol
    /// Lineups come from the static feed (not Football-Data, which gates them
    /// behind a paid tier). `LineupFeedRepository` caches the feed internally.
    private let lineupRepo: LineupRepositoryProtocol

    // MARK: Refresh throttling (tuned for the free-tier ~10 calls/min limit)

    /// Hard floor between *any* two network fetches — even forced pull-to-refresh
    /// no-ops within this window, so users can't spam the API.
    private let minFetchInterval: TimeInterval
    /// Snapshot lifetime while one or more matches are live (scores stay current).
    private let liveRefreshTTL: TimeInterval
    /// Snapshot lifetime when nothing is live (relaxed to conserve the quota).
    private let idleRefreshTTL: TimeInterval
    /// Start of the last network fetch (success or failure), used for throttling.
    private var lastFetchAttempt: Date?

    var isAPIConfigured: Bool { api.isConfigured }

    init(
        local: LocalDataRepositoryProtocol = LocalDataRepository(),
        api: MatchAPIRepositoryProtocol = MatchAPIRepository(client: APIClient(configuration: .live)),
        lineupRepo: LineupRepositoryProtocol = LineupFeedRepository(configuration: .live),
        liveRefreshTTL: TimeInterval = 90,
        idleRefreshTTL: TimeInterval = 5 * 60,
        minFetchInterval: TimeInterval = 15
    ) {
        self.local = local
        self.api = api
        self.lineupRepo = lineupRepo
        self.liveRefreshTTL = liveRefreshTTL
        self.idleRefreshTTL = idleRefreshTTL
        self.minFetchInterval = minFetchInterval
        loadStaticData()
    }

    // MARK: - Loading

    private func loadStaticData() {
        do {
            teams = try local.loadTeams().sorted { $0.name < $1.name }
            groups = try local.loadGroups().sorted { $0.id < $1.id }
            stadiums = try local.loadStadiums()
            matches = try local.loadMatches().sorted { $0.kickoff < $1.kickoff }

            teamsById = Dictionary(teams.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            stadiumsById = Dictionary(stadiums.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            groupsById = Dictionary(groups.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    // MARK: - Lookups

    func team(id: String?) -> Team? {
        guard let id else { return nil }
        return teamsById[id]
    }

    func stadium(id: String?) -> Stadium? {
        guard let id else { return nil }
        return stadiumsById[id]
    }

    func group(id: String?) -> Group? {
        guard let id else { return nil }
        return groupsById[id]
    }

    func match(id: String) -> Match? {
        matches.first { $0.id == id }
    }

    func teams(inGroup groupId: String) -> [Team] {
        (groupsById[groupId]?.teamIds ?? []).compactMap { teamsById[$0] }
    }

    // MARK: - Match queries

    func matches(inGroup groupId: String) -> [Match] {
        matches.filter { $0.groupId == groupId }.sorted { $0.kickoff < $1.kickoff }
    }

    func matches(forTeam teamId: String) -> [Match] {
        matches
            .filter { $0.homeTeamId == teamId || $0.awayTeamId == teamId }
            .sorted { $0.kickoff < $1.kickoff }
    }

    func knockoutMatches(round: KnockoutRound) -> [Match] {
        matches
            .filter { $0.round == round }
            .sorted { ($0.matchNumber ?? 0) < ($1.matchNumber ?? 0) }
    }

    var liveMatches: [Match] {
        matches.filter { $0.status == .live }.sorted { $0.kickoff < $1.kickoff }
    }

    // MARK: - Standings (computed locally, always available offline)

    func standings(forGroup groupId: String) -> [Standing] {
        let teamIds = groupsById[groupId]?.teamIds ?? []
        var table = Dictionary(uniqueKeysWithValues: teamIds.map { ($0, Standing(teamId: $0)) })

        for match in matches(inGroup: groupId) where match.status == .finished {
            guard
                let home = match.homeTeamId, let away = match.awayTeamId,
                let hs = match.score?.home, let as0 = match.score?.away
            else { continue }
            table[home]?.register(scored: hs, conceded: as0)
            table[away]?.register(scored: as0, conceded: hs)
        }
        return Array(table.values).ranked()
    }

    /// Aggregated W/D/L and goals for a team across all finished matches.
    func teamStats(teamId: String) -> Standing {
        var standing = Standing(teamId: teamId)
        for match in matches(forTeam: teamId) where match.status == .finished {
            guard let hs = match.score?.home, let as0 = match.score?.away else { continue }
            if match.homeTeamId == teamId {
                standing.register(scored: hs, conceded: as0)
            } else {
                standing.register(scored: as0, conceded: hs)
            }
        }
        return standing
    }

    // MARK: - Home feed

    /// Groups matches into the date-relative sections shown on Home.
    func homeFeedSections(calendar: Calendar = .current) -> [MatchDaySection] {
        let today = calendar.startOfDay(for: referenceDate)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today)
        else { return [] }

        func matches(onSameDayAs day: Date) -> [Match] {
            self.matches
                .filter { calendar.isDate($0.kickoff, inSameDayAs: day) }
                .sorted { $0.kickoff < $1.kickoff }
        }

        var sections: [MatchDaySection] = []

        let live = liveMatches
        if !live.isEmpty {
            sections.append(MatchDaySection(kind: .live, date: today, matches: live))
        }
        let todayMatches = matches(onSameDayAs: today)
        if !todayMatches.isEmpty {
            sections.append(MatchDaySection(kind: .today, date: today, matches: todayMatches))
        }
        let tomorrowMatches = matches(onSameDayAs: tomorrow)
        if !tomorrowMatches.isEmpty {
            sections.append(MatchDaySection(kind: .tomorrow, date: tomorrow, matches: tomorrowMatches))
        }
        let yesterdayMatches = matches(onSameDayAs: yesterday)
        if !yesterdayMatches.isEmpty {
            sections.append(MatchDaySection(kind: .yesterday, date: yesterday, matches: yesterdayMatches))
        }

        // Upcoming: the next match days, from the day after tomorrow onward.
        let futureMatches = self.matches.filter { $0.kickoff >= dayAfterTomorrow }
        let upcoming = Array(futureMatches.sorted { $0.kickoff < $1.kickoff }.prefix(20))
        if !upcoming.isEmpty {
            sections.append(MatchDaySection(kind: .upcoming, date: dayAfterTomorrow, matches: upcoming))
        }
        return sections
    }

    // MARK: - Home segments (Yesterday / Today / Upcoming)

    /// All matches kicking off on the given calendar day, sorted by kickoff.
    func matches(on day: Date, calendar: Calendar = .current) -> [Match] {
        matches
            .filter { calendar.isDate($0.kickoff, inSameDayAs: day) }
            .sorted { $0.kickoff < $1.kickoff }
    }

    /// Matches kicking off today (relative to `referenceDate`).
    func matchesToday(calendar: Calendar = .current) -> [Match] {
        matches(on: calendar.startOfDay(for: referenceDate), calendar: calendar)
    }

    /// Matches that kicked off yesterday (relative to `referenceDate`).
    func matchesYesterday(calendar: Calendar = .current) -> [Match] {
        let today = calendar.startOfDay(for: referenceDate)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return [] }
        return matches(on: yesterday, calendar: calendar)
    }

    /// Upcoming matches (from tomorrow onward) grouped into chronological day
    /// buckets — the data behind the collapsible "Upcoming" segment on Home.
    func upcomingMatchDays(calendar: Calendar = .current, dayLimit: Int = 40) -> [MatchDaySection] {
        let today = calendar.startOfDay(for: referenceDate)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        let future = matches.filter { $0.kickoff >= tomorrow }
        let grouped = Dictionary(grouping: future) { calendar.startOfDay(for: $0.kickoff) }
        return grouped.keys.sorted()
            .prefix(dayLimit)
            .map { day in
                MatchDaySection(
                    kind: .upcoming,
                    date: day,
                    matches: grouped[day]?.sorted { $0.kickoff < $1.kickoff } ?? []
                )
            }
    }

    // MARK: - Refresh

    /// How long the current snapshot stays "fresh": shorter while matches are
    /// live so scores keep up, longer when idle to conserve the rate limit.
    private var autoRefreshTTL: TimeInterval {
        liveMatches.isEmpty ? idleRefreshTTL : liveRefreshTTL
    }

    /// Suggested delay until the next automatic refresh (adaptive to live play).
    /// `RefreshScheduler` reads this each cycle.
    var recommendedRefreshInterval: TimeInterval { autoRefreshTTL }

    /// Refreshes dynamic match data from the API. Best-effort and non-blocking
    /// for the static experience: failures are surfaced but never clear data.
    ///
    /// Two throttles keep usage inside the free-tier limit (~10 calls/min):
    /// a hard `minFetchInterval` floor on *every* path (so rapid pull-to-refresh
    /// can't spam calls), and — for automatic refreshes only — an adaptive
    /// snapshot TTL. Pull-to-refresh (`force`) skips the TTL but not the floor.
    ///
    /// - Parameter force: pull-to-refresh — bypass the snapshot TTL only.
    func refresh(force: Bool = false) async {
        // These checks are synchronous (no `await` before we set `isRefreshing`),
        // so overlapping launch/foreground calls can't race into two fetches.
        guard api.isConfigured, !isRefreshing else { return }

        let now = Date()
        if let last = lastFetchAttempt {
            let elapsed = now.timeIntervalSince(last)
            if elapsed < minFetchInterval { return }        // hard floor, all paths
            if !force, elapsed < autoRefreshTTL { return }  // snapshot still fresh
        }

        isRefreshing = true
        lastFetchAttempt = now
        defer { isRefreshing = false }

        do {
            let updates = try await api.fetchMatchStates()
            apply(updates)
            lastUpdated = Date()
            refreshError = nil
        } catch {
            refreshError = error.localizedDescription
        }
    }

    // MARK: - Lineups

    /// Lineups for a match, read from the static feed (cached by the repository).
    /// Returns `.empty` when the feed isn't configured or doesn't have them yet —
    /// the Lineups tab degrades gracefully rather than failing.
    func lineups(for match: Match) async -> MatchLineups {
        guard lineupRepo.isConfigured else { return .empty }
        do {
            return try await lineupRepo.fetchLineups(for: match)
        } catch {
            return .empty
        }
    }

    private func apply(_ updates: [MatchStateUpdate]) {
        guard !updates.isEmpty else { return }
        let byApiId = Dictionary(updates.map { ($0.apiMatchId, $0) }, uniquingKeysWith: { a, _ in a })
        matches = matches.map { match in
            guard let apiId = match.apiMatchId, let update = byApiId[apiId] else { return match }
            return match.applying(status: update.status, score: update.score)
        }
    }
}
