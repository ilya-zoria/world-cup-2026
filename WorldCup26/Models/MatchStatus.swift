import Foundation

/// High-level state of a match. We intentionally collapse the many raw
/// statuses returned by Football-Data into the three states the product needs.
enum MatchStatus: String, Codable, CaseIterable, Hashable {
    case scheduled
    case live
    case finished

    /// Maps a Football-Data `status` string onto our simplified model.
    /// Reference: https://docs.football-data.org/general/v4/match.html
    init(apiStatus: String) {
        switch apiStatus.uppercased() {
        case "IN_PLAY", "PAUSED", "SUSPENDED":
            self = .live
        case "FINISHED", "AWARDED":
            self = .finished
        default: // SCHEDULED, TIMED, POSTPONED, CANCELLED
            self = .scheduled
        }
    }

    var isLive: Bool { self == .live }

    var displayKey: String {
        switch self {
        case .scheduled: return "status.scheduled"
        case .live: return "status.live"
        case .finished: return "status.finished"
        }
    }
}
