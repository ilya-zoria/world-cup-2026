import Foundation

/// Composition root: constructs and owns the app's long-lived services so they
/// can be injected into the SwiftUI environment from one place.
@MainActor
final class AppEnvironment {
    let store: TournamentStore
    let localization: LocalizationManager
    let theme: ThemeManager
    let votes: VoteStore
    let scheduler: RefreshScheduler

    init() {
        let store = TournamentStore()
        self.store = store
        self.localization = LocalizationManager()
        self.theme = ThemeManager()
        self.votes = VoteStore()
        self.scheduler = RefreshScheduler(store: store)
    }
}
