import SwiftUI

/// A small colored pill describing a match's state. Live matches pulse.
struct StatusBadge: View {
    let status: MatchStatus

    var body: some View {
        HStack(spacing: 4) {
            if status == .live {
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
                    .opacity(0.9)
            }
            Text(key: status.displayKey)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(foreground)
        .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch status {
        case .live: return .white
        case .finished: return .secondary
        case .scheduled: return .accentColor
        }
    }

    private var background: Color {
        switch status {
        case .live: return DS.Color.live
        case .finished: return Color(.tertiarySystemFill)
        case .scheduled: return Color.accentColor.opacity(0.15)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusBadge(status: .scheduled)
        StatusBadge(status: .live)
        StatusBadge(status: .finished)
    }
    .padding()
}
