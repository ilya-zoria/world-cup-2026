import Foundation
import Observation

/// Provides app metadata and share content for the Profile / Settings screen.
/// Theme, language and purchases are owned by their dedicated managers, which
/// the view reads from the environment directly.
@MainActor
@Observable
final class SettingsViewModel {
    /// App Store identifier used to build store links (placeholder until published).
    private let appStoreID = "idXXXXXXXXX"

    /// App Store URL used by the Share sheet.
    var shareURL: URL { URL(string: "https://apps.apple.com/app/\(appStoreID)")! }

    /// Deep link that opens the App Store straight to the "Write a Review" screen.
    var reviewURL: URL { URL(string: "https://apps.apple.com/app/\(appStoreID)?action=write-review")! }

    var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    var shareMessage: String {
        String(localized: "settings.share.message")
    }
}
