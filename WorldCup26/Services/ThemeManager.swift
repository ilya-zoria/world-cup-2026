import Foundation
import Observation
import SwiftUI

/// User-selectable appearance, persisted across launches.
@MainActor
@Observable
final class ThemeManager {
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .system: return "theme.system"
            case .light: return "theme.light"
            case .dark: return "theme.dark"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    private let defaultsKey = "selectedAppearance"

    var appearance: Appearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: defaultsKey) }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: defaultsKey)
        self.appearance = stored.flatMap(Appearance.init(rawValue:)) ?? .system
    }

    var colorScheme: ColorScheme? { appearance.colorScheme }
}
