import SwiftUI

/// Translucent "glass" surfaces for the Match Detail page, so the animated flag
/// gradient shows through the content. Paired with the page's forced dark color
/// scheme (set in `MatchDetailView`).
extension View {
    func glassCard() -> some View {
        self
            .padding(DS.Spacing.lg)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
    }
}

/// A titled translucent section card — the Match Detail analogue of `SectionCard`.
struct GlassSection<Content: View>: View {
    let titleKey: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(key: titleKey)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}
