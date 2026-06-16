import Foundation

/// Drives the data-refresh strategy:
/// - one refresh shortly after launch / when the app returns to the foreground,
/// - a periodic refresh on an *adaptive* timer while the app is active (tighter
///   when matches are live, relaxed when idle — see `recommendedRefreshInterval`),
/// - pull-to-refresh handled directly by views calling `store.refresh(force:)`.
///
/// All calls go through `TournamentStore.refresh()`, which is itself throttled,
/// so the API is never called per UI interaction nor faster than the free-tier
/// rate limit allows.
@MainActor
final class RefreshScheduler {
    private let store: TournamentStore
    private var loopTask: Task<Void, Never>?

    init(store: TournamentStore) {
        self.store = store
    }

    /// Begins the periodic refresh loop. Safe to call repeatedly.
    func start() {
        guard loopTask == nil, store.isAPIConfigured else { return }
        loopTask = Task { [weak self] in
            guard let self else { return }
            await self.store.refresh()
            while !Task.isCancelled {
                // Cadence adapts to live play; the store also throttles, so this
                // can never push the API over its rate limit.
                let delay = self.store.recommendedRefreshInterval
                try? await Task.sleep(for: .seconds(delay))
                if Task.isCancelled { break }
                await self.store.refresh()
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    /// Called when the app becomes active; refresh honours the cache TTL.
    func appBecameActive() {
        Task { await store.refresh() }
    }
}
