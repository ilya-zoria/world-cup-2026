import Foundation

/// Shared, cached formatters. Creating `DateFormatter` is expensive, so these
/// are instantiated once and reused. They respect the user's selected locale by
/// being created on demand per locale where it matters.
enum Formatters {
    /// Kickoff time, e.g. "19:00" / "7:00 PM" depending on locale.
    static func kickoffTime(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    /// Full date for section headers, e.g. "Sun, 14 Jun".
    static func mediumDate(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter.string(from: date)
    }

    /// Date + time used on match detail, e.g. "14 Jun 2026, 19:00".
    static func dateTime(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// "Updated 2 min ago" style relative string.
    static func relative(_ date: Date, locale: Locale) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
