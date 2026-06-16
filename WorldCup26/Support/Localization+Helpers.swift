import SwiftUI

/// Builds a `LocalizedStringKey` from a runtime key string.
///
/// On-screen text uses `Text(LKey(...))` (and never `String(localized:)`) so it
/// resolves against the SwiftUI environment locale — which the in-app language
/// selector overrides — making language changes apply live across the whole UI.
func LKey(_ key: String) -> LocalizedStringKey {
    LocalizedStringKey(key)
}

extension Text {
    /// Convenience for `Text(LKey(key))`.
    init(key: String) {
        self.init(LKey(key))
    }
}
