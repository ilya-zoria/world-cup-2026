import Foundation
import Observation

/// The three time buckets the Home feed switches between via the segment picker.
enum HomeSegment: String, CaseIterable, Identifiable, Hashable {
    case yesterday, today, upcoming

    var id: String { rawValue }

    /// Reuses the existing `feed.*` strings (already translated into all 11 languages).
    var titleKey: String {
        switch self {
        case .yesterday: return "feed.yesterday"
        case .today: return "feed.today"
        case .upcoming: return "feed.upcoming"
        }
    }
}

/// Drives the Home feed. Derives the per-segment match lists from the store and
/// exposes pull-to-refresh.
@MainActor
@Observable
final class HomeViewModel {
    private let store: TournamentStore

    init(store: TournamentStore) {
        self.store = store
    }

    // MARK: Segment content

    var yesterdayMatches: [Match] { store.matchesYesterday() }
    var todayMatches: [Match] { store.matchesToday() }
    /// Future matches grouped into chronological day sections.
    var upcomingDays: [MatchDaySection] { store.upcomingMatchDays() }

    func matches(for segment: HomeSegment) -> [Match] {
        switch segment {
        case .yesterday: return yesterdayMatches
        case .today: return todayMatches
        case .upcoming: return upcomingDays.flatMap(\.matches)
        }
    }

    // MARK: State

    var hasContent: Bool {
        !yesterdayMatches.isEmpty || !todayMatches.isEmpty || !upcomingDays.isEmpty
    }
    var loadError: String? { store.loadError }
    var lastUpdated: Date? { store.lastUpdated }
    var isAPIConfigured: Bool { store.isAPIConfigured }

    /// Pull-to-refresh forces a network fetch (bypassing the cache TTL).
    func refresh() async {
        await store.refresh(force: true)
    }
}
