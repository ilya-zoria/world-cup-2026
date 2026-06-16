import Foundation

/// A small thread-safe in-memory cache with per-entry time-to-live.
///
/// Used to avoid hammering the API: a value is considered fresh for `ttl`
/// seconds, after which `value(for:)` returns nil and the caller may refetch.
actor InMemoryCache<Key: Hashable, Value> {
    private struct Entry {
        let value: Value
        let storedAt: Date
    }

    private var storage: [Key: Entry] = [:]
    private let ttl: TimeInterval

    init(ttl: TimeInterval) {
        self.ttl = ttl
    }

    /// Returns the cached value if present and still within its TTL.
    func value(for key: Key, now: Date = Date()) -> Value? {
        guard let entry = storage[key] else { return nil }
        guard now.timeIntervalSince(entry.storedAt) < ttl else {
            storage[key] = nil
            return nil
        }
        return entry.value
    }

    /// Returns the cached value regardless of age (useful as an offline fallback).
    func staleValue(for key: Key) -> Value? {
        storage[key]?.value
    }

    func insert(_ value: Value, for key: Key, now: Date = Date()) {
        storage[key] = Entry(value: value, storedAt: now)
    }

    /// True when there is a fresh (non-expired) entry for the key.
    func isFresh(_ key: Key, now: Date = Date()) -> Bool {
        value(for: key, now: now) != nil
    }

    func removeAll() {
        storage.removeAll()
    }
}
