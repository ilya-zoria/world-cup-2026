import SwiftUI

/// Lightweight design tokens used across the app for visual consistency.
enum DS {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let card: CGFloat = 14
        static let chip: CGFloat = 8
        static let pill: CGFloat = 999
    }

    enum Color {
        static let accent = SwiftUI.Color.accentColor
        static let live = SwiftUI.Color.red
        static let cardBackground = SwiftUI.Color(.secondarySystemGroupedBackground)
        static let groupedBackground = SwiftUI.Color(.systemGroupedBackground)
        static let subtle = SwiftUI.Color(.tertiaryLabel)
    }
}

/// A standard rounded card container used by feed rows and detail panels.
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DS.Spacing.lg)
            .background(DS.Color.cardBackground, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

// MARK: - Score typography

extension Font {
    /// The numerals used for scores: a compact, geometric scoreboard treatment.
    ///
    /// True **SF Compact** is the watchOS system family and isn't reachable by
    /// name on iOS (it's hidden from font lookup, and the system file isn't
    /// readable from the app sandbox), so we use SF Pro at *compressed* width —
    /// the closest system-available match for that flat-sided scoreboard look.
    /// To use the real face instead, bundle `SF-Compact.ttf` and return
    /// `.custom("SFCompact-Bold", size: size)` here.
    static func score(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight).width(.compressed)
    }
}
