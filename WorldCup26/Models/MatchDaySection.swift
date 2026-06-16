import Foundation

/// A dated grouping of matches for the Home feed.
struct MatchDaySection: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case live, today, tomorrow, yesterday, upcoming

        var titleKey: String {
            switch self {
            case .live: return "feed.live"
            case .today: return "feed.today"
            case .tomorrow: return "feed.tomorrow"
            case .yesterday: return "feed.yesterday"
            case .upcoming: return "feed.upcoming"
            }
        }
    }

    let kind: Kind
    let date: Date
    let matches: [Match]

    /// Includes the date so multiple same-kind sections (e.g. several
    /// `.upcoming` day buckets) stay uniquely identifiable in a `ForEach`.
    var id: String { "\(kind.rawValue)-\(date.timeIntervalSinceReferenceDate)" }
}
