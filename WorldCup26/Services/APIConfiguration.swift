import Foundation

/// Configuration for the Football-Data API.
///
/// The API is OPTIONAL: the app is offline-first and fully functional without
/// it. When no key is present, `isConfigured` is false and the repository
/// short-circuits so no network calls are attempted.
///
/// To enable live enrichment, add a `FootballDataAPIKey` entry to Info.plist
/// (or set it here) with a key from https://www.football-data.org/client/register
struct APIConfiguration {
    let apiKey: String
    let baseURL: URL
    /// Football-Data competition code for the World Cup.
    let competitionCode: String

    var isConfigured: Bool { !apiKey.isEmpty }

    static let live: APIConfiguration = {
        let key = (Bundle.main.object(forInfoDictionaryKey: "FootballDataAPIKey") as? String) ?? ""
        return APIConfiguration(
            apiKey: key.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: URL(string: "https://api.football-data.org/v4")!,
            competitionCode: "WC"
        )
    }()
}
