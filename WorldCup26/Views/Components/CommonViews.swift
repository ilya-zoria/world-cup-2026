import SwiftUI

/// Centered icon + message used for empty / unavailable states.
struct EmptyStateView: View {
    let systemImage: String
    let titleKey: String
    var messageKey: String? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(key: titleKey)
                .font(.headline)
                .multilineTextAlignment(.center)
            if let messageKey {
                Text(key: messageKey)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.xl)
    }
}

/// A label/value row for detail panels. The label is localized; the value is
/// caller-provided text (often data, e.g. a stadium name).
struct InfoRow: View {
    let labelKey: String
    let value: String

    var body: some View {
        HStack {
            Text(key: labelKey)
                .foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

/// A compact stat tile (big value + localized caption).
struct StatTile: View {
    let value: String
    let captionKey: String
    var tint: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(tint)
            Text(key: captionKey)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
    }
}

/// A titled card section: localized heading above arbitrary content.
struct SectionCard<Content: View>: View {
    let titleKey: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(key: titleKey)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
