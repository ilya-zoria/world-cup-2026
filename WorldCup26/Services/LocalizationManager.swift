import Foundation
import Observation
import SwiftUI

/// The languages the app ships translations for.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case ukrainian = "uk"
    case portuguese = "pt"
    case german = "de"
    case french = "fr"
    case italian = "it"
    case dutch = "nl"
    case norwegian = "nb"
    case swedish = "sv"
    case danish = "da"

    var id: String { rawValue }

    /// Name shown in the picker, in the language's own words.
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .ukrainian: return "Українська"
        case .portuguese: return "Português"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .italian: return "Italiano"
        case .dutch: return "Nederlands"
        case .norwegian: return "Norsk"
        case .swedish: return "Svenska"
        case .danish: return "Dansk"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .spanish: return "🇪🇸"
        case .ukrainian: return "🇺🇦"
        case .portuguese: return "🇵🇹"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        case .italian: return "🇮🇹"
        case .dutch: return "🇳🇱"
        case .norwegian: return "🇳🇴"
        case .swedish: return "🇸🇪"
        case .danish: return "🇩🇰"
        }
    }
}

/// Owns the user's selected language and exposes it as a `Locale`.
///
/// We override the SwiftUI environment locale rather than swapping bundles:
/// `Text` and `LocalizedStringKey` resolve against `\.locale`, so the whole UI
/// re-localizes live when the user picks a new language — no restart needed.
@MainActor
@Observable
final class LocalizationManager {
    private let defaultsKey = "selectedLanguage"

    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: defaultsKey)
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: defaultsKey)
        self.language = stored.flatMap(AppLanguage.init(rawValue:)) ?? Self.systemDefault
    }

    var locale: Locale { Locale(identifier: language.rawValue) }

    private static var systemDefault: AppLanguage {
        for code in Locale.preferredLanguages {
            let base = String(code.prefix(2))
            if let match = AppLanguage(rawValue: base) { return match }
            if base == "no", let nb = AppLanguage(rawValue: "nb") { return nb }
        }
        return .english
    }
}
